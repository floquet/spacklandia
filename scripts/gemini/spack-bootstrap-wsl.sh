#!/usr/bin/env bash
printf "%s\n" "$(tput bold)$(date) ${BASH_SOURCE[0]}$(tput sgr0)"

# invocation: ./spack-bootstrap-wsl.sh 2>&1 | tee spack-bootstrap.log

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    set -euo pipefail
fi
printf "%s\n" "$(tput bold)$(date) ${BASH_SOURCE[0]}$(tput sgr0)"

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

# Configuration: adjust SPACK_ROOT if you prefer a different directory
SPACK_ROOT="${SPACK_ROOT:-$HOME/spack}"
SPACK_REPO="https://github.com/spack/spack.git"
SYS_CA_BUNDLE="/etc/ssl/certs/ca-certificates.crt"

# Begin steps
new_step "Capture baseline WSL network and SSL diagnostics"
sub_step "uname -a && lsb_release -ds 2>/dev/null || cat /etc/os-release"
uname -a
lsb_release -ds 2>/dev/null || grep PRETTY_NAME /etc/os-release

sub_step "env | grep -iE 'proxy|ssl|cert|curl' || echo 'No proxy/SSL env vars set'"
env | grep -iE 'proxy|ssl|cert|curl' || echo "No proxy/SSL env vars set"

sub_step "curl -I -sS --max-time 10 https://github.com | head -n 5"
curl -I -sS --max-time 10 https://github.com | head -n 5

new_step "Obliterate existing Spack installation and user cache"
sub_step "rm -rf $SPACK_ROOT"
rm -rf "$SPACK_ROOT"

sub_step "rm -rf $HOME/.spack"
rm -rf "$HOME/.spack"

new_step "Clone fresh Spack repository"
sub_step "git clone --depth=1 $SPACK_REPO $SPACK_ROOT"
git clone --depth=1 "$SPACK_REPO" "$SPACK_ROOT"

new_step "Initialize Spack shell environment"
sub_step "source $SPACK_ROOT/share/spack/setup-env.sh"
source "$SPACK_ROOT/share/spack/setup-env.sh"

sub_step "spack --version"
spack --version

new_step "Configure Spack to bypass corporate SSL/urllib issues"
sub_step "export SSL_CERT_FILE=$SYS_CA_BUNDLE and REQUESTS_CA_BUNDLE=$SYS_CA_BUNDLE"
if [ -f "$SYS_CA_BUNDLE" ]; then
    export SSL_CERT_FILE="$SYS_CA_BUNDLE"
    export REQUESTS_CA_BUNDLE="$SYS_CA_BUNDLE"
    echo "Exported system CA bundle: $SYS_CA_BUNDLE"
else
    echo "Warning: $SYS_CA_BUNDLE not found"
fi

sub_step "spack config add config:url_fetch_method:curl"
spack config add config:url_fetch_method:curl

sub_step "spack config add config:verify_ssl:false"
spack config add config:verify_ssl:false

sub_step "spack config add config:connect_timeout:30"
spack config add config:connect_timeout:30

sub_step "spack config get config"
spack config get config

new_step "Detect apt-installed compilers"
sub_step "spack compiler find"
spack compiler find

sub_step "spack compilers"
spack compilers

new_step "Smoke test: fetch, build, and install zlib"
sub_step "spack spec zlib"
spack spec zlib

sub_step "spack install --verbose zlib"
spack install --verbose zlib

sub_step "spack find zlib"
spack find zlib
