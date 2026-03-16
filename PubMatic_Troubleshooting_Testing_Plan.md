# PubMatic Troubleshooting Script -- Testing Plan

This document covers comprehensive testing for `PubMatic_Troubleshooting.sh` across all 7 sections, including environment matrices, per-section test cases, cross-cutting integration tests, Docker commands, and failure simulation recipes.

---

## Test Environment Matrix

| ID | OS | Arch | Python Pre-installed | Package Manager | Purpose |
|----|-----|------|---------------------|-----------------|---------|
| E1 | macOS Sonoma/Sequoia | arm64 | 3.12.x | N/A (uses .pkg) | Happy path on Apple Silicon |
| E2 | macOS Ventura+ | x86_64 | None or 3.14+ | N/A (uses .pkg) | Python install flow on Intel Mac |
| E3 | Ubuntu 22.04 | x86_64 | 3.10.x | apt-get | Linux happy path (Debian-family) |
| E4 | Ubuntu 24.04 | x86_64 | None | apt-get | Python install + PEP 668 (EXTERNALLY-MANAGED) |
| E5 | Rocky Linux 9 / RHEL 9 | x86_64 | 3.9.x | dnf | RHEL-family package manager |
| E6 | Alpine 3.19 (Docker) | x86_64 | None | apk | Minimal environment, no DNS tools |
| E7 | Any of the above | Any | Any | Any | No internet (airplane mode / firewall) |

---

## Section 1: Self-Upgrade (`check_upgrade`)

| Test ID | Scenario | How to Simulate | Expected Result | Pass Criteria |
|---------|----------|-----------------|-----------------|---------------|
| 1.1 | Script is already the latest version | Set `SCRIPT_VERSION` to match the actual latest GitHub release tag | Prints "Script is up to date (vX.Y.Z)" | `CHECK_UPGRADE="pass"` |
| 1.2 | Newer version exists on GitHub | Set `SCRIPT_VERSION="0.0.1"` in the script | Shows current vs. latest version, prompts to update | Prompt text includes both versions |
| 1.3 | GitHub API is unreachable | Block `api.github.com` via `/etc/hosts` (add `127.0.0.1 api.github.com`) or disconnect network before this step | Prints "(Skipped -- could not reach GitHub)" | `CHECK_UPGRADE="skip"`, script continues to section 2 |
| 1.4 | GitHub response has no `tag_name` | Point `RELEASES_URL` at a repo with zero releases (e.g., an empty test repo) | Prints "(Skipped -- could not parse version)" | `CHECK_UPGRADE="skip"`, script continues |
| 1.5 | User declines the update prompt | Run interactively (no `--yes`), type `n` or press Enter at the prompt | Prints "Skipped update. Continuing with vX.Y.Z" | `CHECK_UPGRADE="pass"`, no files modified |
| 1.6 | `--yes` flag auto-accepts update | Run `bash PubMatic_Troubleshooting.sh --yes` with `SCRIPT_VERSION="0.0.1"` | Prints "(Auto-accepted via --yes flag)", attempts download | No interactive prompt shown |

**Simulation recipe for 1.3:**
```bash
# Block GitHub API (requires sudo, remember to revert)
echo "127.0.0.1 api.github.com" | sudo tee -a /etc/hosts
bash PubMatic_Troubleshooting.sh
# Revert:
sudo sed -i '' '/api.github.com/d' /etc/hosts  # macOS
sudo sed -i '/api.github.com/d' /etc/hosts      # Linux
```

---

## Section 2: Network Check (`check_network`)

