# PubMatic Troubleshooting Script — Design Plan (v2.1)

## Overview

`PubMatic_Troubleshooting.sh` is a lightweight diagnostic script for the PubMatic MCP Server extension. It runs the following checks in order:

- **Self-upgrade** — fetch the latest version from GitHub and optionally re-exec
- **[0/4] curl** — verify the script's own hard dependency is present
- **[1/4] Network** — confirm internet connectivity
- **[2/4] DNS** — resolve `mcp.pubmatic.com`
- **[3/4] SSL** — verify the TLS certificate for `mcp.pubmatic.com`
- **[4/4] MCP Health** — confirm the health endpoint returns 2xx

Python installation and platform detection have been removed because the `.mcpb` bundle now ships with an **embedded Python 3.12.13 runtime** (`runtime/python3`). Claude Desktop uses the bundled Python exclusively — the host system's Python is never invoked. See `EMBEDDED_RUNTIME.md` for details.

---

## Why Only These Checks

| Removed Check | Reason Removed |
|--------------|----------------|
| Platform detection | No longer needed — embedded Python removes all platform/OS branching |
| Python check & install | Embedded runtime — host Python is irrelevant |

The remaining checks cover the only things that can actually block the extension: network access, name resolution, TLS trust, and server availability.

---

## Dependency Philosophy

**Two hard dependencies only:**
- `bash` (v3.2+ — ships with macOS, v4+ on Linux)
- `curl` (ships with macOS, present on all Linux distros)

No Python, no pip, no package manager checks. The script verifies `curl` is available as its first named check and aborts with a clear message if not.

---

## Execution Flow

```
Self-Upgrade      ← fetch latest from GitHub, re-exec if updated
        ↓
[0/4] curl Check  ← script's own hard dependency
        ↓
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

Each numbered step exits immediately on failure so later steps don't produce misleading results.

---

## Section Details

### Self-Upgrade (`check_upgrade`)

**Dependencies:** `curl`, `grep`, `sed` (all POSIX standard)

- Queries `https://api.github.com/repos/PubMatic/pubmatic-mcp-server/releases/latest`
- Parses `tag_name` with `grep`/`sed` — no `jq` dependency
- Compares with embedded `SCRIPT_VERSION` using `sort -V`
- If newer: prints current vs. latest, downloads the new script, replaces self, re-execs with `exec "$0" "$@"`
- If GitHub is unreachable or version cannot be parsed: logs and continues (`skip`)
- Accepts `--yes` / `-y` flag to auto-accept the update prompt (for CI/automation)
- Status: `pass` (up to date or user declined), `skip` (GitHub unreachable)

---

### 0. curl Check (`check_curl`)

**Dependency:** bash `command` built-in only

Resolves curl's absolute path with `command -v curl` and displays it:

```
[0/4] Checking for curl...
  ✔ curl found: /usr/bin/curl
```

If curl is absent the script prints a clear message and exits before any network operation is attempted.

---

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

The `host` grep matches both IPv4 and IPv6 results:

```bash
host "$host" 2>/dev/null | grep -E "has address|has IPv6 address"
```

curl exit code 6 means "could not resolve host" — a reliable DNS failure signal even without any dedicated DNS tooling.

- On failure: prints error, sets `CHECK_DNS="fail"`, exits
- On success: sets `CHECK_DNS="pass"`, shows resolved addresses (when available, up to 3 lines)

---

### 3. SSL Check (`check_ssl`)

**Dependency:** `curl` only

Tests the TLS handshake and certificate chain for `https://mcp.pubmatic.com`:

```bash
curl -sS --max-time 10 -o /dev/null \
    --write-out "%{ssl_verify_result}:%{http_code}" \
    "https://${MCP_HOST}"
```

`-f` is intentionally **not used**. HTTP-level errors (401, 403, 404) are acceptable — the check only cares whether the TLS handshake succeeded. `ssl_verify_result == 0` is the authoritative pass signal:

| `ssl_verify_result` | curl exit | Outcome |
|---------------------|-----------|---------|
| `0` | any | `CHECK_SSL="pass"` — certificate chain trusted |
| non-zero | 60 or 35 | `CHECK_SSL="fail"` — explicit TLS error |
| non-zero | other | `CHECK_SSL="warn"` — connection-level failure (not TLS-specific) |

The pass message includes both the verify result and the HTTP status code for clarity:

```
  ✔ SSL certificate for mcp.pubmatic.com is valid (verify result: 0, HTTP 200).
```

---

### 4. MCP Server Health Check (`check_health`)

**Dependency:** `curl` (primary), `awk` (for float comparison — POSIX, always present)

```bash
http_output=$(curl -sS -o "$body_file" \
    -w "%{http_code}:%{time_total}" \
    --max-time 15 \
    -H "Accept: application/json" \
    "$HEALTH_CHECK_URL")
```

Response-time threshold uses `awk BEGIN` for reliable float comparison (bash cannot compare floats):

```bash
if awk "BEGIN {exit !($response_time > $HEALTH_RESPONSE_THRESHOLD)}"; then
    # slow
fi
```

- HTTP 2xx → pass; anything else → fail
- Response time > 5 seconds → warn (reachable but slow)
- No HTTP code returned (timeout/network drop) → fail
- Response body logged for support debugging (first 500 bytes)

Status outcomes: `pass`, `warn` (slow), `fail`

---

## Constants

| Constant | Value | Purpose |
|----------|-------|---------|
| `SCRIPT_VERSION` | `"2.1.0"` | Version identifier in logs; compared against GitHub releases |
| `MCP_HOST` | `"mcp.pubmatic.com"` | Used for DNS and SSL checks |
| `HEALTH_CHECK_URL` | `"https://apps.pubmatic.com/mcpserver/health"` | Full health endpoint URL |
| `HEALTH_RESPONSE_THRESHOLD` | `5` | Seconds before health check is flagged as slow |
| `RELEASES_URL` | `"https://api.github.com/repos/PubMatic/pubmatic-mcp-server/releases/latest"` | GitHub API URL for self-upgrade |

---

## Final Summary Output

```
==========================================
 PubMatic MCP Server — Sanity Check Summary
==========================================
 Self-Upgrade               pass
 [0/4] curl                 pass
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
- **Self-upgrade** — script fetches the latest release from GitHub and re-execs itself before running any checks; `--yes`/`-y` auto-accepts for CI use
- **curl pre-flight check `[0/4]`** — shows the resolved curl path so support can see exactly which curl binary ran
- **`-f` intentionally absent from SSL curl** — HTTP 401/403/404 responses are fine; `ssl_verify_result == 0` is the authoritative TLS pass signal
- **Float comparison via `awk BEGIN`** — `awk "BEGIN {exit !($response_time > $HEALTH_RESPONSE_THRESHOLD)}"` is the correct pattern; bash `[ ]` cannot compare floating-point numbers
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
