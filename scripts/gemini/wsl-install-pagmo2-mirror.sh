#!/usr/bin/env bash

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    set -euo pipefail
fi
printf "%s\n" "$(tput bold)$(date) ${BASH_SOURCE[0]}$(tput sgr0)"

# invocation: ./wsl-install-pagmo2-mirror.sh 2>&1 | tee wsl-install-pagmo2-mirror.log

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

# Configuration: override via environment variables if paths differ
SPACK_ROOT="${SPACK_ROOT:-$HOME/spack}"
TARBALL_PATH="${TARBALL_PATH:-$HOME/pagmo2-mirror.tar.gz}"
MIRROR_PARENT="${MIRROR_PARENT:-$HOME}"
MIRROR_DIR="${MIRROR_PARENT}/pagmo2-mirror"
MIRROR_NAME="${MIRROR_NAME:-local_pagmo2}"
TARGET_SPEC="${TARGET_SPEC:-pagmo2}"

# Begin steps
new_step "Verify tarball exists and check SHA-256 integrity"
sub_step "ls -lh $TARBALL_PATH"
if [ ! -f "$TARBALL_PATH" ]; then
    echo "Error: Tarball not found at $TARBALL_PATH"
    echo "Set TARBALL_PATH=/path/to/pagmo2-mirror.tar.gz and re-run."
    exit 1
fi
ls -lh "$TARBALL_PATH"

sub_step "Verify ${TARBALL_PATH}.sha256 if present"
if [ -f "${TARBALL_PATH}.sha256" ]; then
    (cd "$(dirname "$TARBALL_PATH")" && sha256sum -c "$(basename "${TARBALL_PATH}.sha256")")
else
    echo "No .sha256 checksum file found alongside tarball; skipping checksum verification."
fi

new_step "Unpack mirror archive into $MIRROR_PARENT"
sub_step "rm -rf $MIRROR_DIR && tar -xzf $TARBALL_PATH -C $MIRROR_PARENT"
rm -rf "$MIRROR_DIR"
tar -xzf "$TARBALL_PATH" -C "$MIRROR_PARENT"

sub_step "find $MIRROR_DIR -type f | wc -l"
echo "Extracted archive count: $(find "$MIRROR_DIR" -type f | wc -l)"

new_step "Initialize Spack shell environment"
sub_step "source $SPACK_ROOT/share/spack/setup-env.sh"
if ! command -v spack >/dev/null 2>&1; then
    source "$SPACK_ROOT/share/spack/setup-env.sh"
fi
spack --version

new_step "Register local filesystem mirror in Spack"
sub_step "spack mirror remove $MIRROR_NAME (if already exists)"
spack mirror remove "$MIRROR_NAME" 2>/dev/null || true

sub_step "spack mirror add $MIRROR_NAME file://$MIRROR_DIR"
spack mirror add "$MIRROR_NAME" "file://$MIRROR_DIR"

sub_step "spack mirror list"
spack mirror list

new_step "Inspect concretized spec for $TARGET_SPEC"
sub_step "spack spec -I $TARGET_SPEC"
spack spec -I "$TARGET_SPEC"

new_step "Compile and install $TARGET_SPEC from local mirror"
sub_step "spack install --verbose $TARGET_SPEC"
spack install --verbose "$TARGET_SPEC"

new_step "Verify installation and print install prefix"
sub_step "spack find -lv $TARGET_SPEC"
spack find -lv "$TARGET_SPEC"

sub_step "spack location -i $TARGET_SPEC"
spack location -i "$TARGET_SPEC"
