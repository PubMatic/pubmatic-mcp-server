#!/bin/bash

set -e

MIN_VERSION="3.8"
MAX_VERSION="3.13.99"

echo "----------------------------------------"
echo " PubMatic MCP Server - Environment Setup"
echo " Python & SSL Certificate Troubleshooter"
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
    echo "Detected Python version: $CURRENT_VERSION"

    if version_in_range "$CURRENT_VERSION" "$MIN_VERSION" "$MAX_VERSION"; then
        echo "✅ Python version is between 3.8 and 3.13.x. No installation required."
        echo "Proceeding to SSL certificate setup..."
        SKIP_INSTALL=true
    else
        echo "⚠️ Python version is outside the required range."
        echo "Proceeding with Python 3.12 installation/update..."
        SKIP_INSTALL=false
    fi
else
    echo "⚠️ Python3 is not installed."
    echo "Proceeding with Python 3.12 installation..."
    SKIP_INSTALL=false
fi

# ─── INSTALL PYTHON IF NEEDED ─────────────────────────────────────────────────
if [ "$SKIP_INSTALL" = false ]; then

    # Install Homebrew if not present
    if ! command -v brew &> /dev/null
    then
        echo "Homebrew not found. Installing Homebrew..."
        if ! /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
        then
            echo "❌ Homebrew installation failed."
            echo "Reach out to Pubmatic for troubleshooting the issue."
            exit 1
        fi

        if [[ -d "/opt/homebrew/bin" ]]; then
            eval "$(/opt/homebrew/bin/brew shellenv)"
        fi
    fi

    echo "Updating Homebrew..."
    brew update || echo "⚠️  brew update encountered warnings (possibly unrelated cask issues). Continuing..."

    echo "Installing Python 3.12..."
    if ! brew install python@3.12
    then
        echo "❌ Python installation failed."
        echo "Reach out to Pubmatic for troubleshooting the issue."
        exit 1
    fi

    echo "Linking Python 3.12..."
    if ! brew link --overwrite --force python@3.12
    then
        echo "❌ Python linking failed."
        echo "Reach out to Pubmatic for troubleshooting the issue."
        exit 1
    fi

    # Final verification
    if command -v python3.12 &> /dev/null
    then
        echo "✅ Python 3.12 installed successfully."
        python3.12 --version
        CURRENT_VERSION=$(python3.12 --version | awk '{print $2}')
    else
        echo "❌ Python 3.12 installation verification failed."
        echo "Reach out to Pubmatic for troubleshooting the issue."
        exit 1
    fi

fi

# ─── STEP 1: DETECT ACTUAL PYTHON BINARY PATH ────────────────────────────────
echo ""
echo "----------------------------------------"
echo "Detecting Python binary path..."
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
    echo "Reach out to Pubmatic for troubleshooting the issue."
    exit 1
fi

echo "✅ Detected Python binary: $ACTUAL_PYTHON_BIN"

# ─── STEP 2: ENSURE /usr/local/bin EXISTS ────────────────────────────────────
# On Apple Silicon Macs (M1/M2/M3), /usr/local/bin may not exist by default
# since Homebrew installs to /opt/homebrew instead.
if [ ! -d /usr/local/bin ]; then
    echo "Creating /usr/local/bin directory..."
    sudo mkdir -p /usr/local/bin
    echo "✅ /usr/local/bin created."
fi

# ─── STEP 3: BACK UP EXISTING python3 SYMLINK ────────────────────────────────
echo ""
echo "----------------------------------------"
echo "Backing up existing python3 symlink..."
echo "----------------------------------------"

if [ -f /usr/local/bin/python3 ] || [ -L /usr/local/bin/python3 ]; then
    # Remove any previous backup before overwriting to avoid mv collision on re-runs
    sudo rm -f /usr/local/bin/python3.symlink.bak
    sudo mv /usr/local/bin/python3 /usr/local/bin/python3.symlink.bak
    echo "✅ Backed up to /usr/local/bin/python3.symlink.bak"
