# Spack on WSL2: `pagmo` Build Failure Post-Mortem

Two distinct failures occurred during the installation of `pagmo` on WSL2 (`nuclide`):

## 1. Root Cause Analysis

### Failure A: `python@3.14.10` Post-Install `JSONDecodeError` (`boom.txt`)
During Python's post-install verification (`config_vars()`), Spack executes the newly compiled binary (`./python -c "import sysconfig; ... print(json.dumps(config))"`) and parses `stdout` as JSON.

However, **`pip_system_certs`** was injected into the build environment (likely via a leaked host `PYTHONPATH`, `PYTHONSTARTUP`, or system `.pth` file). Because Spack's `python@3.14.10` failed to compile its `_ssl` C extension against `openssl@3.6.5`, `pip_system_certs` emitted error diagnostics directly to `stdout` prior to `json.dumps(config)`:

```text
pip_system_certs: ERROR: could not register module: No module named '_ssl'
pip_system_certs: ERROR: truststore not available
```

These stray lines corrupted the JSON payload, causing Spack's parser to crash with:
```text
json.decoder.JSONDecodeError: Expecting value: line 1 column 1 (char 0)
```

### Failure B: WSL2 Terminal Termination / OOM Kill (`crash-03.txt`)
Running `spack install -j 4 pagmo python@3.12` staged and built `py-numpy`, `openmpi`, and `boost@1.90.0` concurrently. Heavy C++ template compilation (`boost`) combined with multiple parallel build jobs exhausted the default WSL2 RAM/swap allocation, triggering the Linux Out-Of-Memory (OOM) killer and abruptly terminating the WSL session (`[process exited with code 1 (0x00000001)]`).

---

## 2. Resolution & Recovery Steps

Run these steps sequentially in your WSL terminal on `nuclide` to isolate Spack from the host Python environment, prevent WSL OOM kills, and install `pagmo` cleanly:

### Step 1: Sanitize Environment Variables & Clean Failed Stages
Ensure no host Python environment variables (`PYTHONPATH`, `PYTHONSTARTUP`, `PYTHONHOME`) leak into Spack's build environment, and purge the broken `python@3.14.10` staging directory:

```bash
unset PYTHONPATH PYTHONSTARTUP PYTHONHOME
spack clean -a
```

* **Verification:** Running `env | grep -i python` returns no output.

### Step 2: Bypass Building Python from Scratch
The C++ `pagmo` library (unlike `py-pygmo`) only pulls in Python if a transitive dependency such as `boost +python` requests it. Register your system Ubuntu Python as an external package and disable `+python` on `boost`:

```bash
spack external find python
spack spec -I pagmo ^boost~python
```

* **Verification:** The concretized spec tree shows `boost~python` and either uses an external `[e]` Python or omits Python completely.

### Step 3: Install `pagmo` with Bounded Parallelism
Build `pagmo` using a single concurrent package and restricted compile threads so `boost` does not exhaust WSL2 memory:

```bash
spack install -j 1 --concurrent-packages 1 pagmo ^boost~python
```

*(Note: If you specifically need `py-pygmo` or Python bindings later, install `python@3.12` first with `unset PYTHONPATH` so `pip_system_certs` does not inject into `site-packages`, or link your `pybind11` bridge against the Spack-built C++ `pagmo` library.)*

* **Verification:** `spack find -lv pagmo` displays `pagmo` with a green `[+]` hash and no failed dependencies.

### Optional: Increase WSL2 Memory & Swap Limits
If WSL2 still terminates during `boost`, create or update `C:\Users\<YourWindowsUser>\.wslconfig` on Windows to allocate more memory and swap:

```ini
[wsl2]
memory=12GB
swap=8GB
```

Then restart WSL from PowerShell (`wsl --shutdown`) before resuming the Spack build.