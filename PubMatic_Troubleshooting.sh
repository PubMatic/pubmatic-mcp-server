#!/bin/bash

set -e

MIN_VERSION="3.8"
MAX_VERSION="3.13.99"

echo "----------------------------------------"
echo " PubMatic MCP Server - Setup Check"
echo " Python + SSL Fix for Claude Desktop"
echo "----------------------------------------"

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

# Check if python3 exists
CURRENT_VERSION=""
if command -v python3 &> /dev/null
then
    CURRENT_VERSION=$(python3 --version | awk '{print $2}')
    echo "Found Python: $CURRENT_VERSION"

    if version_in_range "$CURRENT_VERSION" "$MIN_VERSION" "$MAX_VERSION"; then
        echo "✅ Python is already in the supported range (3.8 - 3.13.x)."
        echo "Going ahead to certificate setup."
        SKIP_INSTALL=true
    else
        echo "⚠️ Python version is outside the supported range."
        echo "Installing/updating to supported Python 3.12..."
        SKIP_INSTALL=false
    fi
else
    echo "⚠️ Python 3 is not installed on this machine."
    echo "Installing supported Python 3.12 first."
    SKIP_INSTALL=false
fi

# ─── INSTALL PYTHON IF NEEDED ─────────────────────────────────────────────────
if [ "$SKIP_INSTALL" = false ]; then

    # Install Homebrew if not present
    if ! command -v brew &> /dev/null
    then
        echo "Required package manager is missing. Installing Homebrew..."
        if ! /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
        then
            echo "❌ Could not install Homebrew."
            echo "Please reach out to Pubmatic support."
            exit 1
        fi

        if [[ -d "/opt/homebrew/bin" ]]; then
            eval "$(/opt/homebrew/bin/brew shellenv)"
        fi
    fi

    echo "Updating package manager metadata..."
    brew update || echo "⚠️ Some package manager metadata could not be refreshed. Continuing with setup."

    echo "Installing Python 3.12..."
    if ! brew install python@3.12
    then
        echo "❌ Could not install Python 3.12."
        echo "Please reach out to Pubmatic support."
        exit 1
    fi

    echo "Linking Python 3.12..."
    if ! brew link --overwrite --force python@3.12
    then
        echo "❌ Could not complete Python setup."
        echo "Please reach out to Pubmatic support."
        exit 1
    fi

    # Final verification
    if command -v python3.12 &> /dev/null
    then
        echo "✅ Python 3.12 is installed."
        python3.12 --version
        CURRENT_VERSION=$(python3.12 --version | awk '{print $2}')
    else
        echo "❌ Could not verify Python 3.12 installation."
        echo "Please reach out to Pubmatic support."
        exit 1
    fi

fi

# ─── STEP 1: DETECT ACTUAL PYTHON BINARY PATH ────────────────────────────────
echo ""
echo "----------------------------------------"
echo "Finding the Python executable to use..."
echo "----------------------------------------"

# Derive minor version from the validated CURRENT_VERSION (e.g. 3.13.7 → 3.13)
PYTHON_MINOR=$(echo "$CURRENT_VERSION" | cut -d. -f1-2)
ACTUAL_PYTHON_BIN=""

# Look for the exact versioned binary matching the validated version.
# This avoids picking up a different Python that Homebrew may have relinked
# as the default (e.g. 3.14 getting linked after a brew upgrade).
for candidate in \
    "/opt/homebrew/opt/python@${PYTHON_MINOR}/bin/python${PYTHON_MINOR}" \
    "/usr/local/opt/python@${PYTHON_MINOR}/bin/python${PYTHON_MINOR}" \
    "/Library/Frameworks/Python.framework/Versions/${PYTHON_MINOR}/bin/python3"; do
    if [[ -x "$candidate" ]]; then
        ACTUAL_PYTHON_BIN="$candidate"
        break
    fi
done

# Fallback: resolve from sys.executable only if no versioned binary found
if [[ -z "$ACTUAL_PYTHON_BIN" ]]; then
    ACTUAL_PYTHON_BIN=$(python3 -c "import sys; print(sys.executable)")
fi

if [ -z "$ACTUAL_PYTHON_BIN" ]; then
    echo "❌ Could not detect Python binary path."
    echo "Please reach out to Pubmatic support."
    exit 1
fi

echo "✅ Python executable selected for this setup."

