#!/bin/bash

set -e

MIN_VERSION="3.8"
MAX_VERSION="3.13"

echo "----------------------------------------"
echo "Python 3.12 Installation / Validation"
echo "----------------------------------------"

# Function to compare versions
version_in_range() {
    local version=$1
    local min=$2
    local max=$3

    # Compare versions using sort
    if [[ "$(printf '%s\n' "$min" "$version" | sort -V | head -n1)" == "$min" ]] && \
       [[ "$(printf '%s\n' "$version" "$max" | sort -V | head -n1)" == "$version" ]]; then
        return 0
    else
        return 1
    fi
}

# Check if python3 exists
if command -v python3 &> /dev/null
then
    CURRENT_VERSION=$(python3 --version | awk '{print $2}')
    echo "Detected Python version: $CURRENT_VERSION"

    if version_in_range "$CURRENT_VERSION" "$MIN_VERSION" "$MAX_VERSION"; then
        echo "✅ Python version is between 3.8 and 3.13. No installation required."
        echo "----------------------------------------"
        echo "✅ Process completed successfully."
        exit 0
    else
        echo "⚠️ Python version is outside the required range."
        echo "Proceeding with Python 3.12 installation/update..."
    fi
else
    echo "⚠️ Python3 is not installed."
    echo "Proceeding with Python 3.12 installation..."
fi

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
if ! brew update
then
    echo "❌ Homebrew update failed."
    echo "Reach out to Pubmatic for troubleshooting the issue."
    exit 1
fi

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
    echo "----------------------------------------"
    echo "✅ Process completed successfully."
else
    echo "❌ Python 3.12 installation verification failed."
    echo "Reach out to Pubmatic for troubleshooting the issue."
    exit 1
fi

# ----------------------------------------
# SSL Fix — Wrapper Script Setup
# ----------------------------------------
echo ""
echo "----------------------------------------"
echo "SSL Certificate Fix"
echo "----------------------------------------"

# Detect the real python3 executable path (resolving any existing symlinks/wrappers)
REAL_PYTHON3=""

# First try to find the actual Python binary, not just /usr/local/bin/python3
# Check common framework locations (macOS Python.org installer)
for version_dir in /Library/Frameworks/Python.framework/Versions/*/bin/python3; do
    if [[ -x "$version_dir" ]]; then
        REAL_PYTHON3="$version_dir"
    fi
done

# Fall back to Homebrew Python if framework Python not found
if [[ -z "$REAL_PYTHON3" ]]; then
    for brew_python in /opt/homebrew/opt/python@*/bin/python3 /usr/local/opt/python@*/bin/python3; do
        if [[ -x "$brew_python" ]]; then
            REAL_PYTHON3="$brew_python"
            break
        fi
    done
fi

# Last resort: resolve the current python3 symlink to its real target
if [[ -z "$REAL_PYTHON3" ]] && command -v python3 &> /dev/null; then
    REAL_PYTHON3=$(python3 -c "import sys; print(sys.executable)")
fi

if [[ -z "$REAL_PYTHON3" ]]; then
    echo "❌ Could not locate a real Python 3 binary. Skipping SSL wrapper setup."
    echo "Reach out to Pubmatic for troubleshooting the issue."
    exit 1
fi

echo "Detected real Python 3 binary: $REAL_PYTHON3"

# Step 1 — Back up the current python3 symlink
if [[ -e /usr/local/bin/python3 ]]; then
    echo "Backing up /usr/local/bin/python3 → /usr/local/bin/python3.symlink.bak ..."
    sudo mv /usr/local/bin/python3 /usr/local/bin/python3.symlink.bak
else
    echo "No existing /usr/local/bin/python3 found; skipping backup."
fi

# Step 2 — Create the SSL wrapper script
echo "Creating SSL wrapper at /usr/local/bin/python3 ..."
sudo tee /usr/local/bin/python3 > /dev/null <<SH
#!/bin/sh
export SSL_CERT_FILE="/private/etc/ssl/cert.pem"
export REQUESTS_CA_BUNDLE="/private/etc/ssl/cert.pem"
exec "$REAL_PYTHON3" "\$@"
SH

# Step 3 — Make it executable
sudo chmod +x /usr/local/bin/python3
echo "✅ SSL wrapper created and made executable."

# Step 4 — Verify the wrapper works correctly
echo "Verifying SSL wrapper..."
SSL_OUTPUT=$(/usr/local/bin/python3 -c "import os,sys; print(sys.executable); print('SSL_CERT_FILE=', os.environ.get('SSL_CERT_FILE'))")
echo "$SSL_OUTPUT"

if echo "$SSL_OUTPUT" | grep -q "SSL_CERT_FILE= /private/etc/ssl/cert.pem"; then
    echo "✅ SSL wrapper is working correctly."
else
    echo "⚠️  SSL_CERT_FILE not set as expected. Please verify manually."
fi

# ----------------------------------------
# Certifi upgrade and SSL verification
# ----------------------------------------
echo ""
echo "----------------------------------------"
echo "Certifi Upgrade & SSL Verification"
echo "----------------------------------------"

echo "Upgrading certifi..."
if ! /usr/local/bin/python3 -m pip install --upgrade certifi
then
    echo "❌ certifi upgrade failed."
    echo "Reach out to Pubmatic for troubleshooting the issue."
    exit 1
fi

# Run the Python.org Install Certificates command if it exists (macOS)
PYTHON_VERSION_SHORT=$(/usr/local/bin/python3 -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')")
INSTALL_CERTS_CMD="/Applications/Python ${PYTHON_VERSION_SHORT}/Install Certificates.command"

if [[ -f "$INSTALL_CERTS_CMD" ]]; then
    echo "Running Install Certificates.command for Python ${PYTHON_VERSION_SHORT}..."
    open "$INSTALL_CERTS_CMD"
else
    echo "ℹ️  Install Certificates.command not found for Python ${PYTHON_VERSION_SHORT} (this is normal for Homebrew installs)."
fi

echo "Verifying SSL works..."
SSL_VERIFY=$(/usr/local/bin/python3 -c "import ssl; import certifi; print(certifi.where())")
echo "certifi CA bundle: $SSL_VERIFY"

if [[ -n "$SSL_VERIFY" ]]; then
    echo "✅ SSL verification passed."
else
    echo "❌ SSL verification failed."
    echo "Reach out to Pubmatic for troubleshooting the issue."
    exit 1
fi

echo "----------------------------------------"
echo "✅ All steps completed successfully."
echo "----------------------------------------"
