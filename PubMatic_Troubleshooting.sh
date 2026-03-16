#!/bin/bash
# PubMatic MCP Server — Troubleshooting & Setup Script
# Runs 7 ordered checks: self-upgrade, network, DNS, platform, Python, SSL, MCP health.
# Hard dependencies: bash (v3.2+), curl. Everything else is checked before use.

SCRIPT_VERSION="1.0.0"

# ─── CONSTANTS ─────────────────────────────────────────────────────────────────
MIN_VERSION="3.8"
MAX_VERSION="3.13.99"
PYTHON_PKG_VERSION="3.12.9"
MCP_HOST="mcp.pubmatic.com"
HEALTH_CHECK_URL="https://apps.pubmatic.com/mcpserver/health"
HEALTH_RESPONSE_THRESHOLD=5
RELEASES_URL="https://api.github.com/repos/PubMatic/pubmatic-mcp-server/releases/latest"

# ─── ARGUMENT PARSING ──────────────────────────────────────────────────────────
AUTO_YES=false
for arg in "$@"; do
    case "$arg" in
        --yes|-y) AUTO_YES=true ;;
    esac
done

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
CHECK_UPGRADE="pending"
CHECK_NETWORK="pending"
CHECK_DNS="pending"
CHECK_PLATFORM="pending"
CHECK_PYTHON="pending"
CHECK_SSL="pending"
CHECK_HEALTH="pending"

DETECTED_OS=""
DETECTED_ARCH=""
DETECTED_DISTRO="unknown"
PYTHON_CMD=""
PYTHON_MINOR=""

# ─── HELPER FUNCTIONS ─────────────────────────────────────────────────────────
has_cmd() { command -v "$1" &>/dev/null; }

require_cmd() {
    if ! has_cmd "$1"; then
        fail "$2" "$1 is not installed and is required."
    fi
}

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

version_in_range() {
    local version=$1 min=$2 max=$3
    if [[ "$(printf '%s\n' "$min" "$version" | sort -V | head -n1)" == "$min" ]] && \
       [[ "$(printf '%s\n' "$version" "$max" | sort -V | head -n1)" == "$version" ]]; then
        return 0
    fi
    return 1
}

confirm_prompt() {
    local prompt_text="$1"
    if [ "$AUTO_YES" = true ]; then
        echo "  (Auto-accepted via --yes flag)"
        log "Auto-accepted prompt: $prompt_text"
        return 0
    fi
    printf "  %s [y/N] (default: No): " "$prompt_text"
    local answer
    read -r answer
    case "$answer" in
        [yY]|[yY][eE][sS]) return 0 ;;
        *) return 1 ;;
    esac
}

