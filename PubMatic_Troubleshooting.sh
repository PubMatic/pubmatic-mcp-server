#!/bin/bash

set -e

MIN_VERSION="3.8"
MAX_VERSION="3.13.99"

echo "----------------------------------------"
echo " PubMatic MCP Server - Setup Check"
echo " Python + SSL Fix for Claude Desktop"
echo "----------------------------------------"
echo ""

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

if command -v python3 &> /dev/null; then
    CURRENT_VERSION=$(python3 --version | awk '{print $2}')
    if version_in_range "$CURRENT_VERSION" "$MIN_VERSION" "$MAX_VERSION"; then
        echo "✅ Python $CURRENT_VERSION detected — supported version."
        SKIP_INSTALL=true
    else
        echo "⚠️  Python $CURRENT_VERSION is not in the supported range. Installing Python 3.12..."
        SKIP_INSTALL=false
    fi
else
    echo "⚠️  Python 3 not found. Installing Python 3.12..."
    SKIP_INSTALL=false
fi

# ─── INSTALL PYTHON IF NEEDED ─────────────────────────────────────────────────
if [ "$SKIP_INSTALL" = false ]; then

    if ! command -v brew &> /dev/null; then
        echo "    Installing Homebrew (required to install Python)..."
        if ! /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" &> /dev/null; then
            echo "❌ Homebrew installation failed. Please reach out to Pubmatic support."
            exit 1
        fi
        if [[ -d "/opt/homebrew/bin" ]]; then
            eval "$(/opt/homebrew/bin/brew shellenv)"
        fi
    fi

    brew update &> /dev/null || true

    if ! brew install python@3.12 &> /dev/null; then
        echo "❌ Could not install Python 3.12. Please reach out to Pubmatic support."
        exit 1
    fi

    brew link --overwrite --force python@3.12 &> /dev/null || true

    if command -v python3.12 &> /dev/null; then
        CURRENT_VERSION=$(python3.12 --version | awk '{print $2}')
        echo "✅ Python $CURRENT_VERSION installed."
    else
        echo "❌ Python 3.12 installation could not be verified. Please reach out to Pubmatic support."
        exit 1
    fi

fi

# ─── DETECT EXACT PYTHON BINARY ───────────────────────────────────────────────
PYTHON_MINOR=$(echo "$CURRENT_VERSION" | cut -d. -f1-2)
ACTUAL_PYTHON_BIN=""

for candidate in \
    "/opt/homebrew/opt/python@${PYTHON_MINOR}/bin/python${PYTHON_MINOR}" \
    "/usr/local/opt/python@${PYTHON_MINOR}/bin/python${PYTHON_MINOR}" \
    "/Library/Frameworks/Python.framework/Versions/${PYTHON_MINOR}/bin/python3"; do
    if [[ -x "$candidate" ]]; then
        ACTUAL_PYTHON_BIN="$candidate"
        break
    fi
done

if [[ -z "$ACTUAL_PYTHON_BIN" ]]; then
    ACTUAL_PYTHON_BIN=$(python3 -c "import sys; print(sys.executable)")
fi

if [ -z "$ACTUAL_PYTHON_BIN" ]; then
    echo "❌ Could not locate Python binary. Please reach out to Pubmatic support."
    exit 1
fi

# ─── ENSURE /usr/local/bin EXISTS (Apple Silicon) ────────────────────────────
if [ ! -d /usr/local/bin ]; then
    sudo mkdir -p /usr/local/bin
fi

# ─── BACK UP EXISTING python3 ─────────────────────────────────────────────────
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

# ─── VERIFY SSL WRAPPER ────────────────────────────────────────────────────────
VERIFY_OUTPUT=$(/usr/local/bin/python3 -c "import os,sys; print(os.environ.get('SSL_CERT_FILE'))")
if echo "$VERIFY_OUTPUT" | grep -q "/private/etc/ssl/cert.pem"; then
    echo "✅ SSL certificate path configured."
else
    echo "⚠️  SSL certificate path did not apply as expected. Please verify manually."
fi

# ─── UPDATE CERTIFI ────────────────────────────────────────────────────────────
if ! /usr/local/bin/python3 -m pip --version &> /dev/null; then
    /usr/local/bin/python3 -m ensurepip --upgrade &> /dev/null || true
fi

if ! sudo /usr/local/bin/python3 -m pip install --upgrade certifi --break-system-packages --ignore-installed --quiet 2>/dev/null; then
    echo "❌ Failed to update certificate package. Please reach out to Pubmatic support."
    exit 1
fi

# Run Apple's official certificate installer if available
CERT_INSTALLER="/Applications/Python ${PYTHON_MINOR}/Install Certificates.command"
if [ -f "$CERT_INSTALLER" ]; then
    open "$CERT_INSTALLER"
fi

# ─── FINAL SSL VERIFICATION ───────────────────────────────────────────────────
SSL_CHECK=$(/usr/local/bin/python3 -c "import ssl; import certifi; print(certifi.where())" 2>&1)

if echo "$SSL_CHECK" | grep -q ".pem"; then
    echo "✅ SSL certificates verified."
else
    echo "❌ SSL verification failed. Please share this with Pubmatic support: $SSL_CHECK"
    exit 1
fi

echo ""
echo "----------------------------------------"
echo "✅ Setup complete. You can now use the"
echo "   PubMatic MCP Server with Claude Desktop."
echo "----------------------------------------"
