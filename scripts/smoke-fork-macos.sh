set -euo pipefail
mkdir -p smoke
(
  cd artifacts
  shasum -a 256 --check SHA256SUMS
)
manifest=artifacts/release-aarch64-apple-darwin.json
node --input-type=module -e 'import fs from "node:fs"; const m=JSON.parse(fs.readFileSync(process.argv[1])); if(m.revision!==process.env.RELEASE_SHA) throw new Error("Published revision mismatch");' "$manifest"
mount_dir="$RUNNER_TEMP/cap-dmg"
install_dir="$RUNNER_TEMP/cap-installed"
mkdir -p "$mount_dir" "$install_dir"
hdiutil attach artifacts/*_aarch64.dmg -nobrowse -readonly -mountpoint "$mount_dir"
trap 'hdiutil detach "$mount_dir" || true' EXIT
cp -R "$mount_dir/Cap.app" "$install_dir/Cap.app"
hdiutil detach "$mount_dir"
trap - EXIT
app="$install_dir/Cap.app"
codesign --verify --deep --strict "$app"
version=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$app/Contents/Info.plist")
expected=$(node -p "JSON.parse(require('fs').readFileSync('$manifest')).version")
test "$version" = "$expected"
binary_name=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleExecutable' "$app/Contents/Info.plist")
file "$app/Contents/MacOS/$binary_name" | tee smoke/binary.txt
test "$(lipo -archs "$app/Contents/MacOS/$binary_name")" = arm64
updater_dir="$RUNNER_TEMP/cap-updater"
mkdir -p "$updater_dir"
tar -xzf artifacts/*.app.tar.gz -C "$updater_dir"
updater_app="$updater_dir/Cap.app"
codesign --verify --deep --strict "$updater_app"
updater_version=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$updater_app/Contents/Info.plist")
test "$updater_version" = "$expected"
cmp "$app/Contents/MacOS/$binary_name" "$updater_app/Contents/MacOS/$binary_name"
"$app/Contents/MacOS/$binary_name" > smoke/startup.log 2>&1 &
app_pid=$!
trap 'kill "$app_pid" 2>/dev/null || true' EXIT
export CAP_SMOKE_PID="$app_pid"
swift - <<'SWIFT' | tee smoke/window.json
import Foundation
import CoreGraphics
let pid = Int(ProcessInfo.processInfo.environment["CAP_SMOKE_PID"]!)!
for _ in 0..<60 {
    let windows = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as! [[String: Any]]
    if let window = windows.first(where: { ($0[kCGWindowOwnerPID as String] as? Int) == pid && ($0[kCGWindowLayer as String] as? Int) == 0 }),
       let bounds = window[kCGWindowBounds as String] as? [String: Any],
       let width = bounds["Width"] as? Double, let height = bounds["Height"] as? Double,
       width >= 800, height >= 600,
       let title = window[kCGWindowName as String] as? String,
       title == "Welcome to Cap" {
        let evidence: [String: Any] = ["owner": window[kCGWindowOwnerName as String] ?? "", "title": title, "width": width, "height": height, "pid": pid]
        print(String(data: try! JSONSerialization.data(withJSONObject: evidence, options: [.sortedKeys]), encoding: .utf8)!)
        exit(0)
    }
    Thread.sleep(forTimeInterval: 1)
}
fputs("Fresh-install onboarding window did not appear\n", stderr)
exit(1)
SWIFT
screencapture -x smoke/onboarding.png
kill -0 "$app_pid"
node --input-type=module -e 'import fs from "node:fs"; const m=JSON.parse(fs.readFileSync(process.argv[1])); fs.writeFileSync("smoke/result.json", JSON.stringify({...m, installed: true, codesign: "ad-hoc verified", architecture: "arm64", updater_archive: "matching installed binary and version", window: "Welcome to Cap", result: "pass"}));' "$manifest"
