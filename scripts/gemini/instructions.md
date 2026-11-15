Tomorrow's Execution Order on WSL

    Run ./wsl-spack-bootstrap.sh 2>&1 | tee wsl-spack-bootstrap.log (if zlib succeeds, your network fix worked and you don't even need the tarball).

    If zlib is still blocked by corporate security, download pagmo2-mirror.tar.gz from GitLab into $HOME/ (or pass TARBALL_PATH=/path/to/pagmo2-mirror.tar.gz) and run ./wsl-install-pagmo2-mirror.sh 2>&1 | tee wsl-install-pagmo2-mirror.log.