| Test ID | Scenario | How to Simulate | Expected Result | Pass Criteria |
|---------|----------|-----------------|-----------------|---------------|
| 2.1 | Normal internet connectivity | Run on a connected machine | "Internet connectivity confirmed" | `CHECK_NETWORK="pass"` |
| 2.2 | google.com blocked, 1.1.1.1 reachable | Add `127.0.0.1 www.google.com` to `/etc/hosts` | Still passes via 1.1.1.1 fallback | `CHECK_NETWORK="pass"`, log shows "via 1.1.1.1 fallback" |
| 2.3 | No internet at all | Disconnect WiFi / disable network interface | "No internet connectivity detected", script exits | `CHECK_NETWORK="fail"`, exit code 1 |
| 2.4 | Proxy blocks HTTPS | Set `https_proxy=http://127.0.0.1:9999` (non-existent proxy) | Script exits with network error | `CHECK_NETWORK="fail"`, exit code 1 |
| 2.5 | Very slow connection (near 5s timeout) | Use `tc` (Linux) to add 4s latency | Should still pass (within max-time 5s) | `CHECK_NETWORK="pass"` |

**Simulation recipe for 2.3 (macOS):**
```bash
# Disable Wi-Fi
networksetup -setairportpower en0 off
bash PubMatic_Troubleshooting.sh
# Re-enable:
networksetup -setairportpower en0 on
```

**Simulation recipe for 2.4:**
```bash
https_proxy=http://127.0.0.1:9999 bash PubMatic_Troubleshooting.sh
```

---

## Section 3: DNS Check (`check_dns`)

| Test ID | Scenario | How to Simulate | Expected Result | Pass Criteria |
|---------|----------|-----------------|-----------------|---------------|
| 3.1 | `host` command is available (default macOS/Ubuntu) | Run on standard macOS or Ubuntu | Shows resolved IP via `host` command | `CHECK_DNS="pass"`, output contains "has address" |
| 3.2 | Only `nslookup` available | Temporarily rename `host`: `sudo mv $(which host) $(which host).bak` | Falls back to `nslookup`, shows IP | `CHECK_DNS="pass"`, log shows Address |
| 3.3 | Only `dig` available | Rename both `host` and `nslookup` | Falls back to `dig +short` | `CHECK_DNS="pass"` |
| 3.4 | No DNS tools at all (curl fallback) | Use Alpine Docker (no bind-utils installed) | Prints "(resolved via curl -- no DNS tool available to show IP)" | `CHECK_DNS="pass"` |
| 3.5 | DNS resolution fails completely | Add `127.0.0.1 mcp.pubmatic.com` to `/etc/hosts` and block all outbound DNS, or use a non-existent domain by temporarily changing `MCP_HOST` | "DNS resolution failed" | `CHECK_DNS="fail"`, exit code 1 |
| 3.6 | Split-tunnel VPN blocks mcp.pubmatic.com | Connect to a VPN that does not route this domain | "DNS resolution failed", suggests checking VPN/DNS settings | `CHECK_DNS="fail"`, error message mentions VPN |

**Simulation recipe for 3.2 (macOS):**
```bash
sudo mv /usr/bin/host /usr/bin/host.bak
bash PubMatic_Troubleshooting.sh
# Revert:
sudo mv /usr/bin/host.bak /usr/bin/host
```

**Simulation recipe for 3.4 (Docker -- Alpine has no DNS tools):**
```bash
docker run --rm -v "$(pwd)":/app alpine:3.19 sh -c "apk add bash curl && bash /app/PubMatic_Troubleshooting.sh --yes"
```

---

## Section 4: Platform Detection (`detect_platform`)

