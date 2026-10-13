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

VERSION="0.1.22"
BASE_URL="${TRUSTGUARD_CLAUDE_CODE_DOWNLOAD_BASE:-https://github.com/NeuralTrust/trustguard-claude-code-plugin/releases/download}"
BIN_DIR="${TRUSTGUARD_CLAUDE_CODE_BIN_DIR:-$HOME/.trustguard/bin}"

# Per-platform SHA-256 of the release binaries (filled per release).
SHA256_darwin_amd64="4b07c499b8dd6d78a35706d02d1dcaab334b69d7ab6ece37b9c09dac41ac4cad"
SHA256_darwin_arm64="132bff09b2744f4eb920ce5477e26c1ecdfc0fe9ff421a7de6be6934d7ac35af"
SHA256_linux_amd64="ac188c711649ced5cdbef74c27dd9aa21f2a7c2ac252331db555366f04536772"
SHA256_linux_arm64="e0ef2627f0791c3456c1966332ccc8446187dc591091757f7795723df2e66d45"
SHA256_windows_amd64="5c478de84de5669ffbf515fd5fbf3fbedaeddb97abe9f6ae3f3ccb785df95996"
SHA256_windows_arm64="b931233cd3f233cf7ab5400bb99f617b8cc432a21dd9c397a2b05d9096702a6c"

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
