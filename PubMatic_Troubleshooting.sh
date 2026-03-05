#!/bin/bash

set -e

MIN_VERSION="3.7"
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