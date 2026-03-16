# PubMatic Troubleshooting Script — Design Plan (v2)

## Overview

`PubMatic_Troubleshooting.sh` is a lightweight diagnostic script for the PubMatic MCP Server extension. It runs **4 ordered checks**: network connectivity, DNS resolution, SSL certificate validation, and MCP server health.

Python installation and platform detection have been removed because the `.mcpb` bundle now ships with an **embedded Python 3.12.13 runtime** (`runtime/python3`). Claude Desktop uses the bundled Python exclusively — the host system's Python is never invoked. See `EMBEDDED_RUNTIME.md` for details.

---

## Why Only 4 Checks

| Removed Check | Reason Removed |
|--------------|----------------|
| Self-upgrade | Reduces script complexity; users re-download from GitHub when needed |
| Platform detection | No longer needed — embedded Python removes all platform/OS branching |
| Python check & install | Embedded runtime — host Python is irrelevant |

The 4 remaining checks cover the only things that can actually block the extension: network access, name resolution, TLS trust, and server availability.

---

## Dependency Philosophy

**Two hard dependencies only:**
- `bash` (v3.2+ — ships with macOS, v4+ on Linux)
- `curl` (ships with macOS, present on all Linux distros)

No Python, no pip, no package manager checks. The script verifies `curl` is available at startup and aborts with a clear message if not.

---

## Execution Flow

```
[1/4] Network Check
        ↓
[2/4] DNS Check
        ↓
[3/4] SSL Check
        ↓
[4/4] MCP Health Check
        ↓
     Summary
```

Each step exits immediately on failure so later steps don't produce misleading results.

---

## Section Details

### 1. Network Check (`check_network`)

**Dependency:** `curl` only

- Attempts `curl -fsS --max-time 5 -o /dev/null https://www.google.com`
- Falls back to `curl -fsS --max-time 5 -o /dev/null https://1.1.1.1`
- On any failure: prints "No internet connectivity detected", sets `CHECK_NETWORK="fail"`, exits
- On success: sets `CHECK_NETWORK="pass"`

**Why curl and not ping:** ICMP is blocked by most corporate firewalls and VPNs. curl over HTTPS tests the actual protocol the extension needs.

---

### 2. DNS Check (`check_dns`)

**Dependency:** whichever DNS tool is available, with cascading fallback to `curl`

Tries tools in order: `host` → `nslookup` → `dig` → curl exit-code-6 fallback.

```bash
resolve_dns() {
    local host="$1"
    if has_cmd host; then
        host "$host" 2>/dev/null | grep "has address"
    elif has_cmd nslookup; then
        nslookup "$host" 2>/dev/null | grep -A1 "Name:" | grep "Address"
    elif has_cmd dig; then
        dig +short "$host" 2>/dev/null
    else
        curl -fsS --max-time 5 -o /dev/null "https://${host}" 2>/dev/null
        if [ $? -eq 0 ]; then
            echo "(resolved via curl — no DNS tool available to show IP)"
        elif [ $? -eq 6 ]; then
            return 1   # DNS failure
        fi
    fi
}
```

curl exit code 6 means "could not resolve host" — a reliable DNS failure signal even without any dedicated DNS tooling.

- On failure: prints error, sets `CHECK_DNS="fail"`, exits
- On success: sets `CHECK_DNS="pass"`, shows resolved IP (when available)

---

### 3. SSL Check (`check_ssl`)

**Dependency:** `curl` only

Tests the TLS handshake and certificate chain using curl's built-in SSL verification:

```bash
curl -fsS --max-time 10 -o /dev/null \
    --write-out "%{ssl_verify_result}:%{http_code}" \
    "https://${MCP_HOST}"
```

curl exit codes mapped to outcomes:

| curl exit code | Meaning | Script action |
|----------------|---------|---------------|
| 0 | Success (2xx response) | `CHECK_SSL="pass"` |
| 22 | HTTP error (non-2xx), but TLS succeeded | `CHECK_SSL="pass"` — TLS was fine |
| 35 | SSL connect error | `CHECK_SSL="fail"`, exits |
| 60 | SSL certificate problem (untrusted CA, expired, hostname mismatch) | `CHECK_SSL="fail"`, exits |
| other | Unexpected error | `CHECK_SSL="warn"`, continues |

