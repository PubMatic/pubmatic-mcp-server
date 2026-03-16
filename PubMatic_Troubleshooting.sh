#!/bin/bash
# PubMatic MCP Server — Troubleshooting Script
# Runs 4 ordered checks: network, DNS, SSL, MCP health.
# Hard dependencies: bash (v3.2+), curl.

SCRIPT_VERSION="2.0.0"

# ─── CONSTANTS ─────────────────────────────────────────────────────────────────
MCP_HOST="mcp.pubmatic.com"
HEALTH_CHECK_URL="https://apps.pubmatic.com/mcpserver/health"
HEALTH_RESPONSE_THRESHOLD=5

# ─── LOGGING SETUP ─────────────────────────────────────────────────────────────
LOG_FILE="/tmp/pubmatic_troubleshooting_$(date +%Y%m%d_%H%M%S).log"
log() { echo "[$(date '+%H:%M:%S')] $1" >> "$LOG_FILE"; }

# ─── COLOR HELPERS ─────────────────────────────────────────────────────────────
if [ -n "$NO_COLOR" ] || [ ! -t 1 ]; then
    CLR_GREEN="" CLR_RED="" CLR_YELLOW="" CLR_RESET=""
else
    CLR_GREEN="\033[0;32m" CLR_RED="\033[0;31m" CLR_YELLOW="\033[0;33m" CLR_RESET="\033[0m"
fi

green()  { printf "${CLR_GREEN}%s${CLR_RESET}" "$1"; }
red()    { printf "${CLR_RED}%s${CLR_RESET}" "$1"; }
yellow() { printf "${CLR_YELLOW}%s${CLR_RESET}" "$1"; }

# ─── STATUS TRACKING ──────────────────────────────────────────────────────────
CHECK_NETWORK="pending"
CHECK_DNS="pending"
CHECK_SSL="pending"
CHECK_HEALTH="pending"

# ─── HELPER FUNCTIONS ─────────────────────────────────────────────────────────
has_cmd() { command -v "$1" &>/dev/null; }

fail() {
    local user_msg="$1"
    local detail="$2"
    echo ""
    echo -e "  $(red '✘') $user_msg"
    echo "     Please reach out to PubMatic support and share the log file:"
    echo "     $LOG_FILE"
    log "FAILURE: $user_msg"
    log "DETAIL:  $detail"
    exit 1
}

warn_msg() {
    echo -e "  $(yellow '⚠') $1"
    log "WARN: $1"
}

pass_msg() {
    echo -e "  $(green '✔') $1"
    log "PASS: $1"
}

# ─── STARTUP ───────────────────────────────────────────────────────────────────
echo ""
echo "=========================================="
echo " PubMatic MCP Server — Sanity Check"
echo "=========================================="
echo ""
log "=========================================="
log " PubMatic MCP Server — Sanity Check Log"
log " $(date)"
log " Script version: ${SCRIPT_VERSION}"
log "=========================================="

if ! has_cmd curl; then
    echo -e "  $(red '✘') curl is required but not found. Please install curl and re-run this script."
    exit 1
fi

###############################################################################
# 1. NETWORK CHECK
###############################################################################
check_network() {
    echo "[1/4] Checking network connectivity..."
    log "[1/4] Network connectivity check"

    if curl -fsS --max-time 5 -o /dev/null "https://www.google.com" 2>/dev/null; then
        log "Internet connectivity confirmed (via google.com)."
    elif curl -fsS --max-time 5 -o /dev/null "https://1.1.1.1" 2>/dev/null; then
        log "Internet connectivity confirmed (via 1.1.1.1 fallback)."
    else
        CHECK_NETWORK="fail"
        fail "No internet connectivity detected." \
             "curl to both google.com and 1.1.1.1 failed. Check your network, proxy, or VPN settings."
    fi

    CHECK_NETWORK="pass"
    pass_msg "Internet connectivity confirmed."
}

