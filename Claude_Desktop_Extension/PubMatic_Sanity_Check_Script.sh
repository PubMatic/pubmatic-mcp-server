#!/bin/bash
# PubMatic MCP Server — Quick Sanity Check (Bundled MCPB version)



MCP_HOST="mcp.pubmatic.com"
HEALTH_CHECK_URL="https://apps.pubmatic.com/mcpserver/external/health"

echo ""
echo "=========================================="
echo " PubMatic MCP Server — Quick Check"
echo "=========================================="

# 1. CURL CHECK
echo "[1/4] Checking for curl..."
if ! command -v curl >/dev/null 2>&1; then
echo "✘ curl not found. Please install curl."
exit 1
fi
echo "✔ curl available"

# 2. NETWORK CHECK
echo ""
echo "[2/4] Checking internet connectivity..."
if ! curl -fsS --max-time 5 https://www.google.com >/dev/null; then
echo "✘ No internet connectivity."
exit 1
fi
echo "✔ Internet working"

# 3. DNS CHECK (FIXED)
echo ""
echo "[3/4] Checking DNS for ${MCP_HOST}..."

if command -v host >/dev/null 2>&1; then
host "${MCP_HOST}" >/dev/null 2>&1
elif command -v nslookup >/dev/null 2>&1; then
nslookup "${MCP_HOST}" >/dev/null 2>&1
elif command -v dig >/dev/null 2>&1; then
dig +short "${MCP_HOST}" >/dev/null 2>&1
else
ping -c 1 "${MCP_HOST}" >/dev/null 2>&1
fi

if [ $? -ne 0 ]; then
echo "✘ DNS resolution failed for ${MCP_HOST}"
exit 1
fi

echo "✔ DNS resolution working"

# 4. MCP HEALTH CHECK
echo ""
echo "[4/4] Checking MCP server health..."
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" ${HEALTH_CHECK_URL})

if [ "$HTTP_CODE" -ge 200 ] && [ "$HTTP_CODE" -lt 300 ]; then
echo "✔ MCP Server is reachable (HTTP ${HTTP_CODE})"
else
echo "✘ MCP Server issue (HTTP ${HTTP_CODE})"
exit 1
fi

echo ""
echo "=========================================="
echo "✔ All checks passed. You can use MCPB safely."
echo "=========================================="