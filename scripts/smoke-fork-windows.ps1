$ErrorActionPreference = 'Stop'
New-Item -ItemType Directory -Force smoke | Out-Null
Get-Content artifacts/SHA256SUMS | ForEach-Object {
    if ($_ -notmatch '^([0-9a-f]{64}) [ *](.+)$') { throw 'Invalid published checksum inventory line' }
    $expectedHash = $Matches[1]
    $name = $Matches[2]
    $actual = (Get-FileHash (Join-Path artifacts $name) -Algorithm SHA256).Hash.ToLower()
    if ($actual -ne $expectedHash) { throw "Published checksum mismatch: $name" }
}
$manifest = Get-Content artifacts/release-x86_64-pc-windows-msvc.json | ConvertFrom-Json
if ($manifest.revision -ne $env:RELEASE_SHA) { throw 'Published revision mismatch' }
$installer = Get-Item artifacts/*_x64-setup.exe
$installDir = Join-Path $env:RUNNER_TEMP 'cap-installed'
$install = Start-Process $installer.FullName -ArgumentList '/S', "/D=$installDir" -PassThru -Wait
if ($install.ExitCode -ne 0) { throw "Installer failed with exit $($install.ExitCode)" }
$config = Get-Content apps/desktop/src-tauri/tauri.prod.conf.json | ConvertFrom-Json
$binary = Join-Path $installDir "$($config.mainBinaryName).exe"
$version = (Get-Item $binary).VersionInfo.ProductVersion
if ($version -ne $manifest.version) { throw "Installed version $version differs from $($manifest.version)" }
$process = Start-Process $binary -PassThru -RedirectStandardOutput smoke/startup.log -RedirectStandardError smoke/stderr.log
try {
    $ready = $false
    for ($attempt = 0; $attempt -lt 60; $attempt++) {
        $process.Refresh()
        if ($process.HasExited) { throw "Installed app exited with $($process.ExitCode)" }
        if ($process.MainWindowTitle -eq 'Welcome to Cap') { $ready = $true; break }
        Start-Sleep -Seconds 1
    }
    if (-not $ready) { throw "Fresh-install onboarding window did not appear; title: $($process.MainWindowTitle)" }
    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing
    $bounds = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds
    $image = New-Object System.Drawing.Bitmap $bounds.Width, $bounds.Height
    $graphics = [System.Drawing.Graphics]::FromImage($image)
    try {
        $graphics.CopyFromScreen($bounds.Location, [System.Drawing.Point]::Empty, $bounds.Size)
        $image.Save((Join-Path $PWD 'smoke/onboarding.png'))
    } finally {
        $graphics.Dispose()
        $image.Dispose()
    }
    @{
        revision = $manifest.revision
        version = $manifest.version
        target = $manifest.target
        installed = $true
        window = $process.MainWindowTitle
        result = 'pass'
    } | ConvertTo-Json | Set-Content smoke/result.json
} finally {
    if (-not $process.HasExited) { Stop-Process -Id $process.Id }
}
