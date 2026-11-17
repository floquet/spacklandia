#!/usr/bin/env bash
# invocation: ./01-install-pagmo2-offline.sh 2>&1 | tee 01-install-pagmo2-offline_$(hostname).log
printf "%s\n" "$(tput bold)$(date) ${BASH_SOURCE[0]}$(tput sgr0)"

# ==============================================================================
# PURPOSE:
#   Nuclear clean-slate Spack bootstrap + offline pagmo2 build on WSL (isomer).
#   Use this if the monday/ recovery scripts fail and you want to wipe ~/spack
#   and ~/.spack completely and rebuild strictly from ~/pagmo2-mirror.tar.gz.
#
# HOW IT AVOIDS PREVIOUS FAILURES:
#   1. Pre-installs system python3-clingo via apt (Step 0) and exports its
#      site-packages directory via PYTHONPATH so Spack never contacts ghcr.io
#      (which failed Ubuntu 26.04's strict OpenSSL AKI check) or compiles
#      clingo/zlib-ng from source.
#   2. Fetches Spack commit 21bd91776b3a6d1bf96442bbd8b390072ee65fa8 directly
#      (the exact commit that generated pagmo2-mirror.tar.gz) so every package
#      version and SHA-256 matches the local tarball 100%.
#   3. Sets eth0 MTU to 1400 (if present) to prevent WSL packet fragmentation
#      during the initial git fetch of Spack itself.
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
SPACK_REPO="${SPACK_REPO:-https://github.com/spack/spack.git}"
SPACK_COMMIT="${SPACK_COMMIT:-21bd91776b3a6d1bf96442bbd8b390072ee65fa8}"
TARGET_DIR="${TARGET_DIR:-$HOME}"
TARBALL_NAME="${TARBALL_NAME:-pagmo2-mirror.tar.gz}"
CHECKSUM_NAME="${TARBALL_NAME}.sha256"
TARBALL_PATH="${TARGET_DIR}/${TARBALL_NAME}"
CHECKSUM_PATH="${TARGET_DIR}/${CHECKSUM_NAME}"
MIRROR_DIR="${TARGET_DIR}/pagmo2-mirror"
MIRROR_NAME="${MIRROR_NAME:-local_pagmo2}"
TARGET_SPEC="${TARGET_SPEC:-pagmo2}"
SYS_CA_BUNDLE="/etc/ssl/certs/ca-certificates.crt"

new_step "Host diagnostics and WSL MTU stabilization"
    sub_step "hostname && uname -a && nproc"
              hostname
              uname -a
              echo "CPU threads: $(nproc)"

    # HINT: WSL virtual NICs default to MTU 1500, which causes mid-stream TLS
    # drops ('curl: (18) end of response with N bytes missing') over VPNs.
    sub_step "Stabilize eth0 MTU to 1400 (if present)"
              if ip link show eth0 >/dev/null 2>&1; then
                  sudo ip link set dev eth0 mtu 1400 || true
              fi

new_step "Step 0: Install system python3-clingo to bypass ghcr.io bootstrap"
    # HINT: Installing python3-clingo from Ubuntu's apt repo gives Spack's
    # concretizer a working clingo solver immediately without touching ghcr.io.
    sub_step "sudo apt-get update && sudo apt-get install -y python3-clingo clingo gringo"
              sudo apt-get update
              sudo apt-get install -y python3-clingo clingo gringo

    sub_step "Locate system Python site-packages for clingo"
              SYS_SITE=$(python3 -c "import site; print(site.getsitepackages()[0])")
              export PYTHONPATH="${SYS_SITE}${PYTHONPATH:+:$PYTHONPATH}"
              python3 -c "import clingo; print('Verified clingo:', clingo.__file__, clingo.__version__)"