| Test ID | Scenario | How to Simulate | Expected Result | Pass Criteria |
|---------|----------|-----------------|-----------------|---------------|
| 4.1 | macOS arm64 | Run on M1/M2/M3/M4 Mac | "Detected: macOS arm64" | `CHECK_PLATFORM="pass"`, `DETECTED_OS="Darwin"`, `DETECTED_ARCH="arm64"` |
| 4.2 | macOS x86_64 | Run on Intel Mac (or under Rosetta) | "Detected: macOS x86_64" | `CHECK_PLATFORM="pass"`, `DETECTED_ARCH="x86_64"` |
| 4.3 | Ubuntu x86_64 | Run on Ubuntu VM or Docker | "Detected: Linux x86_64 (ubuntu)" | `CHECK_PLATFORM="pass"`, `DETECTED_DISTRO="ubuntu"` |
| 4.4 | RHEL / Rocky 9 | Run on Rocky Linux 9 Docker | "Detected: Linux x86_64 (rocky)" | `CHECK_PLATFORM="pass"`, `DETECTED_DISTRO="rocky"` |
| 4.5 | Alpine (Docker) | `docker run --rm alpine:3.19 ...` | "Detected: Linux x86_64 (alpine)" | `CHECK_PLATFORM="pass"`, `DETECTED_DISTRO="alpine"` |
| 4.6 | Unsupported OS | Cannot easily simulate on real hardware; verify the `case` branch by inspection | "Unsupported operating system" | `CHECK_PLATFORM="fail"`, exit code 1 |
| 4.7 | Linux without `/etc/os-release` | Docker image where `/etc/os-release` is deleted: `docker run --rm ubuntu sh -c "rm /etc/os-release && bash ..."` | Platform detected but distro = "unknown" | `CHECK_PLATFORM="pass"`, `DETECTED_DISTRO="unknown"` |

**Simulation recipe for 4.3 (Docker):**
```bash
docker run --rm -v "$(pwd)":/app ubuntu:22.04 bash -c "apt-get update && apt-get install -y curl && bash /app/PubMatic_Troubleshooting.sh --yes"
```

**Simulation recipe for 4.4 (Docker):**
```bash
docker run --rm -v "$(pwd)":/app rockylinux:9 bash -c "yum install -y curl && bash /app/PubMatic_Troubleshooting.sh --yes"
```

---

## Section 5: Python Check and Install (`check_python`)

| Test ID | Scenario | How to Simulate | Expected Result | Pass Criteria |
|---------|----------|-----------------|-----------------|---------------|
| 5.1 | Python 3.12.x already installed | Standard macOS with Python 3.12 from python.org | "Python 3.12.x is installed (/path/to/python3)" | `CHECK_PYTHON="pass"` |
| 5.2 | Python 3.8.x (minimum boundary) | System with Python 3.8 installed and on PATH | "Python 3.8.x is installed" | `CHECK_PYTHON="pass"` (3.8 is >= MIN_VERSION) |
| 5.3 | Python 3.13.x (near max boundary) | System with Python 3.13 | "Python 3.13.x is installed" | `CHECK_PYTHON="pass"` (3.13.x <= 3.13.99) |
| 5.4 | Python 3.14+ (above max range) | Homebrew `python@3.14` as default `python3` | Shows install plan with 4 steps (macOS) | Prompts user, `CHECK_PYTHON` depends on user action |
| 5.5 | Python 3.7 (below min range) | System with only Python 3.7 | Shows install plan | Prompts user |
| 5.6 | No `python3`, but `python` is Python 3.x | Rename `python3`, ensure `python` -> 3.x | Falls back to `python` command | `PYTHON_CMD="python"`, version check proceeds |
| 5.7 | No Python at all | Docker image without Python pre-installed | Shows install plan with package manager steps | Step list matches detected OS/package manager |
| 5.8 | User declines install (interactive) | Run without `--yes`, press Enter or `n` | "Installation skipped. Please install Python 3.8+ manually" | `CHECK_PYTHON="fail"`, exit code 1 |
| 5.9 | `--yes` auto-accepts install | Run with `--yes` on a system needing install | "(Auto-accepted via --yes flag)", executes steps | No prompt displayed |
| 5.10 | macOS install step display | macOS, Python missing or out of range | Shows: curl download, sudo installer, ln -sf, rm cleanup | 4 steps listed with correct URLs and paths |
| 5.11 | Ubuntu install step display | Ubuntu Docker, no Python | Shows: apt-get update, software-properties-common, deadsnakes PPA, apt-get update, python3.12, ln -sf | 6 steps listed |
| 5.12 | Fedora/RHEL install step display | Rocky/Fedora Docker, no Python | Shows: "sudo dnf install -y python3.12" | 1 step listed via dnf |
| 5.13 | No supported package manager | Minimal Docker with package manager removed | "No supported package manager found" | `CHECK_PYTHON="fail"`, prints manual install URL |
| 5.14 | Post-install verification succeeds | After a successful install run | Re-checks `python3 --version`, reports installed version | `CHECK_PYTHON="pass"`, version in range |
| 5.15 | Homebrew python3 shadows installed 3.12 | macOS with Homebrew Python 3.14+ in `/opt/homebrew/bin`, install 3.12 to `/usr/local/bin` | Post-install finds 3.12.9 via direct path, not Homebrew's 3.14 | `CHECK_PYTHON="pass"`, `PYTHON_CMD` points to 3.12 binary |

