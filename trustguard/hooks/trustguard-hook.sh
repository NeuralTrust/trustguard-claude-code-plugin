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

VERSION="0.1.15"
BASE_URL="${TRUSTGUARD_CLAUDE_CODE_DOWNLOAD_BASE:-https://github.com/NeuralTrust/trustguard-claude-code-plugin/releases/download}"
BIN_DIR="${TRUSTGUARD_CLAUDE_CODE_BIN_DIR:-$HOME/.trustguard/bin}"

# Per-platform SHA-256 of the release binaries (filled per release).
SHA256_darwin_amd64="f8adb3a204d1de91a21c5f8c2699d9199e97ff4793f0e948a8d10cb3c68fca55"
SHA256_darwin_arm64="d1d4505a30298c51a5714f60e9a6ed104955597b6d2ff2ab79f3c0a9ed40b8c5"
SHA256_linux_amd64="97da71c43cf98fdc652e237de4e0d4ed105586184bbfe796e272b59a06fd39cc"
SHA256_linux_arm64="0c41bb2781308c929fc3026fd81a2c8d737ea560ebe2979a3d9ea23a9b1dbe30"
SHA256_windows_amd64="c9f49b00072c6dc54c5efbba51b01ef1b3fc76eb43ad98c487fb97269613ee5b"
SHA256_windows_arm64="3e840c0f5354879e7b52e827c6e86e8b5dd884db806c0bdd0e9adcd1dd655882"

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
