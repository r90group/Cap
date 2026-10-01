import { spawnSync } from "node:child_process";
import { existsSync, mkdtempSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { fileURLToPath } from "node:url";
import { describe, expect, it } from "vitest";

const wrapper = fileURLToPath(
	new URL("./run-with-deadline.js", import.meta.url),
);

describe("native publisher command deadline", () => {
	it("preserves a real compiler-process failure rather than reporting success", () => {
		const directory = mkdtempSync(join(tmpdir(), "cap-compiler-exit-"));
		try {
			const script = join(directory, "compiler.cjs");
			writeFileSync(script, "process.exit(42);\n");
			const result = spawnSync(
				process.execPath,
				[wrapper, "5000", process.execPath, script],
				{ encoding: "utf8", timeout: 10000 },
			);
			expect(result.status).toBe(42);
		} finally {
			rmSync(directory, { recursive: true, force: true });
		}
	});

	it("fails and stops an overdue compiler tree before it can finish its artifact", () => {
		const directory = mkdtempSync(join(tmpdir(), "cap-build-deadline-"));
		try {
			const script = join(directory, "build.cjs");
			const artifact = join(directory, "late-artifact");
			const compiler = join(directory, "compiler.cjs");
			const started = join(directory, "compiler-started");
			writeFileSync(
				script,
				'const child = require("node:child_process").spawn(process.execPath, process.argv.slice(2), { stdio: "inherit" }); child.on("close", () => process.exit(0));\n',
			);
			writeFileSync(
				compiler,
				'process.on("SIGTERM", () => {}); require("node:fs").writeFileSync(process.argv[3], "started"); setTimeout(() => { require("node:fs").writeFileSync(process.argv[2], "finished"); process.exit(0); }, 2500);\n',
			);
			const result = spawnSync(
				process.execPath,
				[
					wrapper,
					"1000",
					process.execPath,
					script,
					compiler,
					artifact,
					started,
				],
				{ encoding: "utf8", timeout: 10000 },
			);
			expect(result.status).toBe(124);
			expect(existsSync(started)).toBe(true);
			expect(existsSync(artifact)).toBe(false);
		} finally {
			rmSync(directory, { recursive: true, force: true });
		}
	});
});