# ─── STEP 2: ENSURE /usr/local/bin EXISTS ────────────────────────────────────
# On Apple Silicon Macs (M1/M2/M3), /usr/local/bin may not exist by default
# since Homebrew installs to /opt/homebrew instead.
if [ ! -d /usr/local/bin ]; then
    echo "Preparing system path for setup helper..."
    sudo mkdir -p /usr/local/bin
    echo "✅ Ready."
fi

# ─── STEP 3: BACK UP EXISTING python3 SYMLINK ────────────────────────────────
echo ""
echo "----------------------------------------"
echo "Backing up your current python3 command..."
echo "----------------------------------------"

if [ -f /usr/local/bin/python3 ] || [ -L /usr/local/bin/python3 ]; then
    # Remove any previous backup before overwriting to avoid mv collision on re-runs
    sudo rm -f /usr/local/bin/python3.symlink.bak
    sudo mv /usr/local/bin/python3 /usr/local/bin/python3.symlink.bak
    echo "✅ Existing command backed up."
else
    echo "ℹ️ No previous override to back up."
fi

# ─── STEP 4: CREATE SSL WRAPPER SCRIPT ───────────────────────────────────────
echo ""
echo "----------------------------------------"
echo "Creating SSL-safe Python launcher..."
echo "----------------------------------------"

sudo tee /usr/local/bin/python3 > /dev/null <<SH
#!/bin/sh
export SSL_CERT_FILE="/private/etc/ssl/cert.pem"
export REQUESTS_CA_BUNDLE="/private/etc/ssl/cert.pem"
exec "$ACTUAL_PYTHON_BIN" "\$@"
SH

echo "✅ SSL-safe Python launcher created."

# ─── STEP 5: MAKE WRAPPER EXECUTABLE ─────────────────────────────────────────
echo ""
echo "----------------------------------------"
echo "Enabling the new Python launcher..."
echo "----------------------------------------"

sudo chmod +x /usr/local/bin/python3
echo "✅ Wrapper script is now executable."

# ─── STEP 6: VERIFY WRAPPER IS WORKING ───────────────────────────────────────
echo ""
echo "----------------------------------------"
echo "Checking SSL settings..."
echo "----------------------------------------"

VERIFY_OUTPUT=$(/usr/local/bin/python3 -c "import os,sys; print(sys.executable); print('SSL_CERT_FILE=', os.environ.get('SSL_CERT_FILE'))")

if echo "$VERIFY_OUTPUT" | grep -q "SSL_CERT_FILE= /private/etc/ssl/cert.pem"; then
    echo "✅ SSL certificate path is now forced for Python."
else
    echo "⚠️ SSL certificate path did not apply as expected. Please verify manually."
fi

# ─── STEP 7: UPGRADE CERTIFI AND FIX CERTIFICATES ───────────────────────────
echo ""
echo "----------------------------------------"
echo "Updating trusted certificate package..."
echo "----------------------------------------"

# Ensure pip is available
if ! /usr/local/bin/python3 -m pip --version &> /dev/null; then
    echo "Python package manager missing. Adding pip..."
    /usr/local/bin/python3 -m ensurepip --upgrade || true
fi

echo "Updating certificate bundle..."
if ! /usr/local/bin/python3 -m pip install --upgrade certifi --break-system-packages --ignore-installed
then
    echo "❌ Failed to update certificate package."
    echo "Please reach out to Pubmatic support."
    exit 1
fi
echo "✅ Certificate package updated."

# Run Apple's official certificate installer if available — path matches installed Python version
CERT_INSTALLER="/Applications/Python ${PYTHON_MINOR}/Install Certificates.command"
if [ -f "$CERT_INSTALLER" ]; then
    echo "Running additional macOS certificate installer for Python ${PYTHON_MINOR}..."
    open "$CERT_INSTALLER"
    echo "✅ Certificate installer started."
else
    echo "ℹ️  No extra macOS certificate installer found for Python ${PYTHON_MINOR}."
fi

# ─── STEP 8: FINAL SSL VERIFICATION ──────────────────────────────────────────
echo ""
echo "----------------------------------------"
echo "Final verification of internet certificate setup..."
echo "----------------------------------------"

SSL_CHECK=$(/usr/local/bin/python3 -c "import ssl; import certifi; print(certifi.where())" 2>&1)

if echo "$SSL_CHECK" | grep -q ".pem"; then
    echo "✅ SSL setup is working. Python can use trusted certificates."
else
    echo "❌ SSL verification failed."
    echo "Please share this output with Pubmatic support: $SSL_CHECK"
    exit 1
fi

echo ""
echo "----------------------------------------"
echo "✅ Process completed successfully."
echo "----------------------------------------"