###############################################################################
# 2. DNS CHECK
###############################################################################
resolve_dns() {
    local host="$1"
    if has_cmd host; then
        host "$host" 2>/dev/null | grep "has address"
        return $?
    elif has_cmd nslookup; then
        nslookup "$host" 2>/dev/null | grep -A1 "Name:" | grep "Address"
        return $?
    elif has_cmd dig; then
        dig +short "$host" 2>/dev/null
        return $?
    else
        local exit_code
        curl -fsS --max-time 5 -o /dev/null "https://${host}" 2>/dev/null
        exit_code=$?
        if [ $exit_code -eq 0 ]; then
            echo "(resolved via curl — no DNS tool available to show IP)"
            return 0
        elif [ $exit_code -eq 6 ]; then
            return 1
        fi
        return 0
    fi
}

check_dns() {
    echo ""
    echo "[2/4] Checking DNS resolution for ${MCP_HOST}..."
    log "[2/4] DNS resolution check for ${MCP_HOST}"

    local dns_output
    dns_output=$(resolve_dns "$MCP_HOST" 2>/dev/null)
    if [ $? -ne 0 ] || [ -z "$dns_output" ]; then
        CHECK_DNS="fail"
        log "DNS resolution failed for ${MCP_HOST}."
        fail "DNS resolution failed for ${MCP_HOST}." \
             "Could not resolve ${MCP_HOST}. Check your DNS settings, VPN, or /etc/hosts file."
    fi

    log "DNS resolution result: ${dns_output}"
    CHECK_DNS="pass"
    pass_msg "DNS resolved ${MCP_HOST} successfully."
    echo "      ${dns_output}" | head -3
}

###############################################################################
# 3. SSL CHECK
###############################################################################
check_ssl() {
    echo ""
    echo "[3/4] Checking SSL certificate for ${MCP_HOST}..."
    log "[3/4] SSL check via curl for ${MCP_HOST}"

    local ssl_output
    ssl_output=$(curl -fsS --max-time 10 -o /dev/null \
        --write-out "%{ssl_verify_result}:%{http_code}" \
        "https://${MCP_HOST}" 2>/tmp/pubmatic_ssl_err.txt)
    local curl_exit=$?

    local ssl_verify_result="${ssl_output%%:*}"

    log "curl exit code: ${curl_exit}, ssl_verify_result: ${ssl_verify_result}"

    # curl exit code 60 = SSL certificate problem
    # exit code 35 = SSL connect error
    # ssl_verify_result 0 = OK
    if [ $curl_exit -eq 60 ] || [ $curl_exit -eq 35 ]; then
        local ssl_err
        ssl_err=$(cat /tmp/pubmatic_ssl_err.txt 2>/dev/null)
        log "SSL error detail: ${ssl_err}"
        CHECK_SSL="fail"
        fail "SSL certificate verification failed for ${MCP_HOST}." \
             "curl SSL error (exit ${curl_exit}): ${ssl_err}"
    elif [ $curl_exit -ne 0 ] && [ $curl_exit -ne 22 ]; then
        # exit 22 = HTTP error (server responded, SSL was fine — acceptable here)
        local ssl_err
        ssl_err=$(cat /tmp/pubmatic_ssl_err.txt 2>/dev/null)
        log "curl failed with exit ${curl_exit}: ${ssl_err}"
        # Only warn if it could be SSL-related; network/DNS would have already failed
        warn_msg "curl returned exit code ${curl_exit} during SSL check. SSL status uncertain."
        CHECK_SSL="warn"
        rm -f /tmp/pubmatic_ssl_err.txt
        return
    fi

    rm -f /tmp/pubmatic_ssl_err.txt
    CHECK_SSL="pass"
    pass_msg "SSL certificate for ${MCP_HOST} is valid."
}

