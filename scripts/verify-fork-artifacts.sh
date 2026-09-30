set -euo pipefail
signature_dir=$(mktemp -d)
trap 'rm -rf "$signature_dir"' EXIT
export SIGNATURE_DIR="$signature_dir"
node --input-type=module <<'NODE'
import fs from 'node:fs';
const files = fs.readdirSync('artifacts');
for (const suffix of ['_aarch64.dmg', '.app.tar.gz', '_x64-setup.exe']) {
  if (files.filter(name => name.endsWith(suffix)).length !== 1) throw new Error(`Expected exactly one ${suffix} artifact`);
}
for (const target of ['aarch64-apple-darwin', 'x86_64-pc-windows-msvc']) {
  const manifest = JSON.parse(fs.readFileSync(`artifacts/release-${target}.json`));
  if (manifest.revision !== process.env.RELEASE_SHA || manifest.target !== target) throw new Error(`Wrong artifact revision or target: ${target}`);
}
for (const name of files.filter(name => name.endsWith('.exe') || name.endsWith('.app.tar.gz'))) {
  const signature = fs.readFileSync(`artifacts/${name}.sig`, 'utf8');
  fs.writeFileSync(`${process.env.SIGNATURE_DIR}/${name}.minisig`, Buffer.from(signature.trim(), 'base64'));
}
NODE
fork_signing_key() {
  node --input-type=module <<'NODE'
const key = process.env.TAURI_SIGNING_PRIVATE_KEY;
if (!key) throw new Error('Fork updater signing key is missing');
process.stdout.write(key.startsWith('untrusted comment:') ? key : Buffer.from(key.trim(), 'base64'));
NODE
}
printf '%s\n' "$TAURI_SIGNING_PRIVATE_KEY_PASSWORD" | minisign -R -s <(fork_signing_key) -p artifacts/updater.pub
for signature in "$signature_dir"/*.minisig; do
  name=$(basename "$signature" .minisig)
  minisign -V -m "artifacts/$name" -x "$signature" -p artifacts/updater.pub
done
(
  cd artifacts
  sha256sum -- * > SHA256SUMS
)
printf '%s\n' "$TAURI_SIGNING_PRIVATE_KEY_PASSWORD" | minisign -S -s <(fork_signing_key) -m artifacts/SHA256SUMS -x artifacts/SHA256SUMS.minisig
minisign -V -m artifacts/SHA256SUMS -x artifacts/SHA256SUMS.minisig -p artifacts/updater.pub
