#!/bin/bash

set -e

MIN_VERSION="3.8"
MAX_VERSION="3.13.99"
PYTHON_PKG_VERSION="3.12.9"
PYTHON_PKG_URL="https://www.python.org/ftp/python/${PYTHON_PKG_VERSION}/python-${PYTHON_PKG_VERSION}-macos11.pkg"
MCP_HOST="mcp.pubmatic.com"
HEALTH_CHECK_URL="https://apps.pubmatic.com/mcpserver/health"
HEALTH_RESPONSE_THRESHOLD=5

# ─── LOGGING SETUP ────────────────────────────────────────────────────────────
LOG_FILE="/tmp/pubmatic_troubleshooting_$(date +%Y%m%d_%H%M%S).log"
# Write all verbose detail to the log file for troubleshooting purposes
log() { echo "$1" >> "$LOG_FILE"; }

echo "----------------------------------------"
echo " PubMatic MCP Server - Sanity Check"
echo "----------------------------------------"
echo ""
log "=========================================="
log " PubMatic MCP Server - Sanity Check Log"
log " $(date)"
log "=========================================="
log ""

# Tracks overall pass/fail per section for the final summary
CHECK_PYTHON="pending"
CHECK_SSL="pending"
CHECK_NETWORK="pending"
CHECK_HEALTH="pending"

# ─── HELPER ───────────────────────────────────────────────────────────────────
fail() {
    local user_msg="$1"
    local detail="$2"
    echo "  ❌ $user_msg"
    echo "     Please reach out to PubMatic support and share the log file:"
    echo "     $LOG_FILE"
    log "FAILURE: $user_msg"
    log "DETAIL:  $detail"
    exit 1
}

warn() { log "WARN: $1"; }

# Function to compare versions
version_in_range() {
    local version=$1
    local min=$2
    local max=$3
    if [[ "$(printf '%s\n' "$min" "$version" | sort -V | head -n1)" == "$min" ]] && \
       [[ "$(printf '%s\n' "$version" "$max" | sort -V | head -n1)" == "$version" ]]; then
        return 0
    else
        return 1
    fi
}

# ─── CHECK PYTHON ─────────────────────────────────────────────────────────────
CURRENT_VERSION=""
SKIP_INSTALL=false

echo "[1/4] Checking Python installation..."
log "[1/4] Checking Python installation"

# Check if the target Python 3.12 is already installed at the python.org path
# before falling back to the system `python3` (which may point to a newer/unsupported version).
PYTHONORG_BIN_PRECHECK="/Library/Frameworks/Python.framework/Versions/3.12/bin/python3.12"
if [ -x "$PYTHONORG_BIN_PRECHECK" ]; then
    CURRENT_VERSION=$("$PYTHONORG_BIN_PRECHECK" --version | awk '{print $2}')
    log "Python $CURRENT_VERSION already installed (python.org)."
    echo "      Python $CURRENT_VERSION is already installed."
    SKIP_INSTALL=true
elif command -v python3 &> /dev/null; then
    CURRENT_VERSION=$(python3 --version | awk '{print $2}')
    if version_in_range "$CURRENT_VERSION" "$MIN_VERSION" "$MAX_VERSION"; then
        log "Python $CURRENT_VERSION — supported."
        echo "      Python $CURRENT_VERSION is already installed."
        SKIP_INSTALL=true
    else
        warn "Python $CURRENT_VERSION is not in the supported range (3.8–3.13.x). Installing Python 3.12..."
        echo "      Python $CURRENT_VERSION found but not compatible. Installing Python ${PYTHON_PKG_VERSION}..."
        SKIP_INSTALL=false
    fi
else
    warn "Python 3 not found. Installing Python 3.12..."
    echo "      Python not found. Installing Python ${PYTHON_PKG_VERSION}..."
    SKIP_INSTALL=false
fi

