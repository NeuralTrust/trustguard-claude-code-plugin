# Bootstrap for the TrustGuard Claude Code plugin (Windows).
#
# Mirror of trustguard-hook.sh: prefers a PATH-installed trustguard-claude-code,
# otherwise installs the pinned release for this arch into
# %USERPROFILE%\.trustguard\bin in the background, verifying its SHA-256
# against the table below. Every bootstrap failure fails open.

param([switch]$InstallOnly)

$Version = '0.1.20'

$Sha256 = @{
    'amd64' = '302f7c963c1c9889b9523dc91c161adeed0e2e5c9fa82db9bcbff5f4c935590d'
    'arm64' = '9c5608ddb714d18717da6e07dd5c792c1c0826899b6ed954b0b8a5fe44f6b697'
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
