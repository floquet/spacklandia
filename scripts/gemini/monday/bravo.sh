#!/usr/bin/env bash
# invocation: ./bravo.sh 2>&1 | tee bravo.log
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

new_step "Stabilize WSL virtual network interface MTU"
    if ip link show eth0 >/dev/null 2>&1; then
        sub_step "sudo ip link set dev eth0 mtu 1400"
                  sudo ip link set dev eth0 mtu 1400
    else
        sub_step "eth0 not present; skipping MTU adjustment"
    fi

new_step "Clean partial stage files and configure Spack fetch resilience"
    sub_step "spack clean -s"
              spack clean -s
    sub_step "spack config add 'config:connect_timeout:60'"
              spack config add "config:connect_timeout:60"
    sub_step "spack config add 'config:verify_ssl:false'"
              spack config add "config:verify_ssl:false"

new_step "Run Spack bootstrap"
    sub_step "spack bootstrap now"
              spack bootstrap now

new_step "Smoke test: concretize zlib"
    sub_step "spack spec zlib"
              spack spec zlib

display_total_elapsed_time
