#!/usr/bin/env bash
# invocation: ./spack-genesis.sh
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

new_step "move to spacklandia: cd ${Github}/spacklandia/scripts/gemini/monday"
                               cd ${Github}/spacklandia/scripts/gemini/monday && pwd

new_step "activate spack: source ~/spack/share/spack/setup-env.sh"
                          source ~/spack/share/spack/setup-env.sh

new_step "install julia: spack install -j 4 julia 2>&1 | tee install-julia.log"
          install julia: spack install -j 4 julia 2>&1 | tee install-julia.log

display_total_elapsed_time