**Simulation recipe for 5.4 (Python out of range, macOS):**
```bash
# If Homebrew python3 is 3.14+, the script will detect it automatically.
# To force the scenario, temporarily alias:
python3 --version  # confirm it's 3.14+
bash PubMatic_Troubleshooting.sh
```

**Simulation recipe for 5.7 (Docker -- no Python):**
```bash
docker run --rm -v "$(pwd)":/app ubuntu:22.04 bash -c "apt-get update && apt-get install -y curl && bash /app/PubMatic_Troubleshooting.sh --yes"
```

**Simulation recipe for 5.13 (Docker -- no package manager):**
```bash
docker run --rm -v "$(pwd)":/app ubuntu:22.04 bash -c "
    apt-get update && apt-get install -y curl
    # Remove apt-get to simulate missing package manager
    mv /usr/bin/apt-get /usr/bin/apt-get.bak
    mv /usr/bin/dpkg /usr/bin/dpkg.bak
    bash /app/PubMatic_Troubleshooting.sh --yes
"
```

---

## Section 6: SSL/Certificate Check (`check_ssl`)

| Test ID | Scenario | How to Simulate | Expected Result | Pass Criteria |
|---------|----------|-----------------|-----------------|---------------|
| 6.1 | SSL handshake succeeds (happy path) | Standard setup with valid certificates | "SSL handshake to mcp.pubmatic.com succeeded" | `CHECK_SSL="pass"`, no fix plan shown |
| 6.2 | SSL fails, user accepts fix | Remove certifi or corrupt cert store, then accept prompt | Shows fix plan, executes steps, re-verifies | `CHECK_SSL="pass"` after re-verify |
| 6.3 | SSL fails, user declines fix | Run without `--yes`, press Enter or `n` at SSL prompt | "SSL certificate fix skipped" | `CHECK_SSL="warn"`, script continues |
| 6.4 | macOS fix steps displayed | macOS with SSL failure | Shows: ensurepip (if pip missing), certifi install with `--break-system-packages`, Apple cert installer (if file exists) | Steps match macOS-specific paths |
| 6.5 | Ubuntu fix steps displayed | Ubuntu with SSL failure | Shows: ca-certificates install, update-ca-certificates, ensurepip (if needed), certifi install | Steps match apt-get commands |
| 6.6 | pip is missing, ensurepip bootstraps it | Uninstall pip: `python3 -m pip uninstall pip -y` then break pip | Shows "Bootstrap pip (not currently installed)" step | ensurepip step appears in fix plan |
| 6.7 | PEP 668 detection (EXTERNALLY-MANAGED) | Ubuntu 24.04 or Debian 12+ where EXTERNALLY-MANAGED file exists | `--break-system-packages` flag included in certifi install command | Flag visible in step display |
| 6.8 | Fix applied but SSL still fails | Corrupt cert store beyond what certifi can fix (e.g., corporate MITM proxy) | "SSL fix was applied but handshake still fails" | `CHECK_SSL="warn"`, script continues |
| 6.9 | `--yes` flag auto-accepts SSL fix | Run with `--yes` on system with SSL failure | "(Auto-accepted via --yes flag)", executes fix steps | No prompt displayed |

**Simulation recipe for 6.2 (force SSL failure on macOS):**
```bash
# Temporarily make Python unable to find certificates
python3 -c "import ssl; ssl.create_default_context()" 2>&1  # confirm it works first
# Corrupt by pointing SSL_CERT_FILE to a non-existent file:
SSL_CERT_FILE=/tmp/nonexistent.pem bash PubMatic_Troubleshooting.sh
```

