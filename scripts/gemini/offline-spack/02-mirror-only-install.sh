#!/usr/bin/env bash
# invocation: ./02-mirror-only-install.sh 2>&1 | tee 02-mirror-only-install_$(hostname).log
printf "%s\n" "$(tput bold)$(date) ${BASH_SOURCE[0]}$(tput sgr0)"

# ==============================================================================
# PURPOSE:
#   Non-destructive mirror registration and offline package installation.
#   Use this when Spack is ALREADY installed and working on isomer, and you
#   only want to unpack ~/pagmo2-mirror.tar.gz, register the local filesystem
#   mirror, and install TARGET_SPEC (defaults to pagmo2) without wiping ~/spack.
#
# USAGE EXAMPLES:
#   ./02-mirror-only-install.sh
#   TARGET_SPEC="zlib" ./02-mirror-only-install.sh
#   TARBALL_PATH=/tmp/pagmo2-mirror.tar.gz ./02-mirror-only-install.sh
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

# Configuration (override via environment variables if paths differ)
SPACK_ROOT="${SPACK_ROOT:-$HOME/spack}"
TARBALL_PATH="${TARBALL_PATH:-$HOME/pagmo2-mirror.tar.gz}"
MIRROR_PARENT="${MIRROR_PARENT:-$HOME}"
MIRROR_DIR="${MIRROR_PARENT}/pagmo2-mirror"
MIRROR_NAME="${MIRROR_NAME:-local_pagmo2}"
TARGET_SPEC="${TARGET_SPEC:-pagmo2}"

new_step "Verify tarball exists and check SHA-256 integrity"
    # HINT: Place pagmo2-mirror.tar.gz (and optional .sha256) in $HOME first,
    # or pass TARBALL_PATH=/full/path/to/pagmo2-mirror.tar.gz.
    sub_step "ls -lh $TARBALL_PATH"
              if [ ! -f "$TARBALL_PATH" ]; then
                  echo "ERROR: Tarball not found at $TARBALL_PATH"
                  echo "Set TARBALL_PATH=/path/to/pagmo2-mirror.tar.gz and re-run."
                  exit 1
              fi
              ls -lh "$TARBALL_PATH"

    sub_step "Verify ${TARBALL_PATH}.sha256 if present"
              if [ -f "${TARBALL_PATH}.sha256" ]; then
                  (cd "$(dirname "$TARBALL_PATH")" && sha256sum -c "$(basename "${TARBALL_PATH}.sha256")")
              else
                  echo "No .sha256 checksum file found alongside tarball; skipping checksum check."
              fi

new_step "Unpack offline mirror archive into $MIRROR_PARENT"
    sub_step "rm -rf $MIRROR_DIR && tar -xzf $TARBALL_PATH -C $MIRROR_PARENT"
              rm -rf "$MIRROR_DIR"
              tar -xzf "$TARBALL_PATH" -C "$MIRROR_PARENT"

    sub_step "Audit extracted source archive count"
              echo "Extracted archive count: $(find "$MIRROR_DIR" -type f | wc -l)"

new_step "Initialize existing Spack environment and wire system clingo"
    # HINT: Ensures Spack sees Ubuntu's apt-installed python3-clingo if present,
    # avoiding any unexpected bootstrap attempts during concretization.
    sub_step "source $SPACK_ROOT/share/spack/setup-env.sh"
              if ! command -v spack >/dev/null 2>&1; then
                  if [ ! -f "$SPACK_ROOT/share/spack/setup-env.sh" ]; then
                      echo "ERROR: Spack not found at $SPACK_ROOT. Run ./01-install-pagmo2-offline.sh instead."
                      exit 1
                  fi
                  source "$SPACK_ROOT/share/spack/setup-env.sh"
              fi
              spack --version

    sub_step "Export system site-packages to PYTHONPATH if system clingo is installed"
              SYS_SITE=$(python3 -c "import site; print(site.getsitepackages()[0])" 2>/dev/null || true)
              if [ -n "$SYS_SITE" ] && [ -d "$SYS_SITE" ]; then
                  export PYTHONPATH="${SYS_SITE}${PYTHONPATH:+:$PYTHONPATH}"
                  echo "PYTHONPATH=${PYTHONPATH}"
              fi

new_step "Register local filesystem mirror in Spack"
    # HINT: Removes any stale mirror with the same name so re-runs are idempotent.
    sub_step "spack mirror remove $MIRROR_NAME (if already exists)"
              spack mirror remove "$MIRROR_NAME" 2>/dev/null || true

    sub_step "spack mirror add $MIRROR_NAME file://$MIRROR_DIR"
              spack mirror add "$MIRROR_NAME" "file://${MIRROR_DIR}"

    sub_step "spack mirror list"
              spack mirror list

new_step "Concretize, compile, and install $TARGET_SPEC from local mirror"
    # HINT: Clean any partial staging directory for $TARGET_SPEC before building.
    sub_step "spack clean -s"
              spack clean -s

    sub_step "spack spec -I $TARGET_SPEC"
              spack spec -I "$TARGET_SPEC"

    sub_step "spack install --verbose $TARGET_SPEC"
              spack install --verbose "$TARGET_SPEC"

new_step "Verify installation and print install prefix"
    sub_step "spack find -lv $TARGET_SPEC"
              spack find -lv "$TARGET_SPEC"

    sub_step "spack location -i $TARGET_SPEC"
              spack location -i "$TARGET_SPEC"
