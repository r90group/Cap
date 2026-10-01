import { execFileSync } from "node:child_process";

export function forkReleaseVersion(baseVersion, sequence) {
	const match = /^(\d+)\.(\d+)\.(\d+)$/.exec(baseVersion);
	if (!match || !Number.isSafeInteger(sequence) || sequence < 1)
		throw new TypeError(
			"A stable base version and positive source sequence are required",
		);
	const major = Number(match[1]);
	const minor = Number(match[2]);
	const patch = Number(match[3]);
	if (major > 255 || minor > 255 || patch > 65535)
		throw new RangeError(
			"Base version exceeds Windows Installer version bounds",
		);
	const serial = (major * 256 + minor) * 65536 + patch + sequence;
	if (serial > 0xffffffff)
		throw new RangeError(
			"Publication version exceeds Windows Installer version bounds",
		);
	return `${Math.floor(serial / 16777216)}.${Math.floor(serial / 65536) % 256}.${serial % 65536}`;
}

export function forkSourceVersion(baseVersion, revision, cwd = process.cwd()) {
	const sequence = Number(
		execFileSync("git", ["rev-list", "--first-parent", "--count", revision], {
			cwd,
			encoding: "utf8",
		}).trim(),
	);
	return forkReleaseVersion(baseVersion, sequence);
}