# ─── INSTALL PYTHON IF NEEDED ─────────────────────────────────────────────────
if [ "$SKIP_INSTALL" = false ]; then
    TMP_PKG="/tmp/python-${PYTHON_PKG_VERSION}-macos11.pkg"

    echo "      Downloading Python ${PYTHON_PKG_VERSION}... (this may take a moment)"
    log "Downloading Python ${PYTHON_PKG_VERSION} from python.org..."
    if ! curl -fsSL "$PYTHON_PKG_URL" -o "$TMP_PKG"; then
        fail "Could not download Python installer." "Check your internet connection and try again."
    fi

    echo "      Installing Python ${PYTHON_PKG_VERSION}... (you may be prompted for your password)"
    log "Installing Python ${PYTHON_PKG_VERSION}..."
    if ! sudo installer -pkg "$TMP_PKG" -target / &> /dev/null; then
        rm -f "$TMP_PKG"
        fail "Python installation failed." "installer exited non-zero."
    fi
    rm -f "$TMP_PKG"

    # Python.org installer places binary at a versioned path
    PYTHONORG_BIN="/Library/Frameworks/Python.framework/Versions/3.12/bin/python3.12"
    if [ -x "$PYTHONORG_BIN" ]; then
        CURRENT_VERSION=$("$PYTHONORG_BIN" --version | awk '{print $2}')
        log "Python $CURRENT_VERSION installed."
    else
        fail "Python 3.12 installation could not be verified." "Binary not found at expected path."
    fi
fi

CHECK_PYTHON="pass"
echo "      ✅ Python $CURRENT_VERSION is ready."

# ─── SECTION 2: DETECT EXACT PYTHON BINARY ───────────────────────────────────
PYTHON_MINOR=$(echo "$CURRENT_VERSION" | cut -d. -f1-2)
ACTUAL_PYTHON_BIN=""

# Locate the exact versioned Python binary to use for the SSL wrapper.
# Priority: python.org install > Homebrew > MacPorts (via /usr/local).
for candidate in \
    "/Library/Frameworks/Python.framework/Versions/${PYTHON_MINOR}/bin/python${PYTHON_MINOR}" \
    "/opt/homebrew/opt/python@${PYTHON_MINOR}/bin/python${PYTHON_MINOR}" \
    "/usr/local/opt/python@${PYTHON_MINOR}/bin/python${PYTHON_MINOR}"; do
    if [[ -x "$candidate" ]]; then
        ACTUAL_PYTHON_BIN="$candidate"
        break
    fi
done

if [[ -z "$ACTUAL_PYTHON_BIN" ]]; then
    ACTUAL_PYTHON_BIN=$(python3 -c "import sys; print(sys.executable)")
fi

if [ -z "$ACTUAL_PYTHON_BIN" ]; then
    fail "Could not locate Python binary." "No versioned binary found and sys.executable returned empty."
fi

# ─── ENSURE /usr/local/bin EXISTS (Apple Silicon) ────────────────────────────
echo ""
echo "[2/4] Configuring SSL certificates..."
echo "      (Your admin password may be required to update system Python settings.)"
log "[2/4] Configuring SSL certificates"
log "ACTUAL_PYTHON_BIN: $ACTUAL_PYTHON_BIN"

if [ ! -d /usr/local/bin ]; then
    sudo mkdir -p /usr/local/bin
fi

# Back up existing python3 at /usr/local/bin (clean up previous backup first)
if [ -f /usr/local/bin/python3 ] || [ -L /usr/local/bin/python3 ]; then
    sudo rm -f /usr/local/bin/python3.symlink.bak
    sudo mv /usr/local/bin/python3 /usr/local/bin/python3.symlink.bak
fi

# ─── CREATE SSL WRAPPER ────────────────────────────────────────────────────────
sudo tee /usr/local/bin/python3 > /dev/null <<SH
#!/bin/sh
export SSL_CERT_FILE="/private/etc/ssl/cert.pem"
export REQUESTS_CA_BUNDLE="/private/etc/ssl/cert.pem"
exec "$ACTUAL_PYTHON_BIN" "\$@"
SH
sudo chmod +x /usr/local/bin/python3

# Verify wrapper correctly injects SSL env
VERIFY_OUTPUT=$(/usr/local/bin/python3 -c "import os; print(os.environ.get('SSL_CERT_FILE',''))")
if echo "$VERIFY_OUTPUT" | grep -q "/private/etc/ssl/cert.pem"; then
    log "SSL certificate path configured correctly."