**Simulation recipe for 6.6 (pip missing):**
```bash
docker run --rm -v "$(pwd)":/app ubuntu:22.04 bash -c "
    apt-get update && apt-get install -y curl python3
    # Remove pip
    python3 -m pip uninstall pip -y 2>/dev/null
    rm -rf /usr/lib/python3/dist-packages/pip* 2>/dev/null
    bash /app/PubMatic_Troubleshooting.sh --yes
"
```

---

## Section 7: MCP Server Health Check (`check_health`)

| Test ID | Scenario | How to Simulate | Expected Result | Pass Criteria |
|---------|----------|-----------------|-----------------|---------------|
| 7.1 | Health endpoint returns 200, fast | Normal connectivity to apps.pubmatic.com | "MCP Server is healthy (HTTP 200, Xs)" | `CHECK_HEALTH="pass"` |
| 7.2 | Health endpoint returns 200, slow (>5s) | Add network latency with `tc` (Linux) or use a slow proxy | "MCP Server is reachable but slow" | `CHECK_HEALTH="warn"` |
| 7.3 | Health endpoint returns 500 | Point `HEALTH_CHECK_URL` at a mock server returning 500 | "PubMatic MCP Server returned HTTP 500" | `CHECK_HEALTH="fail"`, exit code 1 |
| 7.4 | Health endpoint unreachable (DNS blocked) | Add `127.0.0.1 apps.pubmatic.com` to `/etc/hosts` | "Could not reach PubMatic MCP Server" | `CHECK_HEALTH="fail"`, exit code 1 |
| 7.5 | Health endpoint times out (firewall DROP) | Use iptables DROP rule (Linux) on the destination | HTTP code "000", "Could not reach" | `CHECK_HEALTH="fail"`, exit code 1 |
| 7.6 | Response body contains valid JSON `{"status":"ok"}` | Normal response from the real endpoint | Log shows "Parsed server status: ok" (or actual value) | Status parsed and logged |
| 7.7 | Response body is not JSON (e.g., HTML error page) | Point `HEALTH_CHECK_URL` at a URL returning HTML | server_status = "unknown", still evaluates on HTTP code | Does not crash, `CHECK_HEALTH` based on HTTP code |
| 7.8 | Python unavailable for JSON parsing | Theoretical edge case (Python validated in step 5); verify code path by inspection | Falls back to HTTP-code-only evaluation | `CHECK_HEALTH` set based on curl HTTP code alone |

**Simulation recipe for 7.3 (mock server returning 500):**
```bash
# Start a simple mock server in another terminal:
python3 -c "
from http.server import HTTPServer, BaseHTTPRequestHandler
class H(BaseHTTPRequestHandler):
    def do_GET(self):
        self.send_response(500)
        self.end_headers()
        self.wfile.write(b'{\"status\":\"error\"}')
HTTPServer(('127.0.0.1', 8888), H).serve_forever()
" &
MOCK_PID=$!

# Run script with overridden health URL:
HEALTH_CHECK_URL=http://127.0.0.1:8888/health bash PubMatic_Troubleshooting.sh --yes

# Clean up:
kill $MOCK_PID
```

Note: To override `HEALTH_CHECK_URL` without editing the script, you can temporarily change the constant at the top of the script, or use `sed` to replace it inline for testing purposes.

**Simulation recipe for 7.4:**
```bash
echo "127.0.0.1 apps.pubmatic.com" | sudo tee -a /etc/hosts
bash PubMatic_Troubleshooting.sh --yes
# Revert:
sudo sed -i '' '/apps.pubmatic.com/d' /etc/hosts  # macOS
sudo sed -i '/apps.pubmatic.com/d' /etc/hosts      # Linux
```

---

## Cross-Cutting / Integration Tests