This replaces the previous Python `ssl.create_default_context()` handshake test. curl uses the OS certificate store (same store the embedded Python runtime uses), so the result is equivalent.

- On failure: prints SSL error detail, exits
- On pass: sets `CHECK_SSL="pass"`

---

### 4. MCP Server Health Check (`check_health`)

**Dependency:** `curl` (primary), `awk` (for response-time comparison — POSIX, always present)

```bash
http_output=$(curl -sS -o "$body_file" \
    -w "%{http_code}:%{time_total}" \
    --max-time 15 \
    -H "Accept: application/json" \
    "$HEALTH_CHECK_URL")
```

- Parses HTTP status code and response time from the curl write-out format
- HTTP 2xx → pass; anything else → fail
- Response time > 5 seconds → warn (reachable but slow)
- No HTTP code returned (timeout/network drop) → fail
- Response body logged for support debugging (first 500 bytes)
- Response-time threshold comparison done with `awk` (avoids bash float arithmetic)

Status outcomes: `pass`, `warn` (slow), `fail`

---

## Constants

| Constant | Value | Purpose |
|----------|-------|---------|
| `SCRIPT_VERSION` | `"2.0.0"` | Version identifier in logs |
| `MCP_HOST` | `"mcp.pubmatic.com"` | Used for DNS and SSL checks |
| `HEALTH_CHECK_URL` | `"https://apps.pubmatic.com/mcpserver/health"` | Full health endpoint URL |
| `HEALTH_RESPONSE_THRESHOLD` | `5` | Seconds before health check is flagged as slow |

---

## Final Summary Output

```
==========================================
 PubMatic MCP Server — Sanity Check Summary
==========================================
 [1/4] Network              pass
 [2/4] DNS                  pass
 [3/4] SSL                  pass
 [4/4] MCP Health           pass
==========================================

 Log file: /tmp/pubmatic_troubleshooting_20260316_143022.log

 ✔ All checks passed. Claude Desktop is ready to use the PubMatic MCP Server.
```

Any `fail` exits with code 1 and prompts the user to share the log with PubMatic support. Any `warn` exits with code 0 but prints guidance to resolve the warnings.

---

## Key Design Decisions

- **Only two hard dependencies: `bash` and `curl`** — no Python, pip, package managers, or OS detection
- **SSL tested via curl** — uses the OS certificate store, which is the same store the embedded Python runtime uses; no Python needed for this check
- **No self-upgrade check** — reduces complexity; users download the latest script directly from GitHub
- **No platform detection** — embedded runtime removes all platform branching
- **No Python check or install** — bundled `runtime/python3` makes host Python irrelevant
- **Early exit on failure** — each check calls `fail()` which exits immediately, preventing misleading downstream results
- **Modular functions** — each section is a standalone function for readability and testability
- **Bash 3.2 compatible** — no `local -n`, `declare -A`, `readarray`, `${var,,}`, or other bash 4+ features
- **`NO_COLOR` support** — ANSI codes suppressed when `NO_COLOR` is set or stdout is not a TTY
- **Log file always written** — every run creates a timestamped log at `/tmp/pubmatic_troubleshooting_*.log` for support debugging

---

## Embedded Runtime Context

The `.mcpb` bundle structure after the embedded-runtime migration:

```
PubMatic_MCP_Server/
├── icon.png
├── manifest.json
├── lib/                    ← Python shared libraries (libpython3.12.dylib, etc.)
├── runtime/
│   └── python3             ← Standalone Python 3.12.13 binary
└── server/
    └── mcp_bridge.py
```

`manifest.json` now specifies:
```json
"command": "${__dirname}/runtime/python3"
```

Claude Desktop uses `runtime/python3` directly — it never resolves `python3` from PATH. This eliminates all host-Python issues (wrong version, PATH divergence between terminal and GUI, missing Homebrew symlinks, corporate restrictions).

The troubleshooting script no longer needs to care about any of this. Its only job is to verify the network path to the server is clear.
