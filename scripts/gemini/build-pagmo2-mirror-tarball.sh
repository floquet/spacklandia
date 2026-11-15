#!/usr/bin/env bash

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    set -euo pipefail
fi
printf "%s\n" "$(tput bold)$(date) ${BASH_SOURCE[0]}$(tput sgr0)"

# invocation: ./build-pagmo2-mirror-tarball.sh 2>&1 | tee build-pagmo2-mirror-tarball.log

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

# Configuration
SPACK_ROOT="${SPACK_ROOT:-$HOME/spacktivity/genesis}"
MIRROR_DIR="${MIRROR_DIR:-$HOME/pagmo2-mirror}"
TARBALL_PATH="${TARBALL_PATH:-$HOME/pagmo2-mirror.tar.gz}"
TARGET_SPEC="${TARGET_SPEC:-pagmo2}"

# Begin steps
new_step "Initialize Spack environment"
sub_step "source $SPACK_ROOT/share/spack/setup-env.sh"
if ! command -v spack >/dev/null 2>&1; then
    source "$SPACK_ROOT/share/spack/setup-env.sh"
fi
spack --version

new_step "Prepare clean local mirror directory"
sub_step "rm -rf $MIRROR_DIR && mkdir -p $MIRROR_DIR"
rm -rf "$MIRROR_DIR"
mkdir -p "$MIRROR_DIR"

new_step "Concretize and download source archives recursively (-D) for $TARGET_SPEC"
sub_step "spack spec -I $TARGET_SPEC"
spack spec -I "$TARGET_SPEC"

sub_step "spack mirror create -d $MIRROR_DIR -D $TARGET_SPEC"
spack mirror create -d "$MIRROR_DIR" -D "$TARGET_SPEC"

new_step "Audit fetched archives inside $MIRROR_DIR"
sub_step "find $MIRROR_DIR -type f | sort"
find "$MIRROR_DIR" -type f | sort

sub_step "du -sh $MIRROR_DIR"
du -sh "$MIRROR_DIR"

new_step "Create portable compressed tarball"
sub_step "tar -czf $TARBALL_PATH -C $(dirname $MIRROR_DIR) $(basename $MIRROR_DIR)"
tar -czf "$TARBALL_PATH" -C "$(dirname "$MIRROR_DIR")" "$(basename "$MIRROR_DIR")"

sub_step "ls -lh $TARBALL_PATH && sha256sum $TARBALL_PATH"
ls -lh "$TARBALL_PATH"
sha256sum "$TARBALL_PATH" > "${TARBALL_PATH}.sha256"
cat "${TARBALL_PATH}.sha256"

new_step "Print work WSL unpack and offline install commands"
echo "Upload $TARBALL_PATH (and ${TARBALL_PATH}.sha256) to GitLab, download on WSL, then run:"
echo "  sha256sum -c pagmo2-mirror.tar.gz.sha256"
echo "  tar -xzf pagmo2-mirror.tar.gz -C $HOME"
echo "  spack mirror add local_pagmo2 file://$HOME/pagmo2-mirror"
echo "  spack install $TARGET_SPEC"