| Test ID | Scenario | How to Simulate | Expected Result | Pass Criteria |
|---------|----------|-----------------|-----------------|---------------|
| X.1 | All 7 checks pass (happy path, end-to-end) | macOS or Linux with Python 3.12, good network, valid certs | Summary table shows all "pass" | Exit code 0, all `CHECK_*="pass"` |
| X.2 | `--yes` flag end-to-end | `bash PubMatic_Troubleshooting.sh --yes` in a Docker container that needs Python install + SSL fix | No interactive prompts, all auto-accepted | "(Auto-accepted via --yes flag)" appears for each prompt |
| X.3 | `NO_COLOR` environment variable | `NO_COLOR=1 bash PubMatic_Troubleshooting.sh` | No ANSI escape codes in stdout | Output piped through `cat -v` shows no `\033[` sequences |
| X.4 | Piped output (non-TTY detection) | `bash PubMatic_Troubleshooting.sh 2>&1 \| cat` | No ANSI escape codes (script detects non-TTY via `[ ! -t 1 ]`) | Same as X.3 |
| X.5 | Log file is created | Run any scenario, check `/tmp/` after | File `/tmp/pubmatic_troubleshooting_YYYYMMDD_HHMMSS.log` exists | File is non-empty, contains header with date and script version |
| X.6 | Log file contains all section details | Run happy path, inspect log file | All 7 section headers present (`[1/7]` through `[7/7]`), PASS/WARN/FAIL entries | `grep -c '^\[' $LOG_FILE` returns >= 7 |
| X.7 | Summary table shows correct mixed statuses | Force one section to warn (e.g., SSL skip) and others to pass | Table shows "pass" for most, "warn" for SSL | Summary output matches actual `CHECK_*` values |
| X.8 | Exit code 1 on any failure | Force network failure (disconnect) | Script exits 1 | `echo $?` returns 1 |
| X.9 | Exit code 0 on all-pass | Happy path | Script exits 0 | `echo $?` returns 0 |
| X.10 | Early abort stops later sections | Disconnect network (section 2 fails) | Sections 3--7 never execute | No `[3/7]` through `[7/7]` in output |
| X.11 | Bash 3.2 compatibility (macOS default) | Run with `/bin/bash` on macOS (which is bash 3.2) | No syntax errors, no "invalid option" | Clean execution, no bash errors in output or log |
| X.12 | Bash 5.x compatibility | Run on Linux with bash 5.2 | No syntax errors | Clean execution |
| X.13 | `curl` missing at startup | Temporarily rename curl: `sudo mv $(which curl) $(which curl).bak` | "curl is required but not found", immediate exit | Exit code 1, no sections execute |

**Simulation recipe for X.3:**
```bash
NO_COLOR=1 bash PubMatic_Troubleshooting.sh 2>&1 | cat -v | grep -c '\^\[\['
# Expected: 0 (no escape sequences)
```

**Simulation recipe for X.11 (macOS bash 3.2):**
```bash
/bin/bash --version  # Confirm 3.2.x
/bin/bash PubMatic_Troubleshooting.sh
```

**Simulation recipe for X.13:**
```bash
sudo mv /usr/bin/curl /usr/bin/curl.bak
bash PubMatic_Troubleshooting.sh
# Revert immediately:
sudo mv /usr/bin/curl.bak /usr/bin/curl
```

---

## Docker Test Commands (Ready to Run)

These commands mount the current directory and run the script inside disposable containers. Use `--yes` to avoid interactive prompts in non-TTY Docker.

### Ubuntu 22.04

```bash
docker run --rm -v "$(pwd)":/app ubuntu:22.04 bash -c \
    "apt-get update -qq && apt-get install -y -qq curl >/dev/null 2>&1 && bash /app/PubMatic_Troubleshooting.sh --yes"
```

### Ubuntu 24.04 (PEP 668 / EXTERNALLY-MANAGED)

```bash
docker run --rm -v "$(pwd)":/app ubuntu:24.04 bash -c \
    "apt-get update -qq && apt-get install -y -qq curl >/dev/null 2>&1 && bash /app/PubMatic_Troubleshooting.sh --yes"
```