###############################################################################
# 4. MCP SERVER HEALTH CHECK
###############################################################################
check_health() {
    echo ""
    echo "[4/4] Checking PubMatic MCP Server health..."
    log "[4/4] Health check: GET ${HEALTH_CHECK_URL}"

    local http_output http_code response_time body_file="/tmp/pm_health_body.txt"
    rm -f "$body_file"

    http_output=$(curl -sS -o "$body_file" -w "%{http_code}:%{time_total}" \
        --max-time 15 \
        -H "Accept: application/json" \
        "$HEALTH_CHECK_URL" 2>/dev/null) || true

    http_code="${http_output%%:*}"
    response_time="${http_output#*:}"

    log "Health check response: HTTP ${http_code}, time ${response_time}s"

    if [ -z "$http_code" ] || [ "$http_code" = "000" ]; then
        CHECK_HEALTH="fail"
        fail "Could not reach PubMatic MCP Server." \
             "curl to ${HEALTH_CHECK_URL} returned no HTTP code. Connection may have timed out."
    fi

    if [ "$http_code" -ge 200 ] 2>/dev/null && [ "$http_code" -lt 300 ] 2>/dev/null; then
        log "Health endpoint returned HTTP ${http_code}."
    else
        CHECK_HEALTH="fail"
        log "Health check returned HTTP ${http_code}."
        fail "PubMatic MCP Server returned HTTP ${http_code}." \
             "Expected 2xx from ${HEALTH_CHECK_URL}, got ${http_code}."
    fi

    if [ -f "$body_file" ]; then
        log "Response body: $(head -c 500 "$body_file" 2>/dev/null)"
        rm -f "$body_file"
    fi

    # Pure-bash float comparison: multiply to integer (strips decimals)
    local rt_int
    rt_int=$(echo "$response_time" | awk -v t="$HEALTH_RESPONSE_THRESHOLD" \
        'BEGIN{} {if ($1+0 > t+0) print "slow"; else print "ok"}')

    if [ "$rt_int" = "slow" ]; then
        CHECK_HEALTH="warn"
        warn_msg "MCP Server is reachable but slow (${response_time}s > ${HEALTH_RESPONSE_THRESHOLD}s threshold)."
    else
        CHECK_HEALTH="pass"
        pass_msg "MCP Server is healthy (HTTP ${http_code}, ${response_time}s)."
    fi
}

###############################################################################
# FINAL SUMMARY
###############################################################################
print_summary() {
    status_for() {
        case "$1" in
            pass) green "pass" ;;
            warn) yellow "warn" ;;
            fail) red "FAIL" ;;
            *)    yellow "----" ;;
        esac
    }

    echo ""
    echo "=========================================="
    echo " PubMatic MCP Server — Sanity Check Summary"
    echo "=========================================="
    printf " [1/4] %-20s %s\n" "Network"    "$(status_for "$CHECK_NETWORK")"
    printf " [2/4] %-20s %s\n" "DNS"        "$(status_for "$CHECK_DNS")"
    printf " [3/4] %-20s %s\n" "SSL"        "$(status_for "$CHECK_SSL")"
    printf " [4/4] %-20s %s\n" "MCP Health" "$(status_for "$CHECK_HEALTH")"
    echo "=========================================="
    echo ""
    echo " Log file: ${LOG_FILE}"
    echo ""

    if [ "$CHECK_NETWORK" = "fail" ] || [ "$CHECK_DNS" = "fail" ] || \
       [ "$CHECK_SSL" = "fail" ] || [ "$CHECK_HEALTH" = "fail" ]; then
        echo " One or more checks failed."
        echo " Please share the log file above with PubMatic support."
        exit 1
    fi

    if [ "$CHECK_SSL" = "warn" ] || [ "$CHECK_HEALTH" = "warn" ]; then
        echo " Some checks have warnings. The MCP server may not work correctly."
        echo " Consider resolving the warnings and re-running this script."
        exit 0
    fi

    echo -e " $(green '✔') All checks passed. Claude Desktop is ready to use"
    echo "   the PubMatic MCP Server."
}

###############################################################################
# MAIN EXECUTION
###############################################################################
check_network
check_dns
check_ssl
check_health
print_summary
