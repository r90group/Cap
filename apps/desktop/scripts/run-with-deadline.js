import { spawn, spawnSync } from "node:child_process";

const [duration, command, ...args] = process.argv.slice(2);
const windows = process.platform === "win32";
const child = spawn(command, args, {
	stdio: "inherit",
	detached: !windows,
});
let expired = false;
const timer = setTimeout(() => {
	expired = true;
	console.error(
		"::error::Native publisher build exceeded its command deadline",
	);
	if (windows) {
		const result = spawnSync(
			"taskkill",
			["/pid", String(child.pid), "/t", "/f"],
			{ stdio: "inherit", timeout: 10000 },
		);
		if (result.error) throw result.error;
		if (result.status !== 0) child.kill("SIGKILL");
	} else {
		try {
			process.kill(-child.pid, "SIGKILL");
		} catch (error) {
			if (error.code !== "ESRCH") throw error;
		}
	}
}, Number(duration));
child.once("error", (error) => {
	clearTimeout(timer);
	console.error(error);
	process.exitCode = 1;
});
child.once("close", (code) => {
	clearTimeout(timer);
	process.exitCode = expired ? 124 : code === null || code < 0 ? 1 : code;
});
