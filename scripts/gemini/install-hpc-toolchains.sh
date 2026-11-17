#!/usr/bin/env bash
# invocation: ./install-hpc-toolchains.sh 2>&1 | tee install-hpc-toolchains_$(hostname).log
printf "%s\n" "$(tput bold)$(date) ${BASH_SOURCE[0]}$(tput sgr0)"

# ==============================================================================
# PURPOSE:
#   Install modern HPC compilers, coarray/MPI runtimes, LLVM/Flang, and
#   array/numerical environments (Julia, Octave) via Ubuntu 26.04 apt packages.
#
# PACKAGE NOTES FOR UBUNTU 26.04 (RESOLUTE):
#   - GCC 16: Installs gcc-16 / g++-16 / gfortran-16 if available in apt, or
#     falls back cleanly to gcc-15 / gfortran-15 (system default 15.2.0).
#   - Coarray Fortran: Installs libcaf-mpich-3 / libcaf-openmpi-3 and
#     open-coarrays-bin (provides `caf` and `cafrun` wrappers for gfortran).
#   - MPICH: Installs mpich, libmpich-dev, and mpi-default-bin/dev.
#   - LLVM & Flang: Installs unversioned defaults (clang, lld, flang) plus
#     versioned LLVM 21 packages (clang-21, flang-21, libflang-21-dev,
#     libomp-21-dev) when present in the repository.
#   - Julia & Octave: Installs julia and octave (plus liboctave-dev).
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

# Helper: install only packages that exist in apt cache so one unavailable
# versioned package (e.g., gcc-16 vs gcc-15) does not abort the entire batch.
function apt_install_available() {
    local to_install=()
    for pkg in "$@"; do
        if apt-cache show "$pkg" >/dev/null 2>&1; then
            to_install+=("$pkg")
        else
            echo "  [skip] Package not found in apt cache: $pkg"
        fi
    done
    if [ ${#to_install[@]} -gt 0 ]; then
        echo "  [install] ${to_install[*]}"
        sudo DEBIAN_FRONTEND=noninteractive apt-get install -y "${to_install[@]}"
    fi
}

new_step "Update apt package index and baseline build utilities"
    sub_step "sudo apt-get update"
              sudo apt-get update
    sub_step "Install build-essential, cmake, ninja-build, pkg-config, git, curl"
              apt_install_available build-essential cmake ninja-build pkg-config git curl

new_step "Install GCC 16 (with GCC 15 fallback) and GFortran"
    sub_step "Check and install gcc-16 / g++-16 / gfortran-16 (and gcc-15 fallback)"
              apt_install_available \
                  gcc-16 g++-16 gfortran-16 \
                  gcc-15 g++-15 gfortran-15 \
                  gcc g++ gfortran

new_step "Install MPICH and Coarray Fortran (OpenCoarrays)"
    sub_step "Install MPICH runtime and development headers"
              apt_install_available mpich libmpich-dev
    sub_step "Install OpenCoarrays (caf / cafrun wrappers and MPICH coarray library)"
              apt_install_available open-coarrays-bin libcaf-mpich-3

new_step "Install LLVM, Clang, OpenMP, and Flang"
    sub_step "Install unversioned and LLVM 21 toolchains"
              apt_install_available \
                  llvm clang lld flang \
                  llvm-21 clang-21 lld-21 flang-21 \
                  libflang-21-dev libomp-21-dev libomp-dev

new_step "Install Julia and GNU Octave"
    sub_step "Install julia, octave, and liboctave-dev"
              apt_install_available julia octave liboctave-dev

new_step "Verify installed compilers, MPI, Coarrays, Julia, and Octave"
    sub_step "Check GCC / GFortran versions"
              gcc --version | head -n 1
              gfortran --version | head -n 1
              command -v gcc-16 >/dev/null 2>&1 && gcc-16 --version | head -n 1 || true
              command -v gfortran-16 >/dev/null 2>&1 && gfortran-16 --version | head -n 1 || true

    sub_step "Check LLVM / Clang / Flang versions"
              clang --version | head -n 1
              command -v flang-21 >/dev/null 2>&1 && flang-21 --version | head -n 1 || true
              command -v flang >/dev/null 2>&1 && flang --version | head -n 1 || true

    sub_step "Check MPICH and Coarray Fortran (caf / cafrun)"
              mpicc --version | head -n 1
              mpifort --version | head -n 1
              command -v caf >/dev/null 2>&1 && caf --version | head -n 2 || true
              command -v cafrun >/dev/null 2>&1 && cafrun --version | head -n 1 || true

    sub_step "Check Julia and Octave"
              command -v julia >/dev/null 2>&1 && julia --version || true
              command -v octave >/dev/null 2>&1 && octave --version | head -n 1 || true