else
    echo "ℹ️  No existing /usr/local/bin/python3 found. Skipping backup."
fi

# ─── STEP 4: CREATE SSL WRAPPER SCRIPT ───────────────────────────────────────
echo ""
echo "----------------------------------------"
echo "Creating python3 SSL wrapper script..."
echo "----------------------------------------"

sudo tee /usr/local/bin/python3 > /dev/null <<SH
#!/bin/sh
export SSL_CERT_FILE="/private/etc/ssl/cert.pem"
export REQUESTS_CA_BUNDLE="/private/etc/ssl/cert.pem"
exec "$ACTUAL_PYTHON_BIN" "\$@"
SH

echo "✅ Wrapper script created at /usr/local/bin/python3"

# ─── STEP 5: MAKE WRAPPER EXECUTABLE ─────────────────────────────────────────
echo ""
echo "----------------------------------------"
echo "Making wrapper executable..."
echo "----------------------------------------"

sudo chmod +x /usr/local/bin/python3
echo "✅ Wrapper script is now executable."

# ─── STEP 6: VERIFY WRAPPER IS WORKING ───────────────────────────────────────
echo ""
echo "----------------------------------------"
echo "Verifying SSL wrapper..."
echo "----------------------------------------"

VERIFY_OUTPUT=$(/usr/local/bin/python3 -c "import os,sys; print(sys.executable); print('SSL_CERT_FILE=', os.environ.get('SSL_CERT_FILE'))")
echo "$VERIFY_OUTPUT"

if echo "$VERIFY_OUTPUT" | grep -q "SSL_CERT_FILE= /private/etc/ssl/cert.pem"; then
    echo "✅ SSL environment variable is correctly set via wrapper."
else
    echo "⚠️  SSL_CERT_FILE not detected in wrapper output. Please verify manually."
fi

# ─── STEP 7: UPGRADE CERTIFI AND FIX CERTIFICATES ───────────────────────────
echo ""
echo "----------------------------------------"
echo "Upgrading certifi and fixing SSL certificates..."
echo "----------------------------------------"

# Ensure pip is available
if ! /usr/local/bin/python3 -m pip --version &> /dev/null; then
    echo "pip not found. Installing pip..."
    /usr/local/bin/python3 -m ensurepip --upgrade || true
fi

echo "Upgrading certifi..."
if ! /usr/local/bin/python3 -m pip install --upgrade certifi --break-system-packages --ignore-installed
then
    echo "❌ certifi upgrade failed."
    echo "Reach out to Pubmatic for troubleshooting the issue."
    exit 1
fi
echo "✅ certifi upgraded successfully."

# Run Apple's official certificate installer if available — path matches installed Python version
CERT_INSTALLER="/Applications/Python ${PYTHON_MINOR}/Install Certificates.command"
if [ -f "$CERT_INSTALLER" ]; then
    echo "Running Apple certificate installer for Python ${PYTHON_MINOR}..."
    open "$CERT_INSTALLER"
    echo "✅ Certificate installer launched."
else
    echo "ℹ️  Python ${PYTHON_MINOR} certificate installer not found at expected path. Skipping."
fi

# ─── STEP 8: FINAL SSL VERIFICATION ──────────────────────────────────────────
echo ""
echo "----------------------------------------"
echo "Verifying SSL is fully working..."
echo "----------------------------------------"

SSL_CHECK=$(/usr/local/bin/python3 -c "import ssl; import certifi; print(certifi.where())" 2>&1)

if echo "$SSL_CHECK" | grep -q ".pem"; then
    echo "✅ SSL verification passed. Certificate bundle at:"
    echo "   $SSL_CHECK"
else
    echo "❌ SSL verification failed."
    echo "Output: $SSL_CHECK"
    echo "Reach out to Pubmatic for troubleshooting the issue."
    exit 1
fi

echo ""
echo "----------------------------------------"
echo "✅ Process completed successfully."
echo "----------------------------------------"
