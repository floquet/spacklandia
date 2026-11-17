#!/usr/bin/env bash
# invocation: ./03-fetch-mirror-tarball.sh 2>&1 | tee 03-fetch-mirror-tarball_$(hostname).log
printf "%s\n" "$(tput bold)$(date) ${BASH_SOURCE[0]}$(tput sgr0)"

# ==============================================================================
# PURPOSE:
#   Standalone helper to download, checksum-verify, unpack, and register the
#   offline pagmo2 Spack mirror tarball (pagmo2-mirror.tar.gz) from GitHub
#   Releases (floquet/spacklandia) into $HOME.
#
# WHEN TO USE:
#   Run this first if ~/pagmo2-mirror.tar.gz is NOT yet on disk before running
#   ./01-install-pagmo2-offline.sh or ./02-mirror-only-install.sh.
#
# OVERRIDES:
#   REPO="floquet/spacklandia" RELEASE_TAG="pagmo2-mirror-v1" ./03-fetch-mirror-tarball.sh
# ==============================================================================

counter=0
subcounter=0
start_time=${SECONDS}

function new_step() {
    export counter=$((counter + 1))
    export subcounter=0
    echo ""
    echo "===================================================================="
    echo "Step ${counter}: ${1}"
    echo "===================================================================="
}

function sub_step() {
    export subcounter=$((subcounter + 1))
    echo ""
    echo "  Substep ${counter}.${subcounter}: ${1}"
}

function display_total_elapsed_time() {
    local total_elapsed_time=$((SECONDS - start_time))
    local total_minutes=$((total_elapsed_time / 60))
    local total_seconds=$((total_elapsed_time % 60))
    echo ""
    printf "Total elapsed time: %02d:%02d (MM:SS)\n" "$total_minutes" "$total_seconds"
}

trap display_total_elapsed_time EXIT

# Configuration (override via environment variables if desired)
REPO="${REPO:-floquet/spacklandia}"
RELEASE_TAG="${RELEASE_TAG:-pagmo2-mirror-v1}"
DEST_DIR="${DEST_DIR:-$HOME}"
TARBALL_NAME="${TARBALL_NAME:-pagmo2-mirror.tar.gz}"
SHA_NAME="${SHA_NAME:-${TARBALL_NAME}.sha256}"
MIRROR_NAME="${MIRROR_NAME:-local_pagmo2}"
MIRROR_DIR="${MIRROR_DIR:-$DEST_DIR/pagmo2-mirror}"

new_step "Stabilize WSL network MTU (if eth0 is present)"
    # HINT: Prevents mid-stream curl/gh truncation when fetching the ~514 MB tarball.
    sub_step "Check eth0 MTU"
              if ip link show eth0 >/dev/null 2>&1; then
                  sudo ip link set dev eth0 mtu 1400 || true
              fi

new_step "Download release assets ($TARBALL_NAME and $SHA_NAME) into $DEST_DIR"
    # HINT: Uses authenticated 'gh release download' if available (works on both
    # public and private repos); falls back automatically to curl with retries.
    sub_step "Clean any partial downloads in $DEST_DIR"
              mkdir -p "$DEST_DIR"
              rm -f "$DEST_DIR/$TARBALL_NAME" "$DEST_DIR/$SHA_NAME"

    sub_step "Fetch assets from $REPO ($RELEASE_TAG)"
              if command -v gh >/dev/null 2>&1 && gh auth status >/dev/null 2>&1; then
                  gh release download "$RELEASE_TAG" \
                      -R "$REPO" \
                      -D "$DEST_DIR" \
                      -p "$TARBALL_NAME" \
                      -p "$SHA_NAME"
              else
                  BASE_URL="https://github.com/${REPO}/releases/download/${RELEASE_TAG}"
                  curl -fL --retry 3 --retry-delay 2 -o "$DEST_DIR/$TARBALL_NAME" "${BASE_URL}/${TARBALL_NAME}"
                  curl -fL --retry 3 --retry-delay 2 -o "$DEST_DIR/$SHA_NAME" "${BASE_URL}/${SHA_NAME}"
              fi

new_step "Verify SHA-256 checksum"
    # HINT: Aborts if the downloaded tarball does not match its .sha256 digest.
    sub_step "sha256sum -c $SHA_NAME"
              (
                  cd "$DEST_DIR"
                  sha256sum -c "$SHA_NAME"
              )
              if [ $? -ne 0 ]; then
                  echo "ERROR: Checksum verification failed for $DEST_DIR/$TARBALL_NAME"
                  exit 1
              fi

new_step "Extract offline mirror into $MIRROR_DIR"
    sub_step "rm -rf $MIRROR_DIR && tar -xzf $DEST_DIR/$TARBALL_NAME -C $DEST_DIR"
              rm -rf "$MIRROR_DIR"
              tar -xzf "$DEST_DIR/$TARBALL_NAME" -C "$DEST_DIR"

    sub_step "Audit extracted archive count"
              echo "Extracted archive count: $(find "$MIRROR_DIR" -type f | wc -l)"

new_step "Register local mirror in Spack (if spack is already in PATH)"
    # HINT: If you have not installed Spack yet, run ./01-install-pagmo2-offline.sh next;
    # it will automatically reuse the verified tarball in $DEST_DIR without re-downloading.
    sub_step "Check for spack command"
              if command -v spack >/dev/null 2>&1; then
                  spack mirror remove "$MIRROR_NAME" >/dev/null 2>&1 || true
                  spack mirror add "$MIRROR_NAME" "file://${MIRROR_DIR}"
                  spack mirror list
              else
                  echo "NOTE: 'spack' not in PATH yet; skipping 'spack mirror add'."
                  echo "      Next step: run ./01-install-pagmo2-offline.sh"
              fi

echo ""
echo "SUCCESS: Offline pagmo2 mirror verified and unpacked at $MIRROR_DIR"
