#!/usr/bin/env bash
# invocation: ./alpha.sh 2>&1 | tee alpha.log
printf "%s\n" "$(tput bold)$(date) ${BASH_SOURCE[0]}$(tput sgr0)"

counter=0
subcounter=0
start_time=${SECONDS}

function new_step() {
    export counter=$((counter + 1))
    export subcounter=0
    echo ""
    echo "Step ${counter}: ${1}"
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

new_step "Clean truncated stage files"
    sub_step "spack clean -s"
              spack clean -s
    sub_step "rm -rf /tmp/${USER}/spack-stage/*"
              rm -rf "/tmp/${USER}/spack-stage/"*

new_step "Write temporary OpenSSL config to bypass Ubuntu 26.04 AKI check"
    sub_step "Create /tmp/openssl-spack-alpha.cnf"
cat << 'OCNF' > /tmp/openssl-spack-alpha.cnf
openssl_conf = openssl_init

[openssl_init]
ssl_conf = ssl_sect

[ssl_sect]
system_default = system_default_sect

[system_default_sect]
Options = UnsafeLegacyRenegotiation
VerifyMode = None
OCNF
    sub_step "Register cleanup trap for /tmp/openssl-spack-alpha.cnf"
              trap 'rm -f /tmp/openssl-spack-alpha.cnf' EXIT

new_step "Bootstrap clingo binary buildcache from ghcr.io"
    sub_step "spack -k bootstrap now (with relaxed OpenSSL verification)"
              OPENSSL_CONF=/tmp/openssl-spack-alpha.cnf \
              SSL_CERT_FILE=/etc/ssl/certs/ca-certificates.crt \
              REQUESTS_CA_BUNDLE=/etc/ssl/certs/ca-certificates.crt \
              spack -k bootstrap now

new_step "Smoke test: concretize zlib"
    sub_step "spack spec zlib"
              spack spec zlib

display_total_elapsed_time
