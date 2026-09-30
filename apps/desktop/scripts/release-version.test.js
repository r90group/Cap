import { describe, expect, it } from "vitest";
import { forkReleaseVersion } from "./release-version.js";

function compareStableVersions(left, right) {
	const a = left.split(".").map(Number);
	const b = right.split(".").map(Number);
	for (let index = 0; index < 3; index++) {
		if (a[index] !== b[index]) return a[index] - b[index];
	}
	return 0;
}

describe("fork publication versions", () => {
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
