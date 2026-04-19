#!/bin/bash

# PubMatic Copilot Studio Integration Sanity Check Script
# This script validates the configuration and connectivity of PubMatic MCP Server integration

echo "=================================================="
echo "PubMatic Copilot Studio Integration Sanity Check"
echo "=================================================="
echo ""

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check 1: Validate required files
echo "[1] Checking for required files..."
files_to_check=(
    "pubmatic_api_specification.yaml"
    "MCP_CoPilot_Setup_ReadMe_External.md"
)

for file in "${files_to_check[@]}"; do
    if [ -f "$file" ]; then
        echo -e "${GREEN}✓${NC} Found: $file"
    else
        echo -e "${RED}✗${NC} Missing: $file"
    fi
done
echo ""

# Check 2: Validate YAML syntax
echo "[2] Validating YAML API specification..."
if command -v yamllint &> /dev/null; then
    if yamllint pubmatic_api_specification.yaml &> /dev/null; then
        echo -e "${GREEN}✓${NC} YAML syntax is valid"
    else
        echo -e "${YELLOW}⚠${NC} YAML validation warnings detected"
        yamllint pubmatic_api_specification.yaml
    fi
else
    echo -e "${YELLOW}⚠${NC} yamllint not installed. Skipping YAML validation."
    echo "   Install with: brew install yamllint"
fi
echo ""

# Check 3: Verify OpenAPI specification structure
echo "[3] Verifying OpenAPI specification structure..."
if grep -q "swagger: '2.0'" pubmatic_api_specification.yaml; then
    echo -e "${GREEN}✓${NC} OpenAPI version detected: 2.0"
else
    echo -e "${RED}✗${NC} OpenAPI version not found or incorrect"
fi

if grep -q "host: apps.pubmatic.com" pubmatic_api_specification.yaml; then
    echo -e "${GREEN}✓${NC} PubMatic host configured: apps.pubmatic.com"
else
    echo -e "${RED}✗${NC} PubMatic host not configured"
fi

if grep -q "/mcpserver/external/mcp" pubmatic_api_specification.yaml; then
    echo -e "${GREEN}✓${NC} MCP endpoint found: /mcpserver/external/mcp"
else
    echo -e "${RED}✗${NC} MCP endpoint not found"
fi
echo ""

# Check 4: Validate authentication requirements
echo "[4] Checking authentication configuration..."
if grep -q "pubToken" pubmatic_api_specification.yaml; then
    echo -e "${GREEN}✓${NC} PubToken authentication parameter configured"
else
    echo -e "${RED}✗${NC} PubToken authentication parameter missing"
fi

if grep -q "Bearer:" pubmatic_api_specification.yaml; then
    echo -e "${GREEN}✓${NC} Bearer token security definition found"
else
    echo -e "${RED}✗${NC} Bearer token security definition missing"
fi
echo ""

# Check 5: Verify HTTP method and content types
echo "[5] Verifying HTTP method and content types..."
if grep -q "post:" pubmatic_api_specification.yaml; then
    echo -e "${GREEN}✓${NC} POST method configured"
else
    echo -e "${RED}✗${NC} POST method not found"
fi

if grep -q "application/json" pubmatic_api_specification.yaml; then
    echo -e "${GREEN}✓${NC} JSON content type configured"
else
    echo -e "${RED}✗${NC} JSON content type not configured"
fi

if grep -q "text/event-stream" pubmatic_api_specification.yaml; then
    echo -e "${GREEN}✓${NC} Event-stream content type configured for streaming"
else
    echo -e "${YELLOW}⚠${NC} Event-stream content type not configured"
fi
echo ""

# Check 6: Validate response schemas
echo "[6] Checking response schemas..."
if grep -q "200:" pubmatic_api_specification.yaml; then
    echo -e "${GREEN}✓${NC} Success response (200) defined"
else
    echo -e "${RED}✗${NC} Success response (200) not defined"
fi

if grep -q "401:" pubmatic_api_specification.yaml; then
    echo -e "${GREEN}✓${NC} Unauthorized response (401) defined"
else
    echo -e "${YELLOW}⚠${NC} Unauthorized response (401) not defined"
fi
echo ""

# Check 7: Verify folder structure
echo "[7] Verifying folder structure..."
if [ -d "screenshots" ]; then
    count=$(find screenshots -type f | wc -l)
    echo -e "${GREEN}✓${NC} Screenshots folder exists ($count files)"
else
    echo -e "${YELLOW}⚠${NC} Screenshots folder not found"
fi

if [ -d "archive" ]; then
    echo -e "${GREEN}✓${NC} Archive folder exists"
else
    echo -e "${YELLOW}⚠${NC} Archive folder not found"
fi
echo ""

# Check 8: Display configuration summary
echo "=================================================="
echo "Configuration Summary"
echo "=================================================="
echo ""
echo "API Specification:"
echo "  - File: pubmatic_api_specification.yaml"
echo "  - OpenAPI Version: 2.0"
echo "  - Host: apps.pubmatic.com"
echo "  - Base Path: /"
echo "  - Scheme: https"
echo "  - Main Endpoint: /mcpserver/external/mcp"
echo ""
echo "Authentication:"
echo "  - Type: Bearer Token (PubToken)"
echo "  - Required Headers: pubToken, Content-Type, Accept"
echo "  - Optional Headers: resource-id, resource-type"
echo ""
echo "Resource Types Supported:"
echo "  - PUBLISHER"
echo "  - DSP"
echo "  - BUYER"
echo "  - Activate Advertiser"
echo ""
echo "Documentation:"
echo "  - Setup Guide: MCP_CoPilot_Setup_ReadMe_External.md"
echo "  - Screenshots: Located in screenshots/ folder"
echo ""

# Final status
echo "=================================================="
echo "Sanity Check Complete!"
echo "=================================================="
echo ""
echo "Next Steps:"
echo "1. Review MCP_CoPilot_Setup_ReadMe_External.md for setup instructions"
echo "2. Ensure your PubToken and resource credentials are available"
echo "3. Upload the pubmatic_api_specification.yaml to Copilot Studio"
echo "4. Configure the authentication headers in Copilot Studio"
echo "5. Test the integration using the provided documentation"
echo ""
