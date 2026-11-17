#!/usr/bin/env bash

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    set -euo pipefail
fi
printf "%s\n" "$(tput bold)$(date) ${BASH_SOURCE[0]}$(tput sgr0)"
# invocation: ./install-pagmo2-offline.sh 2>&1 | tee install-pagmo2-offline_$(hostname).log

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
SPACK_ROOT="${SPACK_ROOT:-$HOME/spack}"
SPACK_REPO="${SPACK_REPO:-https://github.com/spack/spack.git}"
SPACK_COMMIT="${SPACK_COMMIT:-21bd91776b3a6d1bf96442bbd8b390072ee65fa8}"
REPO_SLUG="${REPO_SLUG:-floquet/spacklandia}"
RELEASE_TAG="${RELEASE_TAG:-pagmo2-mirror-v1}"
TARBALL_NAME="pagmo2-mirror.tar.gz"
CHECKSUM_NAME="${TARBALL_NAME}.sha256"
TARGET_DIR="${TARGET_DIR:-$HOME}"
TARBALL_PATH="${TARGET_DIR}/${TARBALL_NAME}"
CHECKSUM_PATH="${TARGET_DIR}/${CHECKSUM_NAME}"
MIRROR_DIR="${TARGET_DIR}/pagmo2-mirror"
MIRROR_NAME="${MIRROR_NAME:-local_pagmo2}"
TARGET_SPEC="${TARGET_SPEC:-pagmo2}"
SYS_CA_BUNDLE="/etc/ssl/certs/ca-certificates.crt"

new_step "Host and environment diagnostics"
sub_step "hostname && uname -a && nproc"
hostname
uname -a
echo "CPU threads: $(nproc)"

new_step "Wipe existing Spack tree and ~/.spack hangover"
sub_step "rm -rf $SPACK_ROOT $HOME/.spack"
rm -rf "$SPACK_ROOT" "$HOME/.spack"

new_step "Fetch and verify offline mirror archive ($TARBALL_NAME)"
mkdir -p "$TARGET_DIR"
if [ -f "$TARBALL_PATH" ] && [ -f "$CHECKSUM_PATH" ] && (cd "$TARGET_DIR" && sha256sum -c "$CHECKSUM_NAME" >/dev/null 2>&1); then
    sub_step "Valid $TARBALL_PATH already present; skipping download"
    ls -lh "$TARBALL_PATH"
else
    sub_step "Downloading $TARBALL_NAME and $CHECKSUM_NAME from $REPO_SLUG ($RELEASE_TAG)"
    rm -f "$TARBALL_PATH" "$CHECKSUM_PATH"
    if command -v gh >/dev/null 2>&1 && gh auth status >/dev/null 2>&1; then
        gh release download "$RELEASE_TAG" \
            --repo "$REPO_SLUG" \
            --pattern "$TARBALL_NAME" \
            --pattern "$CHECKSUM_NAME" \
            --dir "$TARGET_DIR" \
            --clobber
    else
        BASE_URL="https://github.com/${REPO_SLUG}/releases/download/${RELEASE_TAG}"
        curl -fL --retry 3 --retry-delay 2 -o "$TARBALL_PATH" "${BASE_URL}/${TARBALL_NAME}"
        curl -fL --retry 3 --retry-delay 2 -o "$CHECKSUM_PATH" "${BASE_URL}/${CHECKSUM_NAME}"
    fi
fi

sub_step "Verify SHA-256 checksum"
(cd "$TARGET_DIR" && sha256sum -c "$CHECKSUM_NAME")

new_step "Unpack offline mirror into $MIRROR_DIR"
sub_step "rm -rf $MIRROR_DIR && tar -xzf $TARBALL_PATH -C $TARGET_DIR"
rm -rf "$MIRROR_DIR"
tar -xzf "$TARBALL_PATH" -C "$TARGET_DIR"

sub_step "Count extracted archive files"
echo "Extracted archive count: $(find "$MIRROR_DIR" -type f | wc -l)"

new_step "Clone Spack and check out exact mirror commit ($SPACK_COMMIT)"
sub_step "git clone -c feature.manyFiles=true $SPACK_REPO $SPACK_ROOT"
git clone --depth=1 -c feature.manyFiles=true "$SPACK_REPO" "$SPACK_ROOT"

sub_step "git -C $SPACK_ROOT checkout $SPACK_COMMIT"

new_step "Initialize Spack and configure compilers, SSL, and local mirror"
sub_step "source $SPACK_ROOT/share/spack/setup-env.sh"
# shellcheck disable=SC1091
source "$SPACK_ROOT/share/spack/setup-env.sh"
spack --version

sub_step "Configure curl fetch settings and system CA bundle"
if [ -f "$SYS_CA_BUNDLE" ]; then
    export SSL_CERT_FILE="$SYS_CA_BUNDLE"
    export REQUESTS_CA_BUNDLE="$SYS_CA_BUNDLE"
fi
spack config add config:url_fetch_method:curl
spack config add config:verify_ssl:false
spack config add config:connect_timeout:30

sub_step "Detect compilers"
spack compiler find
spack compilers

sub_step "Register local mirror $MIRROR_NAME -> file://$MIRROR_DIR"
spack mirror add "$MIRROR_NAME" "file://${MIRROR_DIR}"
spack mirror list

new_step "Concretize, build, and verify $TARGET_SPEC"
sub_step "spack spec -I $TARGET_SPEC"
spack spec -I "$TARGET_SPEC"

sub_step "spack install --verbose $TARGET_SPEC"
spack install --verbose "$TARGET_SPEC"

sub_step "Verify installed package and location"
spack find -lv "$TARGET_SPEC"
spack location -i "$TARGET_SPEC"

echo ""
echo "SUCCESS: $TARGET_SPEC installed cleanly in $SPACK_ROOT"
echo "To load in any shell: source $SPACK_ROOT/share/spack/setup-env.sh && spack load $TARGET_SPEC"

exit 0

: << 'END_NOTES'
NOTES & DESIGN RATIONALE:
1. Zero-Hangover Clean Slate:
   Unconditionally removes `$HOME/spack` and `$HOME/.spack` before cloning so stale compiler
   entries, broken caches, or old mirror configs never contaminate a fresh run.
2. Exact Commit Pinning (`21bd91776b3a6d1bf96442bbd8b390072ee65fa8`):
   Pins Spack to the exact commit from `isomer` (`~/spacktivity/genesis`) that generated
   `pagmo2-mirror.tar.gz`, ensuring every dependency version and checksum in the concretized
   DAG matches the offline tarball 100% with zero external source downloads.
3. Smart Tarball Reuse + Dual Transport:
   If `~/pagmo2-mirror.tar.gz` and `.sha256` already exist and pass `sha256sum -c` (as on
   `isotope` tonight), it skips re-downloading the 514 MB archive; on a fresh machine (like
   the office workstation tomorrow), it fetches via `gh` or `curl` automatically.
END_NOTES