### Alpine 3.19 (Minimal -- no DNS tools, no Python)

```bash
docker run --rm -v "$(pwd)":/app alpine:3.19 sh -c \
    "apk add --no-cache bash curl >/dev/null 2>&1 && bash /app/PubMatic_Troubleshooting.sh --yes"
```

### Rocky Linux 9 (RHEL-family, dnf)

```bash
docker run --rm -v "$(pwd)":/app rockylinux:9 bash -c \
    "dnf install -y curl >/dev/null 2>&1 && bash /app/PubMatic_Troubleshooting.sh --yes"
```

### Fedora (Latest, dnf)

```bash
docker run --rm -v "$(pwd)":/app fedora:latest bash -c \
    "dnf install -y curl >/dev/null 2>&1 && bash /app/PubMatic_Troubleshooting.sh --yes"
```

### Debian 12 (PEP 668 / EXTERNALLY-MANAGED)

```bash
docker run --rm -v "$(pwd)":/app debian:12 bash -c \
    "apt-get update -qq && apt-get install -y -qq curl >/dev/null 2>&1 && bash /app/PubMatic_Troubleshooting.sh --yes"
```

---

## Known Issues / Edge Cases

### 1. Bash 3.2 Nameref Incompatibility (Resolved)

**What happened:** During the first implementation run on macOS, the script failed with `local: -n: invalid option` because `display_and_run_steps()` used `local -n` (bash namerefs), which require bash 4.3+. macOS ships `/bin/bash` v3.2.

**Resolution:** Replaced with indirect expansion (`${!steps_var}`), which is compatible with bash 3.2+. See the "Implementation Notes" section in `PubMatic_Troubleshooting_Plan.md` for the full before/after and a table of bash features to avoid.

**Test:** Run `X.11` to verify.

### 2. Python 3.14+ Detected as Out of Range

**What happened:** On a macOS machine with Homebrew Python 3.14.3, the script correctly identified it as outside the supported range (3.8--3.13.99) and presented the install plan for Python 3.12.9. The download step succeeded, but the `sudo installer` step failed because the terminal session did not have admin privileges.

**Expected behavior:** This is correct. The script:
- Correctly rejected Python 3.14.3
- Showed the exact install commands before asking for confirmation
- Failed gracefully when `sudo installer` was denied
- Printed a clear error message pointing to the log file

**Test:** Run `5.4` to verify.

### 3. `sudo` Prompts in Non-Interactive Environments

Python install (section 5) and SSL fix (section 6) require `sudo` for some steps. In non-interactive environments (Docker, CI), `sudo` may fail if the user is not in sudoers or if no password can be provided.

**Mitigation:** Run Docker containers as root, or ensure the CI user has passwordless sudo. The `--yes` flag handles prompt auto-acceptance but does not bypass `sudo` password requirements.

### 4. Corporate Proxies and Certificate Interception

Some corporate environments use MITM proxies that inject custom CA certificates. In these cases:
- Section 6 (SSL) may fail even after applying the fix
- The certifi bundle does not include corporate CA certificates
- The user may need to manually add their corporate CA to the Python certificate store

**Test:** This is difficult to simulate in testing. Document it as a known limitation and advise users in corporate environments to contact their IT department if section 6 repeatedly fails.

### 5. Homebrew PATH Precedence Shadows Installed Python (Resolved)

**What happened:** On macOS with Homebrew, after successfully installing Python 3.12.9 from python.org and symlinking it to `/usr/local/bin/python3`, the post-install verification still reported Python 3.14.3. This is because `/opt/homebrew/bin` comes before `/usr/local/bin` in PATH, so `command -v python3` resolved to Homebrew's Python 3.14.3 instead of the newly installed 3.12.9.

```
PATH=...:/opt/homebrew/bin:/opt/homebrew/sbin:/usr/local/bin:...
```

**Resolution:** `find_python()` now uses a three-tier lookup after install:
1. Check `INSTALLED_PYTHON_BIN` (the known absolute path of the binary just installed)
2. Check `/usr/local/bin/python3` explicitly and verify its version is in range
3. Fall back to generic `command -v python3` only if the above don't match

