# PubMatic Troubleshooting Script — Testing Plan (v2)

This document covers testing for `PubMatic_Troubleshooting.sh` across its 4 checks: network, DNS, SSL, and MCP health. Python, platform detection, and self-upgrade sections have been removed because the `.mcpb` bundle now ships with an embedded Python 3.12.13 runtime.

---

## Test Environment Matrix

| ID | OS | Arch | Notes |
|----|----|------|-------|
| E1 | macOS Sonoma/Sequoia | arm64 | Primary target (Apple Silicon) |
| E2 | macOS Ventura+ | x86_64 | Intel Mac |
| E3 | Ubuntu 22.04 | x86_64 | Linux happy path |
| E4 | Alpine 3.19 (Docker) | x86_64 | Minimal environment — no DNS tools pre-installed |
| E5 | Any | Any | No internet (airplane mode / firewall) |

---

## Section 1: Network Check (`check_network`)

| Test ID | Scenario | How to Simulate | Expected Result | Pass Criteria |
|---------|----------|-----------------|-----------------|---------------|
| 1.1 | Normal internet connectivity | Run on a connected machine | "Internet connectivity confirmed" | `CHECK_NETWORK="pass"` |
| 1.2 | google.com blocked, 1.1.1.1 reachable | Add `127.0.0.1 www.google.com` to `/etc/hosts` | Still passes via 1.1.1.1 fallback | `CHECK_NETWORK="pass"`, log shows "via 1.1.1.1 fallback" |
| 1.3 | No internet at all | Disconnect Wi-Fi / disable network interface | "No internet connectivity detected", script exits | `CHECK_NETWORK="fail"`, exit code 1 |
| 1.4 | Proxy blocks HTTPS | `https_proxy=http://127.0.0.1:9999 bash PubMatic_Troubleshooting.sh` | Script exits with network error | `CHECK_NETWORK="fail"`, exit code 1 |

**Simulation recipe for 1.3 (macOS):**
```bash
networksetup -setairportpower en0 off
bash PubMatic_Troubleshooting.sh
# Revert:
networksetup -setairportpower en0 on
```

**Simulation recipe for 1.4:**
```bash
https_proxy=http://127.0.0.1:9999 bash PubMatic_Troubleshooting.sh
```

---

## Section 2: DNS Check (`check_dns`)

| Test ID | Scenario | How to Simulate | Expected Result | Pass Criteria |
|---------|----------|-----------------|-----------------|---------------|
| 2.1 | `host` command available (default macOS/Ubuntu) | Run on standard macOS or Ubuntu | Shows resolved IP via `host` | `CHECK_DNS="pass"`, output contains "has address" |
| 2.2 | Only `nslookup` available | `sudo mv $(which host) $(which host).bak` | Falls back to `nslookup`, shows IP | `CHECK_DNS="pass"` |
| 2.3 | Only `dig` available | Rename both `host` and `nslookup` | Falls back to `dig +short` | `CHECK_DNS="pass"` |
| 2.4 | No DNS tools at all (curl fallback) | Alpine Docker (no bind-utils installed) | Prints "(resolved via curl — no DNS tool available to show IP)" | `CHECK_DNS="pass"` |
| 2.5 | DNS resolution fails completely | Add `127.0.0.1 mcp.pubmatic.com` to `/etc/hosts` | "DNS resolution failed", script exits | `CHECK_DNS="fail"`, exit code 1 |
| 2.6 | Split-tunnel VPN blocks mcp.pubmatic.com | Connect to a VPN that does not route this domain | "DNS resolution failed", script exits | `CHECK_DNS="fail"`, exit code 1 |

**Simulation recipe for 2.2 (macOS):**
```bash
sudo mv /usr/bin/host /usr/bin/host.bak
bash PubMatic_Troubleshooting.sh
# Revert:
sudo mv /usr/bin/host.bak /usr/bin/host
```

