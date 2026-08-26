#!/bin/sh
# Bootstrap for the TrustGuard Claude Code plugin (macOS/Linux).
#
# Claude Code invokes this script on each hook event. It executes trustguard-claude-code
# from the PATH when present (manual/MDM installs win); otherwise it installs
# the pinned release for this OS/arch into ~/.trustguard/bin in the background,
# verifying its SHA-256 against the table below, and evaluates from the next
# event on. Every bootstrap failure fails open (Claude Code must never brick) with a
# warning on stderr.
#
# The VERSION and SHA256_* table are updated per release.
set -u

VERSION="0.1.16"
BASE_URL="${TRUSTGUARD_CLAUDE_CODE_DOWNLOAD_BASE:-https://github.com/NeuralTrust/trustguard-claude-code-plugin/releases/download}"
BIN_DIR="${TRUSTGUARD_CLAUDE_CODE_BIN_DIR:-$HOME/.trustguard/bin}"

# Per-platform SHA-256 of the release binaries (filled per release).
SHA256_darwin_amd64="085b4e89d86059db317637f2972428a012977cfa8e555a2127884774f4c7d162"
SHA256_darwin_arm64="f27955893796950e459e372f90d9f34b3e3f1187f848666ee32904f638e950c8"
SHA256_linux_amd64="463f22ba20ca945fbf0edac56e4a368039c09076c654e245e729a8ffb4d61a3f"
SHA256_linux_arm64="efac5e45ef3d640a4bb5dc33699765f6fbbd98df50f72ac38b1e5de22da68e71"
SHA256_windows_amd64="5560f81d328a0af3e4e3332192311b46d1be25e38459065fbee46cdf5d05f1b7"
SHA256_windows_arm64="1d4c522c7097001031a5a248d29b794ef6c822993b42ecf484c086246438235e"

fail_open() {
    echo "trustguard-claude-code bootstrap: $1 — allowing without evaluation" >&2
    # Empty allow: Claude Code continues when stdout is empty / exit 0.
    printf '{}\n'
    exit 0
}

EXT=""
case "$(uname -s)" in
    Darwin) OS="darwin" ;;
    Linux) OS="linux" ;;
    MINGW* | MSYS* | CYGWIN*) OS="windows" EXT=".exe" ;;
    *) OS="" ;;
esac

# MDM (Kandji) first — org binary must win over any developer PATH copy.
MDM_BIN="/Library/Application Support/TrustGuard/bin/trustguard-claude-code$EXT"
if [ -x "$MDM_BIN" ]; then
    exec "$MDM_BIN" hook
fi

if command -v trustguard-claude-code >/dev/null 2>&1; then
    exec trustguard-claude-code hook
fi

# Local install (make install-local) drops an unversioned binary here.
LOCAL_BIN="$BIN_DIR/trustguard-claude-code$EXT"
if [ -x "$LOCAL_BIN" ]; then
    exec "$LOCAL_BIN" hook
fi

BIN="$BIN_DIR/trustguard-claude-code-$VERSION$EXT"
if [ -x "$BIN" ]; then
    exec "$BIN" hook
fi

if [ -z "$OS" ]; then
    fail_open "unsupported OS $(uname -s); install trustguard-claude-code manually"
fi
case "$(uname -m)" in
    x86_64 | amd64) ARCH="amd64" ;;
    arm64 | aarch64) ARCH="arm64" ;;
    *) fail_open "unsupported arch $(uname -m); install trustguard-claude-code manually" ;;
esac

WANT_SHA=$(eval "printf '%s' \"\${SHA256_${OS}_${ARCH}:-}\"")
if [ -z "$WANT_SHA" ]; then
    fail_open "no pinned checksum for ${OS}/${ARCH} (release ${VERSION} not published yet?); install trustguard-claude-code manually"
fi

URL="$BASE_URL/v$VERSION/trustguard-claude-code_${VERSION}_${OS}_${ARCH}${EXT}"
mkdir -p "$BIN_DIR" 2>/dev/null || fail_open "cannot create $BIN_DIR"

install_binary() {
    TMP="$BIN.download.$$"
    if command -v curl >/dev/null 2>&1; then
        curl -fsSL --connect-timeout 5 --max-time 300 -o "$TMP" "$URL" || { rm -f "$TMP"; return 1; }
    elif command -v wget >/dev/null 2>&1; then
        wget -q -T 300 -O "$TMP" "$URL" || { rm -f "$TMP"; return 1; }
    else
        return 1
    fi

    if command -v sha256sum >/dev/null 2>&1; then
        GOT_SHA=$(sha256sum "$TMP" | cut -d' ' -f1)
    elif command -v shasum >/dev/null 2>&1; then
        GOT_SHA=$(shasum -a 256 "$TMP" | cut -d' ' -f1)
    else
        rm -f "$TMP"
        return 1
    fi
    if [ "$GOT_SHA" != "$WANT_SHA" ]; then
        rm -f "$TMP"
        return 1
    fi

    chmod 0755 "$TMP" || { rm -f "$TMP"; return 1; }
    mv -f "$TMP" "$BIN" || { rm -f "$TMP"; return 1; }
}

LOCK="$BIN_DIR/install-claude-code-$VERSION.lock"
if [ -d "$LOCK" ] && [ -n "$(find "$LOCK" -maxdepth 0 -mmin +10 2>/dev/null)" ]; then
    rmdir "$LOCK" 2>/dev/null || :
fi
if mkdir "$LOCK" 2>/dev/null; then
    ( install_binary; rmdir "$LOCK" 2>/dev/null ) >/dev/null 2>&1 &
fi
fail_open "trustguard-claude-code $VERSION not installed yet; fetching it in the background"