**Test:** Run `5.15` to verify.

### 6. `sort -V` Availability

Version comparison uses `sort -V` (version sort). This is available on:
- macOS 10.15+ (Catalina and later)
- GNU coreutils (all modern Linux)

On very old systems where `sort -V` is unavailable, `version_in_range()` will silently produce incorrect results. This is considered acceptable since the minimum supported macOS is 10.15 and all modern Linux distros include GNU coreutils.

---

## Test Execution Checklist

Use this checklist to track test progress across environments:

```
Environment: _______________
Date: _______________
Tester: _______________

Section 1 -- Self-Upgrade
  [ ] 1.1 Up to date
  [ ] 1.2 Newer version exists
  [ ] 1.3 GitHub unreachable
  [ ] 1.4 No tag_name
  [ ] 1.5 User declines
  [ ] 1.6 --yes auto-accept

Section 2 -- Network
  [ ] 2.1 Normal connectivity
  [ ] 2.2 google.com blocked
  [ ] 2.3 No internet
  [ ] 2.4 Proxy blocks HTTPS
  [ ] 2.5 Slow connection

Section 3 -- DNS
  [ ] 3.1 host available
  [ ] 3.2 nslookup fallback
  [ ] 3.3 dig fallback
  [ ] 3.4 curl fallback (no DNS tools)
  [ ] 3.5 DNS failure
  [ ] 3.6 VPN blocking

Section 4 -- Platform
  [ ] 4.1 macOS arm64
  [ ] 4.2 macOS x86_64
  [ ] 4.3 Ubuntu
  [ ] 4.4 RHEL/Rocky
  [ ] 4.5 Alpine
  [ ] 4.6 Unsupported OS
  [ ] 4.7 Missing /etc/os-release

Section 5 -- Python
  [ ] 5.1  Python 3.12 installed
  [ ] 5.2  Python 3.8 (min boundary)
  [ ] 5.3  Python 3.13 (near max)
  [ ] 5.4  Python 3.14+ (above max)
  [ ] 5.5  Python 3.7 (below min)
  [ ] 5.6  python fallback (no python3)
  [ ] 5.7  No Python at all
  [ ] 5.8  User declines install
  [ ] 5.9  --yes auto-install
  [ ] 5.10 macOS steps displayed
  [ ] 5.11 Ubuntu steps displayed
  [ ] 5.12 RHEL/Fedora steps displayed
  [ ] 5.13 No package manager
  [ ] 5.14 Post-install verification
  [ ] 5.15 Homebrew PATH shadows installed Python

Section 6 -- SSL
  [ ] 6.1 SSL passes
  [ ] 6.2 SSL fails, user accepts fix
  [ ] 6.3 SSL fails, user declines
  [ ] 6.4 macOS fix steps
  [ ] 6.5 Ubuntu fix steps
  [ ] 6.6 pip missing
  [ ] 6.7 PEP 668 detection
  [ ] 6.8 Fix applied, still fails
  [ ] 6.9 --yes auto-fix

Section 7 -- Health
  [ ] 7.1 HTTP 200, fast
  [ ] 7.2 HTTP 200, slow
  [ ] 7.3 HTTP 500
  [ ] 7.4 Unreachable
  [ ] 7.5 Timeout
  [ ] 7.6 Valid JSON body
  [ ] 7.7 Non-JSON body
  [ ] 7.8 Python unavailable

Cross-Cutting
  [ ] X.1  All pass (happy path)
  [ ] X.2  --yes end-to-end
  [ ] X.3  NO_COLOR
  [ ] X.4  Piped output
  [ ] X.5  Log file created
  [ ] X.6  Log file contents
  [ ] X.7  Mixed status summary
  [ ] X.8  Exit code on failure
  [ ] X.9  Exit code on success
  [ ] X.10 Early abort
  [ ] X.11 Bash 3.2 compat
  [ ] X.12 Bash 5.x compat
  [ ] X.13 curl missing
```