display_and_run_steps() {
    local steps_var="$1[@]"
    local steps=("${!steps_var}")
    local step_num=0 total=${#steps[@]}

    echo ""
    echo "  The following steps will be executed on your system:"
    echo ""
    for entry in "${steps[@]}"; do
        step_num=$((step_num + 1))
        local cmd="${entry%%|*}"
        local desc="${entry#*|}"
        echo "    Step ${step_num}: ${cmd}"
        echo "            (${desc})"
        echo ""
    done
    echo "  ============================================================"

    if ! confirm_prompt "This modifies your system. Proceed?"; then
        return 1
    fi

    step_num=0
    for entry in "${steps[@]}"; do
        step_num=$((step_num + 1))
        local cmd="${entry%%|*}"
        local desc="${entry#*|}"
        echo "    [${step_num}/${total}] ${desc}..."
        log "Executing step ${step_num}/${total}: ${cmd}"
        if ! eval "$cmd" >> "$LOG_FILE" 2>&1; then
            log "Step ${step_num} failed: ${cmd}"
            echo -e "    $(red '✘') Step ${step_num} failed: ${desc}"
            return 2
        fi
        log "Step ${step_num} completed successfully."
    done
    return 0
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

require_cmd "curl" "curl is required but not found. Please install curl and re-run this script."

###############################################################################
# 1. SELF-UPGRADE CHECK
###############################################################################
check_upgrade() {
    echo "[1/7] Checking for script updates..."
    log "[1/7] Self-upgrade check"

    local latest_raw latest
    latest_raw=$(curl -fsSL --max-time 10 "$RELEASES_URL" 2>/dev/null) || {
        log "Could not reach GitHub releases API. Skipping upgrade check."
        echo "      (Skipped — could not reach GitHub)"
        CHECK_UPGRADE="skip"
        return
    }

    latest=$(echo "$latest_raw" | grep '"tag_name"' | sed 's/.*"v\?\([^"]*\)".*/\1/')
    if [ -z "$latest" ]; then
        log "Could not parse latest version from GitHub response."
        CHECK_UPGRADE="skip"
        echo "      (Skipped — could not parse version)"
        return
    fi

    log "Current version: ${SCRIPT_VERSION}, Latest version: ${latest}"

    local newer
    newer=$(printf '%s\n' "$SCRIPT_VERSION" "$latest" | sort -V | tail -n1)
    if [ "$newer" = "$SCRIPT_VERSION" ] || [ "$latest" = "$SCRIPT_VERSION" ]; then
        pass_msg "Script is up to date (v${SCRIPT_VERSION})."
        CHECK_UPGRADE="pass"
        return
    fi

    echo "      New version available: v${latest} (current: v${SCRIPT_VERSION})"

    local download_url
    download_url=$(echo "$latest_raw" | grep '"browser_download_url"' | grep -i 'troubleshooting' | sed 's/.*"\(https[^"]*\)".*/\1/' | head -1)
    if [ -z "$download_url" ]; then
        warn_msg "Could not find download URL for the new version. Please update manually."
        CHECK_UPGRADE="skip"
        return
    fi

    if confirm_prompt "Download and apply update to v${latest}?"; then
        local tmp_script="/tmp/pubmatic_troubleshooting_update.sh"
        if curl -fsSL --max-time 30 "$download_url" -o "$tmp_script" 2>/dev/null; then
            cp "$tmp_script" "$0"
            chmod +x "$0"
            rm -f "$tmp_script"
            log "Updated to v${latest}. Re-executing."
            echo "      Updated to v${latest}. Restarting..."
            exec "$0" "$@"
        else
            warn_msg "Download failed. Continuing with current version."
            CHECK_UPGRADE="skip"
        fi
    else
        echo "      Skipped update. Continuing with v${SCRIPT_VERSION}."
        CHECK_UPGRADE="pass"
    fi
}

###############################################################################
# 2. NETWORK CHECK
###############################################################################
check_network() {
    echo ""
    echo "[2/7] Checking network connectivity..."
    log "[2/7] Network connectivity check"

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
# 3. DNS CHECK
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
    echo "[3/7] Checking DNS resolution for ${MCP_HOST}..."
    log "[3/7] DNS resolution check for ${MCP_HOST}"

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
# 4. OS AND ARCH DETECTION
###############################################################################
detect_platform() {
    echo ""
    echo "[4/7] Detecting platform..."
    log "[4/7] Platform detection"

    DETECTED_OS=$(uname -s 2>/dev/null)
    DETECTED_ARCH=$(uname -m 2>/dev/null)

    case "$DETECTED_OS" in
        Darwin) DETECTED_OS="Darwin" ;;
        Linux)  DETECTED_OS="Linux" ;;
        *)
            CHECK_PLATFORM="fail"
            fail "Unsupported operating system: ${DETECTED_OS}." \
                 "This script supports macOS and Linux. For Windows, use the separate Windows troubleshooting script."
            ;;
    esac

    case "$DETECTED_ARCH" in
        x86_64|amd64) DETECTED_ARCH="x86_64" ;;
        arm64|aarch64) DETECTED_ARCH="arm64" ;;
        *)
            log "Uncommon architecture detected: ${DETECTED_ARCH}. Continuing."
            ;;
    esac

    if [ "$DETECTED_OS" = "Linux" ] && [ -f /etc/os-release ]; then
        . /etc/os-release
        DETECTED_DISTRO="${ID:-unknown}"
        log "Linux distro detected: ${DETECTED_DISTRO} (${PRETTY_NAME:-unknown})"
    fi

    local platform_label
    if [ "$DETECTED_OS" = "Darwin" ]; then
        platform_label="macOS ${DETECTED_ARCH}"
    else
        platform_label="Linux ${DETECTED_ARCH} (${DETECTED_DISTRO})"
    fi

    CHECK_PLATFORM="pass"
    pass_msg "Detected: ${platform_label}"
    log "Platform: OS=${DETECTED_OS}, Arch=${DETECTED_ARCH}, Distro=${DETECTED_DISTRO}"
}

