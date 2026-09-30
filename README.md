<p align="center">
  <p align="center">
   <img width="150" height="150" src="https://github.com/CapSoftware/Cap/blob/main/apps/desktop/src-tauri/icons/Square310x310Logo.png" alt="Logo">
  </p>
	<h1 align="center"><b>Cap</b></h1>
	<p align="center">
		The open source Loom alternative.
    <br />
    <a href="https://cap.so"><strong>Cap.so »</strong></a>
    <br />
    <br />
    <b>Internal Downloads: </b>
		<a href="https://github.com/r90group/Cap/releases/tag/internal-latest">macOS & Windows builds</a>
    <br />
  </p>
</p>
<br/>

[![Open Bounties](https://img.shields.io/endpoint?url=https%3A%2F%2Fconsole.algora.io%2Fapi%2Fshields%2FCapSoftware%2Fbounties%3Fstatus%3Dopen)](https://console.algora.io/org/CapSoftware/bounties?status=open)

Cap is the open source alternative to Loom. It's a video messaging tool that allows you to record, edit and share videos in seconds.

<img src="https://raw.githubusercontent.com/CapSoftware/Cap/refs/heads/main/apps/web/public/landing-cover.png"/>

# Our Deployment

This R90 fork runs against an internal self-hosted Cap instance deployed on **[Railway](https://railway.com/)**. Desktop builds produced by the workflow below are pre-configured to talk to that instance.

For access to the Railway project, environment variables, deployment issues, or anything else about our internal instance, ping **[@jacogrande](https://github.com/jacogrande)**.

## Downloading the Desktop App

Every merge to `main` whose push CI passes publishes the R90 fork desktop app automatically. Download the current healthy build from **[Internal Downloads](https://github.com/r90group/Cap/releases/tag/internal-latest)**:

- macOS Apple Silicon (M1/M2/M3/M4): `*_aarch64.dmg`
- Windows x64: `*_x64-setup.exe`

The channel links to immutable, exact-revision release assets. Installer checksums, Tauri updater signatures, the updater public key, target/revision manifests, and the installed-app smoke run are linked from the release. Intel Mac builds are not supported by this fork's publication workflow.

### First-launch warnings (expected)

These internal builds retain the fork's existing signing boundary: macOS bundles are ad-hoc signed, not Apple Developer ID signed or notarized; Windows installers are not Authenticode signed. Tauri updater artifacts are signed with the existing fork key.

- **macOS**: right-click the app → Open the first time, or run `xattr -dr com.apple.quarantine /Applications/Cap.app` after installing.
- **Windows**: SmartScreen will warn you — click "More info" → "Run anyway".

## Building the Desktop App

The [`publish` workflow](.github/workflows/publish.yml) follows successful **push** CI on `main`, checks out that exact revision, and builds macOS Apple Silicon and Windows x64 in parallel. No release dispatch, version bump, Discord interaction, or human approval is required.

Pull requests build the same production configuration and install/launch the resulting artifacts without publishing. Publication verifies updater signatures before exposing a complete immutable candidate. Native smoke runners then download that published candidate, check its checksums and installed version, install it in a disposable directory, and launch the fresh-install `Welcome to Cap` window. Logs, screenshots and target/revision results are retained in the workflow artifacts; screenshots still need visual inspection for the first observed release. Only both successful native walks advance `internal-latest`; a failed or cancelled walk withdraws the candidate and leaves the last healthy channel unchanged. Agent triage can rerun failed jobs against the authenticated draft assets, or rerun all jobs to complete an interrupted draft upload; already published healthy assets are not overwritten. Promotion failures restore the prior channel. The previous rolling release's files are retained under its exact-revision tag during cutover.

The workflow publishes to **r90group/Cap GitHub Releases**, never upstream CrabNebula, upstream Discord, upstream signing services or upstream Sentry. It does not activate the upstream automatic-update channel. Each green revision gets its own immutable candidate and smoke; newer healthy revisions may supersede an intermediate channel promotion. First-launch Gatekeeper/SmartScreen consent and screen/microphone grants are not bypassed or exercised by this isolated, unquarantined startup smoke. Private recordings, authenticated uploads and the Railway runtime are outside this artifact-publication walk.

Kaylee's triage engineer can restore a later-discovered regression to a previously smoke-verified revision using:

```bash
REVISION=<previous-smoke-verified-full-sha>
gh api repos/r90group/Cap/git/refs/tags/internal-latest --method PATCH -f sha="$REVISION" -F force=true
gh release edit internal-latest --repo r90group/Cap --title "Internal build ${REVISION:0:12}" --notes "Restored healthy build and downloads: https://github.com/r90group/Cap/releases/tag/internal-$REVISION"
gh api repos/r90group/Cap/git/ref/tags/internal-latest --jq .object.sha
```

Already installed copies are not silently replaced. Preserve the earlier immutable installers and signing identity.

Railway's existing GitHub App integration deploys application changes to the self-hosted runtime independently. Desktop publication does not change its services, credentials, database, migrations, or watch-path policy.

### Release failures and agent triage

Failed default-branch CI/publication and Railway deployment statuses go through GitHub hook **689911713** to the approved signed R90 intake at `https://kaylee-alert-intake.misty-step.workers.dev/github/r90group`, never a human inbox. This fork has an explicit hook because the central automatic route guard excludes forks. Kaylee owns agent triage; inspect the failed run and retained smoke evidence before repair.

Exercise the route without publishing or touching user data with `gh workflow run alert-route-probe.yml --repo r90group/Cap --ref main`. Its intentional failed run is labelled `alert-route-probe`; delivery is proven by the hook's HTTP 200 receipt and the agent intake record, not by the workflow file alone.

### Required repo secrets

The workflow depends on three repository secrets (**Settings → Secrets and variables → Actions**):

| Secret | Purpose |
|---|---|
| `SELF_HOST_URL` | Base URL of our Railway-hosted Cap instance (no trailing slash). Baked into builds as `VITE_SERVER_URL`. |
| `TAURI_SIGNING_PRIVATE_KEY` | Existing fork Tauri updater signing key. Publication verifies its signatures and signs the installer checksum inventory. Do not rotate it as part of a routine release. |
| `TAURI_SIGNING_PRIVATE_KEY_PASSWORD` | Password for the key above (can be empty). |

If any of these need rotating or you're standing up a new fork, talk to @jacogrande.

# Self Hosting (upstream)

### Quick Start (One Command)

```bash
git clone https://github.com/CapSoftware/Cap.git && cd Cap && docker compose up -d
```

Cap will be running at `http://localhost:3000`. That's it!

> **Note:** Login links appear in the logs (`docker compose logs cap-web`) since email isn't configured by default.

### Other Deployment Options

| Method | Best For |
|--------|----------|
| **Docker Compose** | VPS, home servers, any Docker host |
| **[Railway](https://railway.com/new/template/PwpGcf)** | One-click managed hosting |
| **Coolify** | Self-hosted PaaS (use `docker-compose.coolify.yml`) |

[![Deploy on Railway](https://railway.com/button.svg)](https://railway.com/new/template/PwpGcf)

### Production Configuration

For production, create a `.env` file:

```bash
CAP_URL=https://cap.yourdomain.com
S3_PUBLIC_URL=https://s3.yourdomain.com
```

See our [self-hosting docs](https://cap.so/docs/self-hosting) for full configuration options including email setup, AI features, and SSL.

Cap Desktop can connect to your self-hosted instance via Settings → Cap Server URL.

# Monorepo App Architecture

We use a combination of Rust, React (Next.js), TypeScript, Tauri, Drizzle (ORM), MySQL, TailwindCSS throughout this Turborepo powered monorepo.

> A note about database: The codebase is currently designed to work with MySQL only. MariaDB or other compatible databases might partially work but are not officially supported.

### Apps:

- `desktop`: A [Tauri](https://tauri.app) (Rust) app, using [SolidStart](https://start.solidjs.com) on the frontend.
- `web`: A [Next.js](https://nextjs.org) web app.

### Packages:

- `ui`: A [React](https://reactjs.org) Shared component library.
- `utils`: A [React](https://reactjs.org) Shared utility library.
- `tsconfig`: Shared `tsconfig` configurations used throughout the monorepo.
- `database`: A [React](https://reactjs.org) and [Drizzle ORM](https://orm.drizzle.team/) Shared database library.
- `config`: `eslint` configurations (includes `eslint-config-next`, `eslint-config-prettier` other configs used throughout the monorepo).

### License:
Portions of this software are licensed as follows:

- All code residing in the `cap-camera*` and `scap-*` families of crates is licensed under the MIT License (see [licenses/LICENSE-MIT](https://github.com/CapSoftware/Cap/blob/main/licenses/LICENSE-MIT)).
- All third party components are licensed under the original license provided by the owner of the applicable component
- All other content not mentioned above is available under the AGPLv3 license as defined in [LICENSE](https://github.com/CapSoftware/Cap/blob/main/LICENSE)
  
# Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for more information. This guide is a work in progress, and is updated regularly as the app matures.

## Analytics (Tinybird)

Cap uses [Tinybird](https://www.tinybird.co) to ingest viewer telemetry for dashboards. The Tinybird admin token (`TINYBIRD_ADMIN_TOKEN` or `TINYBIRD_TOKEN`) must be available in your environment. Once the token is present you can:

- Provision the required data sources and materialized views via `pnpm analytics:setup`. This command installs the Tinybird CLI (if needed), runs `tb login` when a `.tinyb` credential file is missing, copies that credential into `scripts/analytics/tinybird`, and finally executes `tb deploy --allow-destructive-operations --wait` from that directory. **It synchronizes the Tinybird workspace to the resources defined in `scripts/analytics/tinybird`, removing any other datasources/pipes in that workspace.**
- Validate that the schema and materialized views match what the app expects via `pnpm analytics:check`.

Both commands target the workspace pointed to by `TINYBIRD_HOST` (defaults to `https://api.tinybird.co`). Make sure you are comfortable with the destructive nature of the deploy step before running `analytics:setup`.