**Simulation recipe for 2.4 (Docker — Alpine has no DNS tools):**
```bash
docker run --rm -v "$(pwd)":/app alpine:3.19 sh -c \
    "apk add --no-cache bash curl && bash /app/PubMatic_Troubleshooting.sh"
```

**Simulation recipe for 2.5:**
```bash
echo "127.0.0.1 mcp.pubmatic.com" | sudo tee -a /etc/hosts
bash PubMatic_Troubleshooting.sh
# Revert:
sudo sed -i '' '/mcp.pubmatic.com/d' /etc/hosts   # macOS
sudo sed -i '/mcp.pubmatic.com/d' /etc/hosts        # Linux
```

---

## Section 3: SSL Check (`check_ssl`)

| Test ID | Scenario | How to Simulate | Expected Result | Pass Criteria |
|---------|----------|-----------------|-----------------|---------------|
| 3.1 | SSL handshake succeeds (happy path) | Standard setup with valid system certificates | "SSL certificate for mcp.pubmatic.com is valid" | `CHECK_SSL="pass"` |
| 3.2 | SSL certificate problem (curl exit 60) | `SSL_CERT_FILE=/dev/null bash PubMatic_Troubleshooting.sh` | "SSL certificate verification failed", script exits | `CHECK_SSL="fail"`, exit code 1 |
| 3.3 | SSL connect error (curl exit 35) | Use iptables/firewall to block port 443 on the target IP | "SSL certificate verification failed", script exits | `CHECK_SSL="fail"`, exit code 1 |
| 3.4 | Server returns HTTP error (e.g. 401/403), but TLS is valid | Normal — the real endpoint may return a non-2xx if no auth token is sent | SSL check still passes (TLS succeeded) | `CHECK_SSL="pass"` (curl exit 22 is treated as SSL-pass) |
| 3.5 | Corporate MITM proxy with custom CA | Corporate environment with SSL inspection | Depends on whether system trust store includes corporate CA | If CA is trusted: `CHECK_SSL="pass"`; if not: `CHECK_SSL="fail"` |

**Simulation recipe for 3.2 (macOS/Linux — remove system CA trust):**
```bash
SSL_CERT_FILE=/dev/null bash PubMatic_Troubleshooting.sh
# On macOS, if SSL_CERT_FILE is not honoured by the OS keychain, use:
SSL_CERT_DIR=/dev/null SSL_CERT_FILE=/dev/null bash PubMatic_Troubleshooting.sh
```

---

## Section 4: MCP Server Health Check (`check_health`)

| Test ID | Scenario | How to Simulate | Expected Result | Pass Criteria |
|---------|----------|-----------------|-----------------|---------------|
| 4.1 | Health endpoint returns 200, fast | Normal connectivity to apps.pubmatic.com | "MCP Server is healthy (HTTP 200, Xs)" | `CHECK_HEALTH="pass"` |
| 4.2 | Health endpoint returns 200, slow (>5s) | Add network latency with `tc` (Linux) or a throttling proxy | "MCP Server is reachable but slow" | `CHECK_HEALTH="warn"` |
| 4.3 | Health endpoint returns 500 | Point `HEALTH_CHECK_URL` at a mock server returning 500 | "PubMatic MCP Server returned HTTP 500", script exits | `CHECK_HEALTH="fail"`, exit code 1 |
| 4.4 | Health endpoint unreachable (DNS blocked) | Add `127.0.0.1 apps.pubmatic.com` to `/etc/hosts` | "Could not reach PubMatic MCP Server" | `CHECK_HEALTH="fail"`, exit code 1 |
| 4.5 | Health endpoint times out (firewall DROP) | iptables DROP on destination (Linux) | HTTP code "000", "Could not reach" | `CHECK_HEALTH="fail"`, exit code 1 |
| 4.6 | Response body is not JSON | Point `HEALTH_CHECK_URL` at a URL returning HTML | Does not crash; `CHECK_HEALTH` based on HTTP code | No crash, `CHECK_HEALTH="pass"` if HTTP 2xx |

