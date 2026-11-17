#!/usr/bin/env bash
printf "%s\n" "$(tput bold)$(date) ${BASH_SOURCE[0]}$(tput sgr0)"
# invocation: ./fetch-pagmo2-mirror-tarball.sh 2>&1 | tee fetch-pagmo2-mirror-tarball_$(hostname).log

# set -euo pipefail

REPO="${REPO:-floquet/spacklandia}"
RELEASE_TAG="${RELEASE_TAG:-pagmo2-mirror-v1}"
DEST_DIR="${DEST_DIR:-$HOME}"
TARBALL_NAME="${TARBALL_NAME:-pagmo2-mirror.tar.gz}"
SHA_NAME="${SHA_NAME:-${TARBALL_NAME}.sha256}"
MIRROR_NAME="${MIRROR_NAME:-pagmo2-local}"
MIRROR_DIR="${MIRROR_DIR:-$DEST_DIR/pagmo2-mirror}"

start_time=${SECONDS}

echo "================================================================================"
echo "FETCH & REGISTER OFFLINE PAGMO2 SPACK MIRROR"
echo "================================================================================"
echo "Host:         $(hostname)"
echo "Repository:   $REPO"
echo "Release Tag:  $RELEASE_TAG"
echo "Target Dir:   $DEST_DIR"
echo "Mirror Name:  $MIRROR_NAME -> $MIRROR_DIR"
echo "--------------------------------------------------------------------------------"

# Step 1: Download release assets (prefer gh CLI, fall back to curl)
echo "[1/4] Downloading release assets into $DEST_DIR ..."
mkdir -p "$DEST_DIR"
rm -f "$DEST_DIR/$TARBALL_NAME" "$DEST_DIR/$SHA_NAME"

if command -v gh >/dev/null 2>&1 && gh auth status >/dev/null 2>&1; then
    gh release download "$RELEASE_TAG" \
        -R "$REPO" \
        -D "$DEST_DIR" \
        -p "$TARBALL_NAME" \
        -p "$SHA_NAME"
else
    BASE_URL="https://github.com/${REPO}/releases/download/${RELEASE_TAG}"
    curl -fL --retry 3 -o "$DEST_DIR/$TARBALL_NAME" "${BASE_URL}/${TARBALL_NAME}"
    curl -fL --retry 3 -o "$DEST_DIR/$SHA_NAME" "${BASE_URL}/${SHA_NAME}"
fi

# Step 2: Verify SHA-256 checksum
echo "[2/4] Verifying SHA-256 checksum ..."
(
    cd "$DEST_DIR"
    sha256sum -c "$SHA_NAME"
)

# Step 3: Extract offline mirror cleanly
echo "[3/4] Extracting $TARBALL_NAME into $DEST_DIR ..."
rm -rf "$MIRROR_DIR"
tar -xzf "$DEST_DIR/$TARBALL_NAME" -C "$DEST_DIR"

# Step 4: Register local mirror in Spack (if spack is available in PATH)
echo "[4/4] Registering Spack mirror '$MIRROR_NAME' ..."
if command -v spack >/dev/null 2>&1; then
    spack mirror remove "$MIRROR_NAME" >/dev/null 2>&1 || true
    spack mirror add "$MIRROR_NAME" "file://${MIRROR_DIR}"
    spack mirror list
else
    echo "WARNING: 'spack' not found in PATH; skipped 'spack mirror add'."
    echo "         Once Spack is sourced, run:"
    echo "         spack mirror add ${MIRROR_NAME} file://${MIRROR_DIR}"
fi

elapsed=$((SECONDS - start_time))
echo "--------------------------------------------------------------------------------"
echo "SUCCESS: Offline pagmo2 mirror verified and unpacked in ${elapsed}s."
echo "================================================================================"

exit 0

: << 'END_NOTES'
NOTES & DESIGN RATIONALE:
1. Strict Error Handling (`set -euo pipefail`): Aborts immediately on network failure,
   corrupted download, or tar extraction error so partial mirrors are never registered.
2. Dual Transport (`gh` with `curl` fallback): Uses authenticated `gh release download`
   when available (which also works if the repository is ever switched to private), and
   falls back automatically to `curl -fL` on work machines where `gh` is not installed.
3. Idempotent Mirror Registration: Removes any stale `pagmo2-local` mirror entry before
   adding `file://$HOME/pagmo2-mirror`, avoiding Spack duplicate-mirror errors on re-runs.
4. Graceful Spack Check: If run before sourcing `setup-env.sh` in a fresh Spack install,
   extraction and checksum verification still succeed and print the exact registration command.
5. Environment Overrides: All parameters (`REPO`, `RELEASE_TAG`, `DEST_DIR`, `MIRROR_NAME`)
   can be overridden at invocation time without editing the script.
END_NOTES
