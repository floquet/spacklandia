rm -f charlie.sh charlie.log
cat << 'EOF' > start-clingo.sh
#!/usr/bin/env bash
# invocation: ./start-clingo.sh 2>&1 | tee start-clingo.log
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

new_step "Install system clingo packages via apt (Step 0)"
    sub_step "sudo apt-get update"
              sudo apt-get update
    sub_step "sudo apt-get install -y python3-clingo clingo gringo"
              sudo apt-get install -y python3-clingo clingo gringo

new_step "Verify Python clingo module and locate site-packages"
    sub_step "python3 -c 'import clingo'"
              python3 -c "import clingo; print('Verified system clingo:', clingo.__file__, clingo.__version__)"
    sub_step "Capture system site-packages directory"
              sys_site=$(python3 -c "import site; print(site.getsitepackages()[0])")
              echo "sys_site = ${sys_site}"

new_step "Register external clingo and clean partial bootstrap stage"
    sub_step "spack external find clingo"
              spack external find clingo
    sub_step "spack clean -s"
              spack clean -s

new_step "Smoke test: concretize zlib with system clingo"
    sub_step "PYTHONPATH=${sys_site} spack spec zlib"
              PYTHONPATH="${sys_site}${PYTHONPATH:+:$PYTHONPATH}" spack spec zlib

display_total_elapsed_time
EOF
chmod +x start-clingo.sh
