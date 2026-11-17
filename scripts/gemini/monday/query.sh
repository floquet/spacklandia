cat << 'EOF' > query.sh
#!/usr/bin/env bash
printf "%s\n" "$(tput bold)$(date) ${BASH_SOURCE[0]}$(tput sgr0)"

# invocation: ./query.sh 2>&1 | tee query.log

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

outdir="${pGithub:-$HOME/repos-isomer/github}/spacklandia/builds/${HOSTNAME}/query"
log="${outdir}/query-$(date +%Y%m%d-%H%M%S).log"

new_step "Prepare output directory and log file"
    sub_step "mkdir -p ${outdir}"
              mkdir -p "${outdir}"
    sub_step "Tee output to ${log}"
              exec > >(tee -a "${log}") 2>&1

new_step "OS, Kernel, WSL, and Network diagnostics"
    sub_step "uname -a"
              uname -a
    sub_step "grep -E '^(NAME|VERSION)=' /etc/os-release"
              grep -E '^(NAME|VERSION)=' /etc/os-release
    sub_step "ip addr"
              ip addr
    sub_step "cat /etc/resolv.conf"
              cat /etc/resolv.conf

new_step "TLS, OpenSSL, and Python SSL verification"
    sub_step "openssl version -a"
              openssl version -a
    sub_step "python3 --version"
              python3 --version
    sub_step "Python SSL default verify paths"
              python3 -c "import ssl; print('Python SSL:', ssl.OPENSSL_VERSION); print('Verify paths:', ssl.get_default_verify_paths())"
    sub_step "OpenSSL s_client handshake to ghcr.io:443"
              echo | openssl s_client -connect ghcr.io:443 -servername ghcr.io -verify_return_error 2>&1 | grep -E 'Verify return code|depth=|subject=|issuer='
    sub_step "Python urllib test against ghcr.io bootstrap manifest"
              python3 -c "import urllib.request; urllib.request.urlopen('https://ghcr.io/v2/spack/bootstrap-buildcache-v2.2/manifests/index.spack', timeout=10)" 2>&1

new_step "Spack installation and environment"
    sub_step "which spack"
              which spack
    sub_step "env | grep -E '^(SPACK|SSL|REQUESTS|CURL|OPENSSL|PATH|PYTHONPATH|HTTP)'"
              env | grep -E '^(SPACK|SSL|REQUESTS|CURL|OPENSSL|PATH|PYTHONPATH|HTTP)'
    sub_step "spack --version"
              spack --version
    sub_step "spack arch"
              spack arch
    sub_step "spack debug report"
              spack debug report 2>&1

new_step "Spack configs and bootstrap status"
    sub_step "spack config blame config"
              spack config blame config 2>&1
    sub_step "spack config blame bootstrap"
              spack config blame bootstrap 2>&1
    sub_step "spack bootstrap list"
              spack bootstrap list 2>&1
    sub_step "spack bootstrap status"
              spack bootstrap status 2>&1
    sub_step "ls -la ~/.spack ~/.spack/bootstrap /tmp/${USER}/spack-stage"
              ls -la ~/.spack ~/.spack/bootstrap "/tmp/${USER}/spack-stage" 2>&1

new_step "System clingo and registered compilers"
    sub_step "dpkg -l | grep -E 'clingo|ssl|ca-certificates|curl|python3'"
              dpkg -l | grep -E 'clingo|ssl|ca-certificates|curl|python3'
    sub_step "python3 -c 'import clingo'"
              python3 -c "import clingo; print('clingo module:', clingo.__file__, clingo.__version__)" 2>&1
    sub_step "spack compilers"
              spack compilers 2>&1

display_total_elapsed_time
EOF
chmod +x query.sh