else
    warn "SSL certificate path did not apply as expected. Connectivity may still fail."
fi

# Update certifi — use sudo to write to system site-packages (guaranteed visible to Claude Desktop)
if ! /usr/local/bin/python3 -m pip --version &> /dev/null; then
    /usr/local/bin/python3 -m ensurepip --upgrade &> /dev/null || true
fi

if ! sudo /usr/local/bin/python3 -m pip install --upgrade certifi \
        --break-system-packages --ignore-installed --quiet 2>/dev/null; then
    fail "Failed to update certificate package." "pip install certifi exited non-zero."
fi

# Run Apple's official certificate installer if present (Python.org installs only).
# Run it silently via bash (not `open`) to avoid launching a new Terminal window.
# Errors are suppressed because macOS SIP protects /etc/ssl/cert.pem on modern systems;
# the wrapper + certifi pip install above already handle SSL correctly.
CERT_INSTALLER="/Applications/Python ${PYTHON_MINOR}/Install Certificates.command"
if [ -f "$CERT_INSTALLER" ]; then
    bash "$CERT_INSTALLER" &> /dev/null || true
fi

SSL_BUNDLE=$(/usr/local/bin/python3 -c "import certifi; print(certifi.where())" 2>&1)
if echo "$SSL_BUNDLE" | grep -q ".pem"; then
    log "Certificate bundle: $SSL_BUNDLE"
    CHECK_SSL="pass"
else
    warn "Certificate bundle could not be verified: $SSL_BUNDLE"
    CHECK_SSL="warn"
fi
echo "      ✅ SSL certificates are configured and up to date."

# ─── SECTION 4: NETWORK SANITY CHECKS ────────────────────────────────────────
echo ""
echo "[3/4] Checking network connectivity..."
log "[3/4] Checking network connectivity to $MCP_HOST"

# 4a — Ping mcp.pubmatic.com
if ping -c 3 -W 5000 "${MCP_HOST}" &> /dev/null; then
    log "Ping to $MCP_HOST successful."
else
    log "WARN: Ping to $MCP_HOST failed (ICMP may be blocked by firewall). Continuing with TCP checks."
fi

# 4b — DNS resolution
if /usr/local/bin/python3 -c "import socket; socket.getaddrinfo('${MCP_HOST}', 443)" &> /dev/null; then
    log "DNS resolved $MCP_HOST successfully."
else
    CHECK_NETWORK="fail"
    fail "Cannot connect to PubMatic servers." \
         "DNS resolution failed for $MCP_HOST. Check internet connection or VPN."
fi

# 4c — TCP port 443 reachability
if /usr/local/bin/python3 -c "
import socket
s = socket.create_connection(('${MCP_HOST}', 443), timeout=10)
s.close()
" &> /dev/null; then
    log "TCP port 443 reachable on $MCP_HOST."
else
    CHECK_NETWORK="fail"
    fail "Cannot connect to PubMatic servers." \
         "TCP connection to $MCP_HOST:443 failed. A firewall or VPN may be blocking HTTPS."
fi

