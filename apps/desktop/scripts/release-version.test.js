import { execFileSync } from "node:child_process";
import { mkdtempSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { describe, expect, it } from "vitest";
import { forkReleaseVersion, forkSourceVersion } from "./release-version.js";

function compareStableVersions(left, right) {
	const a = left.split(".").map(Number);
	const b = right.split(".").map(Number);
	for (let index = 0; index < 3; index++) {
		if (a[index] !== b[index]) return a[index] - b[index];
	}
	return 0;
}

describe("fork publication versions", () => {
	it("keeps descendant updates newer when ancestors finish later and HEAD moves", () => {
		const repository = mkdtempSync(join(tmpdir(), "cap-release-history-"));
		const git = (...args) =>
			execFileSync(
				"git",
				[
					"-c",
					"user.name=Cap CI",
					"-c",
					"user.email=cap-ci@example.invalid",
					"-c",
					"commit.gpgsign=false",
					"-c",
					`core.hooksPath=${join(repository, "empty-hooks")}`,
					...args,
				],
				{ cwd: repository, encoding: "utf8" },
			).trim();
		try {
			git("init", "--quiet", "--initial-branch=main");
			git("commit", "--quiet", "--allow-empty", "--message=ancestor");
			const ancestor = git("rev-parse", "HEAD");
			git("commit", "--quiet", "--allow-empty", "--message=descendant");
			const descendant = git("rev-parse", "HEAD");
			const newer = forkSourceVersion("0.4.85", descendant, repository);
			const older = forkSourceVersion("0.4.85", ancestor, repository);
			expect(compareStableVersions(newer, older)).toBeGreaterThan(0);
			git("commit", "--quiet", "--allow-empty", "--message=later-head");
			expect(forkSourceVersion("0.4.85", descendant, repository)).toBe(newer);
			expect(
				compareStableVersions(
					forkSourceVersion("0.4.85", "HEAD", repository),
					newer,
				),
			).toBeGreaterThan(0);
		} finally {
			rmSync(repository, { recursive: true, force: true });
		}
	});

	it("makes successive merges eligible for native semver updates", () => {
		let installed = "0.4.85";
		for (let sequence = 1; sequence <= 300; sequence++) {
			const candidate = forkReleaseVersion("0.4.85", sequence);
			expect(compareStableVersions(candidate, installed)).toBeGreaterThan(0);
			installed = candidate;
		}
	});

	it("crosses Windows patch and minor limits without regressing the client", () => {
		for (const installed of ["0.4.65535", "0.255.65535"]) {
			const candidate = forkReleaseVersion(installed, 1);
			const [major, minor, patch] = candidate.split(".").map(Number);
			expect(compareStableVersions(candidate, installed)).toBeGreaterThan(0);
			expect(major).toBeLessThanOrEqual(255);
			expect(minor).toBeLessThanOrEqual(255);
			expect(patch).toBeLessThanOrEqual(65535);
		}
	});

	it("rejects versions that cannot be represented by the native installer", () => {
		expect(() => forkReleaseVersion("255.255.65535", 1)).toThrow(RangeError);
		expect(() => forkReleaseVersion("0.4.85", 0)).toThrow(TypeError);
	});
});