###############################################################################
# 5. PYTHON CHECK AND INSTALL
###############################################################################
find_python() {
    if has_cmd python3; then
        PYTHON_CMD="python3"
    elif has_cmd python; then
        local py_major
        py_major=$(python --version 2>&1 | grep -oE '[0-9]+' | head -1)
        if [ "$py_major" = "3" ]; then
            PYTHON_CMD="python"
        fi
    fi
}

build_python_install_steps() {
    INSTALL_STEPS=()
    if [ "$DETECTED_OS" = "Darwin" ]; then
        local pkg_file="python-${PYTHON_PKG_VERSION}-macos11.pkg"
        local pkg_url="https://www.python.org/ftp/python/${PYTHON_PKG_VERSION}/${pkg_file}"
        local installed_bin="/Library/Frameworks/Python.framework/Versions/3.12/bin/python3.12"
        INSTALL_STEPS+=(
            "curl -fsSL ${pkg_url} -o /tmp/${pkg_file}|Download Python ${PYTHON_PKG_VERSION} installer from python.org"
            "sudo installer -pkg /tmp/${pkg_file} -target /|Install Python ${PYTHON_PKG_VERSION} system-wide (requires admin password)"
            "sudo ln -sf ${installed_bin} /usr/local/bin/python3|Symlink python3 so the MCP manifest can find it"
            "rm -f /tmp/${pkg_file}|Clean up downloaded installer"
        )
    elif [ "$DETECTED_OS" = "Linux" ]; then
        if has_cmd apt-get; then
            INSTALL_STEPS+=(
                "sudo apt-get update|Refresh package lists"
                "sudo apt-get install -y software-properties-common|Install prerequisite for adding PPAs"
                "sudo add-apt-repository -y ppa:deadsnakes/ppa|Add deadsnakes PPA for Python 3.12"
                "sudo apt-get update|Refresh package lists with new PPA"
                "sudo apt-get install -y python3.12|Install Python 3.12"
                "sudo ln -sf /usr/bin/python3.12 /usr/local/bin/python3|Symlink python3 if needed"
            )
        elif has_cmd dnf; then
            INSTALL_STEPS+=("sudo dnf install -y python3.12|Install Python 3.12 via dnf")
        elif has_cmd yum; then
            INSTALL_STEPS+=("sudo yum install -y python3|Install Python 3 via yum")
        elif has_cmd apk; then
            INSTALL_STEPS+=("sudo apk add python3|Install Python 3 via apk")
        elif has_cmd pacman; then
            INSTALL_STEPS+=("sudo pacman -Sy --noconfirm python|Install Python 3 via pacman")
        else
            return 1
        fi
    fi
}

