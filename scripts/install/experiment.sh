#!/usr/bin/env bash
printf "%s\n" "$(tput bold)$(date) ${BASH_SOURCE[0]}$(tput sgr0)"

counter=0
subcounter=0
start_time=${SECONDS}

function new_step() {
    export counter=$((counter + 1))
    export subcounter=0
    export subsubcounter=0
    echo ""
    echo "Step ${counter}: ${1}"
}

function sub_step() {
    export subcounter=$((subcounter + 1))
    export subsubcounter=0
    echo ""
    echo "  Substep ${counter}.${subcounter}: ${1}"
}

function sub_substep() {
    export subsubcounter=$((subsubcounter + 1))
    echo ""
    echo "  Substep ${counter}.${subcounter}.${subsubcounter}: ${1}"
}

function display_total_elapsed_time() {
    local total_elapsed_time=$((SECONDS - start_time))
    local total_minutes=$((total_elapsed_time / 60))
    local total_seconds=$((total_elapsed_time % 60))
    echo ""
    printf "Total elapsed time: %02d:%02d (MM:SS)\n" "$total_minutes" "$total_seconds"
}

new_step "Housekeeping in advance of spack installs"

sub_step "Check that package list is passed in the argument"
if [[ $# -ne 1 ]]; then
    echo "Usage: $0 package-file"
    exit 1
fi

file="$1"
sub_step "package list passed: ${file}"

sub_step "Does file exist?"
if [[ ! -f "${file}" ]]; then
    echo "ERROR: file not found: ${file}"
    exit 1
fi

sub_step "file located"

repo="${pGithub}/spacklandia/builds/${HOSTNAME}"
sub_step "pointer to repo for build output = ${repo}"

sub_step "build directory structure"
    sub_substep "mkdir -p ${repo}/dependencies"
                 mkdir -p ${repo}/dependencies
    sub_substep "mkdir -p ${repo}/find"
                 mkdir -p ${repo}/find
    sub_substep "mkdir -p ${repo}/graph"
                 mkdir -p ${repo}/graph
    sub_substep "mkdir -p ${repo}/info"
                 mkdir -p ${repo}/info
    sub_substep "mkdir -p ${repo}/install"
                 mkdir -p ${repo}/install
    sub_substep "mkdir -p ${repo}/spec"
                 mkdir -p ${repo}/spec
    sub_substep "mkdir -p ${repo}/list-files"
                 mkdir -p ${repo}/list-files

sub_step "begin loop over packages"
while IFS= read -r package; do
    [[ -z "${package}" || "${package}" == \#* ]] && continue

new_step "install package ${package}"

  sub_step "spack dependencies  ${package}"
            spack dependencies "${package}" > "${repo}/dependencies/${package}.txt" 2>&1 &

  sub_step "spack find  ${package}"
            spack find "${package}" > "${repo}/find/${package}.txt" 2>&1 &

  sub_step "spack graph  ${package}"
            spack graph "${package}" > "${repo}/graph/${package}.txt" 2>&1 &

  sub_step "spack info  ${package}"
            spack info "${package}" > "${repo}/info/${package}.txt" 2>&1 &

  sub_step "spack spec  ${package}"
            spack spec "${package}" > "${repo}/spec/${package}.txt" 2>&1 &

  sub_step "spack install  ${package}"
            # spack install "${package}" > "${repo}/install/${package}.txt" 2>&1

  sub_step "wait for all probe commands to finish writing"
	    wait

  sub_step "git add -A"
            git add -A

  sub_step "git commit -m  '${package}' - '${HOSTNAME}'"
	    git commit -m  "${package}  -  ${HOSTNAME}"

done < "${file}"

# new_step "Wait for parallel processes to complete"
#          wait

new_step "Add results to git repo"
    sub_step "store list file"
	      cp "${file}" "${repo}/list-files/."
    sub_step "git add -A"
              git add -A
    sub_step "git commit -m 'builds from ${file} on ${HOSTNAME}'"
              git commit -m "builds from ${file} on ${HOSTNAME}"

printf "to push:\n cd $repo\n"

display_total_elapsed_time