**Simulation recipe for 4.3 (mock server returning 500):**
```bash
# Start mock server in another terminal:
python3 -c "
from http.server import HTTPServer, BaseHTTPRequestHandler
class H(BaseHTTPRequestHandler):
    def do_GET(self):
        self.send_response(500)
        self.end_headers()
        self.wfile.write(b'{\"status\":\"error\"}')
    def log_message(self, *a): pass
HTTPServer(('127.0.0.1', 8888), H).serve_forever()
" &
MOCK_PID=$!

# Edit HEALTH_CHECK_URL in a temp copy and run:
sed 's|HEALTH_CHECK_URL=.*|HEALTH_CHECK_URL="http://127.0.0.1:8888/health"|' \
    PubMatic_Troubleshooting.sh > /tmp/pm_test.sh
bash /tmp/pm_test.sh

kill $MOCK_PID
```

**Simulation recipe for 4.4:**
```bash
echo "127.0.0.1 apps.pubmatic.com" | sudo tee -a /etc/hosts
bash PubMatic_Troubleshooting.sh
# Revert:
sudo sed -i '' '/apps.pubmatic.com/d' /etc/hosts   # macOS
sudo sed -i '/apps.pubmatic.com/d' /etc/hosts        # Linux
```

---

## Cross-Cutting / Integration Tests

| Test ID | Scenario | How to Simulate | Expected Result | Pass Criteria |
|---------|----------|-----------------|-----------------|---------------|
| X.1 | All 4 checks pass (happy path, end-to-end) | Connected machine with valid certs and reachable server | Summary table shows all "pass" | Exit code 0, all `CHECK_*="pass"` |
| X.2 | `NO_COLOR` environment variable | `NO_COLOR=1 bash PubMatic_Troubleshooting.sh` | No ANSI escape codes in stdout | Output piped through `cat -v` shows no `\033[` sequences |
| X.3 | Piped output (non-TTY detection) | `bash PubMatic_Troubleshooting.sh 2>&1 \| cat` | No ANSI escape codes | Same as X.2 |
| X.4 | Log file is created | Run any scenario, check `/tmp/` after | File `/tmp/pubmatic_troubleshooting_YYYYMMDD_HHMMSS.log` exists | File is non-empty, contains header with date and script version |
| X.5 | Log file contains all section headers | Run happy path, inspect log | Headers `[1/4]` through `[4/4]` present | `grep -c '^\[' $LOG_FILE` returns >= 4 |
| X.6 | Mixed statuses in summary | Force one section to warn (e.g., block mcp.pubmatic.com briefly to slow health) | Table shows mix of "pass" and "warn" | Summary matches actual `CHECK_*` values |
| X.7 | Exit code 1 on any failure | Disconnect network | Script exits 1 | `echo $?` returns 1 |
| X.8 | Exit code 0 on all-pass | Happy path | Script exits 0 | `echo $?` returns 0 |
| X.9 | Early abort stops later sections | Disconnect network (section 1 fails) | Sections 2–4 never execute | No `[2/4]` through `[4/4]` in output |
| X.10 | Bash 3.2 compatibility (macOS default) | `/bin/bash PubMatic_Troubleshooting.sh` on macOS | No syntax errors, clean execution | No bash errors in output or log |
| X.11 | Bash 5.x compatibility | Run on Linux with bash 5.2 | Clean execution | No syntax errors |
| X.12 | `curl` missing at startup | `sudo mv $(which curl) $(which curl).bak` | "curl is required but not found", immediate exit | Exit code 1, no sections execute |

**Simulation recipe for X.2:**
```bash
NO_COLOR=1 bash PubMatic_Troubleshooting.sh 2>&1 | cat -v | grep -c '\^\[\['
# Expected: 0
```

**Simulation recipe for X.10 (macOS bash 3.2):**
```bash
/bin/bash --version   # Confirm 3.2.x
/bin/bash PubMatic_Troubleshooting.sh
```

---

## Docker Test Commands (Ready to Run)

### Ubuntu 22.04