show_python_install_plan() {
    local situation="$1"
    echo ""
    echo "  ============================================================"
    echo -e "  $(yellow '⚠')  WARNING: Python installation required"
    echo "  ============================================================"
    echo ""
    echo "  Current situation:"
    echo "    - ${situation}"
    echo "    - The PubMatic MCP Server requires Python 3.8 or higher (up to 3.13.x)"
    echo ""

    build_python_install_steps
    if [ $? -ne 0 ] || [ ${#INSTALL_STEPS[@]} -eq 0 ]; then
        echo "  No supported package manager found on this system."
        echo "  Please install Python 3.8+ manually and re-run this script."
        echo "  Visit: https://www.python.org/downloads/"
        CHECK_PYTHON="fail"
        return 1
    fi

    local result
    display_and_run_steps INSTALL_STEPS
    result=$?
    if [ $result -eq 1 ]; then
        echo ""
        echo "  Installation skipped."
        echo "  Please install Python 3.8+ manually and re-run this script."
        echo "  Visit: https://www.python.org/downloads/"
        CHECK_PYTHON="fail"
        return 1
    elif [ $result -eq 2 ]; then
        CHECK_PYTHON="fail"
        fail "Python installation failed." "One of the install steps exited non-zero. See log for details."
    fi
    return 0
}

check_python() {
    echo ""
    echo "[5/7] Checking Python installation..."
    log "[5/7] Python check"

    find_python

    if [ -n "$PYTHON_CMD" ]; then
        local current_version
        current_version=$($PYTHON_CMD --version 2>&1 | awk '{print $2}')
        local current_bin
        current_bin=$(command -v "$PYTHON_CMD")
        log "Found ${PYTHON_CMD} at ${current_bin} — version ${current_version}"

        if version_in_range "$current_version" "$MIN_VERSION" "$MAX_VERSION"; then
            PYTHON_MINOR=$(echo "$current_version" | cut -d. -f1-2)
            CHECK_PYTHON="pass"
            pass_msg "Python ${current_version} is installed (${current_bin})."
            return
        fi

        echo "      Python ${current_version} found but outside supported range (${MIN_VERSION}–3.13.x)."
        log "Python ${current_version} is outside supported range."

        show_python_install_plan "Python ${current_version} is outside the supported range (${MIN_VERSION}–3.13.x)"
        [ $? -ne 0 ] && return
    else
        echo "      Python 3 not found on this system."
        log "python3 command not found in PATH."

        show_python_install_plan "Python 3 is not installed"
        [ $? -ne 0 ] && return
    fi

    # Post-install verification
    PYTHON_CMD=""
    find_python
    if [ -z "$PYTHON_CMD" ]; then
        CHECK_PYTHON="fail"
        fail "Python could not be found after installation." \
             "python3 is not in PATH. You may need to restart your terminal or add it to PATH manually."
    fi

    local new_version
    new_version=$($PYTHON_CMD --version 2>&1 | awk '{print $2}')
    log "Post-install verification: ${PYTHON_CMD} version ${new_version}"

    if version_in_range "$new_version" "$MIN_VERSION" "$MAX_VERSION"; then
        PYTHON_MINOR=$(echo "$new_version" | cut -d. -f1-2)
        CHECK_PYTHON="pass"
        pass_msg "Python ${new_version} installed and verified."
    else
        CHECK_PYTHON="fail"
        fail "Installed Python ${new_version} is still outside the supported range." \
             "Expected ${MIN_VERSION}–${MAX_VERSION}, got ${new_version}."
    fi
}

###############################################################################
# 6. SSL / CERTIFICATE CHECK
###############################################################################
test_ssl_handshake() {
    $PYTHON_CMD -c "
import ssl, socket
try:
    ctx = ssl.create_default_context()
    with ctx.wrap_socket(socket.socket(), server_hostname='${MCP_HOST}') as s:
        s.connect(('${MCP_HOST}', 443))
    print('ok')
except Exception as e:
    print('fail:' + str(e))
" 2>&1
}

build_ssl_fix_steps() {
    SSL_STEPS=()

    if [ "$DETECTED_OS" = "Linux" ]; then
        if has_cmd apt-get; then
            SSL_STEPS+=(
                "sudo apt-get install -y ca-certificates|Install/update OS CA certificates"
                "sudo update-ca-certificates|Rebuild system certificate store"
            )
        elif has_cmd dnf; then
            SSL_STEPS+=(
                "sudo dnf install -y ca-certificates|Install/update OS CA certificates"
                "sudo update-ca-trust|Rebuild system certificate store"
            )
        elif has_cmd yum; then
            SSL_STEPS+=(
                "sudo yum install -y ca-certificates|Install/update OS CA certificates"
                "sudo update-ca-trust|Rebuild system certificate store"
            )
        fi
    fi

    if ! $PYTHON_CMD -m pip --version &>/dev/null; then
        SSL_STEPS+=("$PYTHON_CMD -m ensurepip --upgrade|Bootstrap pip (not currently installed)")
    fi

    local pip_flags=""
    if [ "$DETECTED_OS" = "Darwin" ]; then
        pip_flags="--break-system-packages"
    elif [ "$DETECTED_OS" = "Linux" ]; then
        if [ -f "$($PYTHON_CMD -c 'import sysconfig; import os; print(os.path.join(os.path.dirname(sysconfig.get_path("stdlib")), "EXTERNALLY-MANAGED"))' 2>/dev/null)" ] 2>/dev/null; then
            pip_flags="--break-system-packages"
        fi
    fi
    SSL_STEPS+=("sudo $PYTHON_CMD -m pip install --upgrade certifi ${pip_flags}|Install/update the certifi CA bundle for Python")

    if [ "$DETECTED_OS" = "Darwin" ]; then
        local cert_cmd="/Applications/Python ${PYTHON_MINOR}/Install Certificates.command"
        if [ -f "$cert_cmd" ]; then
            SSL_STEPS+=("bash \"${cert_cmd}\"|Run Apple's certificate installer for Python ${PYTHON_MINOR}")
        fi
    fi
}

show_ssl_fix_plan() {
    local error_detail="$1"
    echo ""
    echo "  ============================================================"
    echo -e "  $(yellow '⚠')  WARNING: SSL certificate update required"
    echo "  ============================================================"
    echo ""
    echo "  Current situation:"
    echo "    - SSL handshake to ${MCP_HOST} failed"
    echo "    - Error: ${error_detail}"
    echo ""

    build_ssl_fix_steps
    if [ ${#SSL_STEPS[@]} -eq 0 ]; then
        echo "  Could not determine certificate fix steps for this platform."
        echo "  Please configure SSL certificates manually."
        CHECK_SSL="warn"
        return 1
    fi

    local result
    display_and_run_steps SSL_STEPS
    result=$?
    if [ $result -eq 1 ]; then
        echo ""
        echo "  SSL certificate fix skipped."
        echo "  The MCP server may not work correctly without proper SSL certificates."
        CHECK_SSL="warn"
        return 1
    elif [ $result -eq 2 ]; then
        log "SSL fix step failed. See log for details."
        echo -e "  $(red '✘') An SSL fix step failed. The MCP server may not work correctly."
        CHECK_SSL="warn"
        return 1
    fi
    return 0
}

check_ssl() {
    echo ""
    echo "[6/7] Checking SSL certificates..."
    log "[6/7] SSL certificate check"

    local ssl_result
    ssl_result=$(test_ssl_handshake)

    if echo "$ssl_result" | grep -q "^ok$"; then
        CHECK_SSL="pass"
        pass_msg "SSL handshake to ${MCP_HOST} succeeded."
        return
    fi

    local error_detail="${ssl_result#fail:}"
    log "SSL handshake failed: ${error_detail}"
    echo "      SSL handshake to ${MCP_HOST} failed."

    show_ssl_fix_plan "$error_detail"
    if [ $? -ne 0 ]; then
        return
    fi

    # Verify after fix
    ssl_result=$(test_ssl_handshake)
    if echo "$ssl_result" | grep -q "^ok$"; then
        CHECK_SSL="pass"
        pass_msg "SSL certificates configured successfully."
    else
        local post_error="${ssl_result#fail:}"
        log "SSL still failing after fix: ${post_error}"
        warn_msg "SSL fix was applied but handshake still fails: ${post_error}"
        CHECK_SSL="warn"
    fi
}

###############################################################################
# 7. MCP SERVER HEALTH CHECK
###############################################################################
check_health() {
    echo ""
    echo "[7/7] Checking PubMatic MCP Server health..."
    log "[7/7] Health check: GET ${HEALTH_CHECK_URL}"

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

    # Parse response body with Python if available, otherwise just use HTTP status
    local server_status="unknown"
    if [ -n "$PYTHON_CMD" ] && [ -f "$body_file" ]; then
        server_status=$($PYTHON_CMD -c "
import json, sys
try:
    d = json.load(open('${body_file}'))
    print(d.get('status', 'unknown'))
except:
    print('unknown')
" 2>/dev/null || echo "unknown")
        log "Parsed server status: ${server_status}"
    fi

    if [ -f "$body_file" ]; then
        log "Response body: $(cat "$body_file" 2>/dev/null | head -c 500)"
        rm -f "$body_file"
    fi

    # Check response time threshold
    local is_slow="no"
    if has_cmd "$PYTHON_CMD" 2>/dev/null; then
        is_slow=$($PYTHON_CMD -c "print('yes' if float('${response_time}') > ${HEALTH_RESPONSE_THRESHOLD} else 'no')" 2>/dev/null || echo "no")
    fi

    if [ "$is_slow" = "yes" ]; then
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
    local status_icon
    status_for() {
        case "$1" in
            pass) green "pass" ;;
            warn) yellow "warn" ;;
            fail) red "FAIL" ;;
            skip) yellow "skip" ;;
            *)    yellow "----" ;;
        esac
    }

    echo ""
    echo "=========================================="
    echo " PubMatic MCP Server — Sanity Check Summary"
    echo "=========================================="

    local platform_info=""
    if [ "$DETECTED_OS" = "Darwin" ]; then
        platform_info="macOS ${DETECTED_ARCH}"
    elif [ -n "$DETECTED_OS" ]; then
        platform_info="Linux ${DETECTED_ARCH}"
    fi

    local python_info=""
    if [ -n "$PYTHON_CMD" ]; then
        python_info=$($PYTHON_CMD --version 2>&1 | awk '{print $2}' 2>/dev/null)
    fi

    printf " [1/7] %-20s %s\n" "Self-Upgrade" "$(status_for "$CHECK_UPGRADE")"
    printf " [2/7] %-20s %s\n" "Network" "$(status_for "$CHECK_NETWORK")"
    printf " [3/7] %-20s %s\n" "DNS" "$(status_for "$CHECK_DNS")"
    printf " [4/7] %-20s %s  %s\n" "Platform" "$(status_for "$CHECK_PLATFORM")" "(${platform_info})"
    printf " [5/7] %-20s %s  %s\n" "Python" "$(status_for "$CHECK_PYTHON")" "(${python_info})"
    printf " [6/7] %-20s %s\n" "SSL Certificates" "$(status_for "$CHECK_SSL")"
    printf " [7/7] %-20s %s\n" "MCP Health" "$(status_for "$CHECK_HEALTH")"

    echo "=========================================="
    echo ""
    echo " Log file: ${LOG_FILE}"
    echo ""

    if [ "$CHECK_NETWORK" = "fail" ] || [ "$CHECK_DNS" = "fail" ] || \
       [ "$CHECK_PLATFORM" = "fail" ] || [ "$CHECK_PYTHON" = "fail" ] || \
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
check_upgrade
check_network
check_dns
detect_platform
check_python
check_ssl
check_health
print_summary