# 4d — SSL/TLS handshake
SSL_HANDSHAKE_RESULT=$(/usr/local/bin/python3 -c "
import ssl, socket
ctx = ssl.create_default_context()
with ctx.wrap_socket(socket.socket(), server_hostname='${MCP_HOST}') as s:
    s.connect(('${MCP_HOST}', 443))
    print('ok')
" 2>&1)
if echo "$SSL_HANDSHAKE_RESULT" | grep -q "ok"; then
    log "SSL/TLS handshake with $MCP_HOST successful."
    CHECK_NETWORK="pass"
else
    CHECK_NETWORK="fail"
    log "SSL handshake error: $SSL_HANDSHAKE_RESULT"
    fail "SSL certificate error when connecting to PubMatic." \
         "SSL handshake with $MCP_HOST failed: $SSL_HANDSHAKE_RESULT"
fi
echo "      ✅ Your device can reach PubMatic servers."

# ─── SECTION 5: MCP SERVER HEALTH CHECK ──────────────────
echo ""
echo "[4/4] Checking PubMatic MCP Server health..."
log "[4/4] Health check: GET $HEALTH_CHECK_URL"

HEALTH_RESULT=$(/usr/local/bin/python3 - <<PYEOF
import json, ssl, sys, time
from urllib.request import Request, urlopen
from urllib.error import URLError, HTTPError

url = "${HEALTH_CHECK_URL}"
headers = {
    "Accept":        "application/json, text/event-stream",
    "Content-Type":  "application/json",
}

req = Request(url, headers=headers, method="GET")
ctx = ssl.create_default_context()
start = time.time()
try:
    with urlopen(req, timeout=15, context=ctx) as resp:
        elapsed = time.time() - start
        body = resp.read().decode("utf-8", errors="replace")
        print(f"OK:{elapsed:.3f}:{body[:300]}")
except HTTPError as e:
    elapsed = time.time() - start
    print(f"HTTP_ERROR:{e.code}:{elapsed:.3f}")
except URLError as e:
    print(f"URL_ERROR:{e.reason}")
except Exception as e:
    print(f"ERROR:{e}")
PYEOF
)

if echo "$HEALTH_RESULT" | grep -q "^OK:"; then
    ELAPSED=$(echo "$HEALTH_RESULT" | cut -d: -f2)
    BODY=$(echo "$HEALTH_RESULT" | cut -d: -f3-)
    log "Health endpoint reachable. Response time: ${ELAPSED}s"
    log "Response body: $BODY"
    # Check response time threshold
    SLOW=$(python3 -c "print('yes' if float('${ELAPSED}') > ${HEALTH_RESPONSE_THRESHOLD} else 'no')" 2>/dev/null || echo "no")
    if [ "$SLOW" = "yes" ]; then
        log "WARN: Response time (${ELAPSED}s) exceeds ${HEALTH_RESPONSE_THRESHOLD}s threshold."
        CHECK_HEALTH="warn"
        echo "      ✅ PubMatic MCP Server is reachable but responding slowly (${ELAPSED}s)."
    else
        CHECK_HEALTH="pass"
        echo "      ✅ PubMatic MCP Server is up and healthy (responded in ${ELAPSED}s)."
    fi
    STATUS=$(echo "$BODY" | /usr/local/bin/python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    print(d.get('status','unknown'))
except Exception:
    print('unknown')
" 2>/dev/null || echo "unknown")
    log "Server status: $STATUS"
elif echo "$HEALTH_RESULT" | grep -q "^HTTP_ERROR:"; then
    CODE=$(echo "$HEALTH_RESULT" | cut -d: -f2)
    ELAPSED=$(echo "$HEALTH_RESULT" | cut -d: -f3)
    CHECK_HEALTH="fail"
    log "Health check HTTP error: $CODE (${ELAPSED}s)"
    fail "PubMatic MCP Server is not responding as expected." \
         "Health endpoint returned HTTP $CODE in ${ELAPSED}s."
elif echo "$HEALTH_RESULT" | grep -q "^URL_ERROR:\|^ERROR:"; then
    REASON=$(echo "$HEALTH_RESULT" | cut -d: -f2-)
    CHECK_HEALTH="fail"
    log "Health check connection error: $REASON"
    fail "Could not reach PubMatic MCP Server." \
         "Connection error: $REASON"
else
    CHECK_HEALTH="fail"
    log "Health check unexpected response: $HEALTH_RESULT"
    fail "PubMatic MCP Server returned an unexpected response." \
         "Raw result: $HEALTH_RESULT"
fi

# ─── FINAL RESULT ─────────────────────────────────────────────────────────────
echo ""
if [ "$CHECK_PYTHON" = "fail" ] || [ "$CHECK_SSL" = "fail" ] || \
   [ "$CHECK_NETWORK" = "fail" ] || [ "$CHECK_HEALTH" = "fail" ]; then
    echo "One or more checks failed."
    echo "Please share the log file below with PubMatic support:"
    echo "  $LOG_FILE"
    exit 1
else
    log "All checks passed."
    echo "✅ All checks passed. Claude Desktop is ready to use"
    echo "   the PubMatic MCP Server."
fi