```bash
docker run --rm -v "$(pwd)":/app ubuntu:22.04 bash -c \
    "apt-get update -qq && apt-get install -y -qq curl >/dev/null 2>&1 && bash /app/PubMatic_Troubleshooting.sh"
```

### Alpine 3.19 (Minimal — no DNS tools)

```bash
docker run --rm -v "$(pwd)":/app alpine:3.19 sh -c \
    "apk add --no-cache bash curl >/dev/null 2>&1 && bash /app/PubMatic_Troubleshooting.sh"
```

### Rocky Linux 9 (RHEL-family)

```bash
docker run --rm -v "$(pwd)":/app rockylinux:9 bash -c \
    "dnf install -y curl >/dev/null 2>&1 && bash /app/PubMatic_Troubleshooting.sh"
```

---

## Known Issues / Edge Cases

### 1. Corporate MITM SSL Inspection

Some corporate environments inject custom CA certificates and perform SSL inspection. In these cases, section 3 (SSL) may fail even though the network is working.

**Mitigation:** The user needs to ensure their corporate CA is added to the OS trust store. Contact IT if section 3 repeatedly fails on a corporate network.

### 2. `SSL_CERT_FILE` Does Not Override macOS Keychain

On macOS, curl uses the OS keychain for certificate validation rather than `SSL_CERT_FILE`. Setting `SSL_CERT_FILE=/dev/null` may not reliably force an SSL failure on macOS for test 3.2. Use an outbound firewall rule or a non-routable IP to reliably block port 443 for SSL failure testing.

### 3. `sort -V` Availability

Version comparison (not used in the current 4-check script) was the only place `sort -V` appeared. With the removal of the Python version check, `sort -V` is no longer used. No compatibility concern.

### 4. Bash 3.2 Compatibility

All bash features in this script are validated against bash 3.2 (the version shipped with macOS). Features to avoid:

| Feature | Requires | Alternative used |
|---------|----------|-----------------|
| `local -n` (namerefs) | bash 4.3+ | Not used |
| `declare -A` (associative arrays) | bash 4.0+ | Not used |
| `readarray` / `mapfile` | bash 4.0+ | Not used |
| `${var,,}` lowercase | bash 4.0+ | `awk tolower` if needed |

---

## Test Execution Checklist

```
Environment: _______________
Date:        _______________
Tester:      _______________

Section 1 — Network
  [ ] 1.1  Normal connectivity
  [ ] 1.2  google.com blocked, 1.1.1.1 reachable
  [ ] 1.3  No internet
  [ ] 1.4  Proxy blocks HTTPS

Section 2 — DNS
  [ ] 2.1  host available
  [ ] 2.2  nslookup fallback
  [ ] 2.3  dig fallback
  [ ] 2.4  curl fallback (no DNS tools)
  [ ] 2.5  DNS failure
  [ ] 2.6  VPN blocking

Section 3 — SSL
  [ ] 3.1  SSL passes (happy path)
  [ ] 3.2  SSL cert problem (curl exit 60)
  [ ] 3.3  SSL connect error (curl exit 35)
  [ ] 3.4  HTTP error but TLS valid (curl exit 22)
  [ ] 3.5  Corporate MITM proxy

Section 4 — MCP Health
  [ ] 4.1  HTTP 200, fast
  [ ] 4.2  HTTP 200, slow (>5s)
  [ ] 4.3  HTTP 500
  [ ] 4.4  Unreachable
  [ ] 4.5  Timeout
  [ ] 4.6  Non-JSON body

Cross-Cutting
  [ ] X.1   All pass (happy path)
  [ ] X.2   NO_COLOR
  [ ] X.3   Piped output (non-TTY)
  [ ] X.4   Log file created
  [ ] X.5   Log file contents
  [ ] X.6   Mixed status summary
  [ ] X.7   Exit code 1 on failure
  [ ] X.8   Exit code 0 on success
  [ ] X.9   Early abort
  [ ] X.10  Bash 3.2 compat (macOS)
  [ ] X.11  Bash 5.x compat (Linux)
  [ ] X.12  curl missing at startup
```
