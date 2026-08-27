# Bootstrap for the TrustGuard Claude Code plugin (Windows).
#
# Mirror of trustguard-hook.sh: prefers a PATH-installed trustguard-claude-code,
# otherwise installs the pinned release for this arch into
# %USERPROFILE%\.trustguard\bin in the background, verifying its SHA-256
# against the table below. Every bootstrap failure fails open.

param([switch]$InstallOnly)

$Version = '0.1.19'

$Sha256 = @{
    'amd64' = '7d0934af5728a99bc2ffeb76b68b39c318ea2743c0e23f8f550f1065f5d29776'
    'arm64' = '9abf5d8cf392371157d6938e638372764871662efa384e4df82469ee8196d3b0'
}

$Stdin = if ($InstallOnly) { $null } else { [Console]::In.ReadToEnd() }

function Invoke-Hook([string]$Exe) {
    $out = $Stdin | & $Exe hook
    if ($null -ne $out) { Write-Output $out }
    exit $LASTEXITCODE
}

function Exit-FailOpen([string]$Message) {
    [Console]::Error.WriteLine("trustguard-claude-code bootstrap: $Message - allowing without evaluation")
    Write-Output '{}'
    exit 0
}

function Install-Binary([string]$Url, [string]$Target, [string]$WantSha) {
    $tmp = "$Target.download.$PID"
    try {
        Invoke-WebRequest -UseBasicParsing -Uri $Url -OutFile $tmp -TimeoutSec 300
        $gotSha = (Get-FileHash -Algorithm SHA256 -Path $tmp).Hash.ToLowerInvariant()
        if ($gotSha -ne $WantSha.ToLowerInvariant()) { throw "checksum mismatch (got $gotSha, want $WantSha)" }
        Move-Item -Force $tmp $Target
    } catch {
        Remove-Item -Force -ErrorAction SilentlyContinue $tmp
        [Console]::Error.WriteLine("trustguard-claude-code bootstrap: install failed: $($_.Exception.Message)")
    }
}

try {
    # MDM / ProgramData first — org binary must win over any developer PATH copy.
    $programData = if ($env:ProgramData) { $env:ProgramData } else { 'C:\ProgramData' }
    $mdmBin = Join-Path $programData 'TrustGuard\bin\trustguard-claude-code.exe'
    if ((Test-Path $mdmBin) -and -not $InstallOnly) { Invoke-Hook $mdmBin }

    $onPath = Get-Command 'trustguard-claude-code' -ErrorAction SilentlyContinue
    if ($onPath -and -not $InstallOnly) { Invoke-Hook $onPath.Source }

    $binDir = if ($env:TRUSTGUARD_CLAUDE_CODE_BIN_DIR) { $env:TRUSTGUARD_CLAUDE_CODE_BIN_DIR } else { Join-Path $env:USERPROFILE '.trustguard\bin' }
    $baseUrl = if ($env:TRUSTGUARD_CLAUDE_CODE_DOWNLOAD_BASE) { $env:TRUSTGUARD_CLAUDE_CODE_DOWNLOAD_BASE } else { 'https://github.com/NeuralTrust/trustguard-claude-code-plugin/releases/download' }

    $localBin = Join-Path $binDir 'trustguard-claude-code.exe'
    if ((Test-Path $localBin) -and -not $InstallOnly) { Invoke-Hook $localBin }

    $bin = Join-Path $binDir "trustguard-claude-code-$Version.exe"
    if ((Test-Path $bin) -and -not $InstallOnly) { Invoke-Hook $bin }

    $arch = switch ($env:PROCESSOR_ARCHITECTURE) {
        'AMD64' { 'amd64' }
        'ARM64' { 'arm64' }
        default { Exit-FailOpen "unsupported arch $($env:PROCESSOR_ARCHITECTURE); install trustguard-claude-code manually" }
    }
    $wantSha = $Sha256[$arch]
    if (-not $wantSha) {
        Exit-FailOpen "no pinned checksum for windows/$arch (release $Version not published yet?); install trustguard-claude-code manually"
    }

    $url = "$baseUrl/v$Version/trustguard-claude-code_${Version}_windows_$arch.exe"
    New-Item -ItemType Directory -Force -Path $binDir | Out-Null
    $lock = Join-Path $binDir "install-claude-code-$Version.lock"

    if ($InstallOnly) {
        Install-Binary $url $bin $wantSha
        Remove-Item -Force -Recurse -ErrorAction SilentlyContinue $lock
        exit 0
    }

    if ((Test-Path $lock) -and ((Get-Item $lock).CreationTime -lt (Get-Date).AddMinutes(-10))) {
        Remove-Item -Force -Recurse -ErrorAction SilentlyContinue $lock
    }
    if (-not (Test-Path $lock)) {
        New-Item -ItemType Directory -Path $lock -ErrorAction SilentlyContinue | Out-Null
        Start-Process -FilePath 'powershell' -WindowStyle Hidden -ArgumentList @(
            '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $PSCommandPath, '-InstallOnly'
        )
    }
    Exit-FailOpen "trustguard-claude-code $Version not installed yet; fetching it in the background"
} catch {
    Exit-FailOpen "unexpected error: $($_.Exception.Message)"
}