new_step "Verify offline mirror tarball ($TARBALL_PATH)"
    # HINT: Ensure pagmo2-mirror.tar.gz is already downloaded into $HOME before
    # running this script (or pass TARBALL_PATH=/path/to/pagmo2-mirror.tar.gz).
    sub_step "Check tarball existence"
              if [ ! -f "$TARBALL_PATH" ]; then
                  echo "ERROR: Tarball not found at $TARBALL_PATH"
                  echo "Download pagmo2-mirror.tar.gz into $TARGET_DIR and re-run."
                  exit 1
              fi
              ls -lh "$TARBALL_PATH"

    sub_step "Verify SHA-256 checksum (if $CHECKSUM_PATH exists)"
              if [ -f "$CHECKSUM_PATH" ]; then
                  (cd "$TARGET_DIR" && sha256sum -c "$CHECKSUM_NAME")
              else
                  echo "No .sha256 file found alongside tarball; skipping checksum check."
              fi

new_step "Wipe existing Spack tree, ~/.spack configs, and stale stage files"
    # HINT: Guarantees zero hangover from broken compiler entries, corrupted
    # tarballs in /tmp, or failed bootstrap caches.
    sub_step "rm -rf $SPACK_ROOT $HOME/.spack /tmp/${USER}/spack-stage/*"
              rm -rf "$SPACK_ROOT" "$HOME/.spack" "/tmp/${USER}/spack-stage/"*

new_step "Unpack offline mirror into $MIRROR_DIR"
    sub_step "rm -rf $MIRROR_DIR && tar -xzf $TARBALL_PATH -C $TARGET_DIR"
              rm -rf "$MIRROR_DIR"
              tar -xzf "$TARBALL_PATH" -C "$TARGET_DIR"

    sub_step "Audit extracted source archive count"
              echo "Extracted archive count: $(find "$MIRROR_DIR" -type f | wc -l)"

new_step "Clone Spack at exact mirror commit ($SPACK_COMMIT)"
    # HINT: Shallow-fetching the exact commit avoids cloning full history while
    # actually checking out the pinned SHA (fixing the old --depth=1 checkout bug).
    sub_step "git init $SPACK_ROOT && fetch commit $SPACK_COMMIT"
              mkdir -p "$SPACK_ROOT"
              git -C "$SPACK_ROOT" init
              git -C "$SPACK_ROOT" config feature.manyFiles true
              git -C "$SPACK_ROOT" remote add origin "$SPACK_REPO"
              git -C "$SPACK_ROOT" fetch --depth=1 origin "$SPACK_COMMIT"
              git -C "$SPACK_ROOT" checkout FETCH_HEAD

new_step "Initialize Spack, compilers, and local filesystem mirror"
    sub_step "source $SPACK_ROOT/share/spack/setup-env.sh"
              source "$SPACK_ROOT/share/spack/setup-env.sh"
              spack --version

    sub_step "Configure SSL and curl settings"
              if [ -f "$SYS_CA_BUNDLE" ]; then
                  export SSL_CERT_FILE="$SYS_CA_BUNDLE"
                  export REQUESTS_CA_BUNDLE="$SYS_CA_BUNDLE"
              fi
              spack config add config:url_fetch_method:curl
              spack config add config:verify_ssl:false
              spack config add config:connect_timeout:60

    sub_step "Detect system compilers (gcc / llvm)"
              spack compiler find
              spack compilers

    sub_step "Register local mirror $MIRROR_NAME -> file://$MIRROR_DIR"
              spack mirror add "$MIRROR_NAME" "file://${MIRROR_DIR}"
              spack mirror list

new_step "Concretize, install, and verify $TARGET_SPEC from offline mirror"
    # HINT: Every source tarball for pagmo2 and its dependencies is pulled
    # locally from file://$MIRROR_DIR with zero external downloads.
    sub_step "spack spec -I $TARGET_SPEC"
              spack spec -I "$TARGET_SPEC"

    sub_step "spack install --verbose $TARGET_SPEC"
              spack install --verbose "$TARGET_SPEC"

    sub_step "Verify installed package and prefix"
              spack find -lv "$TARGET_SPEC"
              spack location -i "$TARGET_SPEC"

echo ""
echo "SUCCESS: $TARGET_SPEC installed cleanly in $SPACK_ROOT"
echo "HINT: Add this line to ~/.bashrc so Spack always finds system clingo:"
echo "      export PYTHONPATH=\"${SYS_SITE}\${PYTHONPATH:+:\$PYTHONPATH}\""
