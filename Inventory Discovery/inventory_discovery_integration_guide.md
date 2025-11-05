# Inventory Discovery Integration Guide

## Overview

The Inventory Discovery Agent enables buyers to find, evaluate, and curate supply opportunities programmatically via MCP (Model Context Protocol). It returns structured, machine-readable outputs suitable for AI assistants and custom applications.

## Capabilities

- Search inventory by format, geography, device, audience, contextual signals, brand safety, and marketplace type.
- Rank and explain results with rationale and confidence signals.
- Curate recommended supply packages optimized for stated objectives.

## Authentication

All tool calls require an API key. Contact PubMatic to obtain credentials.

Header:
```
X-API-Key: your-api-key
```

## Tools

### inventory_discovery
- Purpose: Single-call tool for discovery and curation driven by a natural-language campaign brief.
- Method: tools/call
- Name: `inventory_discovery`
- Parameters (inputSchema excerpt):
```json
{
  "type": "object",
  "properties": {
    "brief": { "type": "string", "description": "Campaign brief from the user describing objectives, audiences, markets, formats, constraints, budget/flight, etc." },
    "filters": {
      "type": "object",
      "description": "Optional explicit filters to guide discovery",
      "properties": {
        "similarity": { "type": "number", "minimum": 0, "maximum": 1 },
        "content": {
          "type": "object",
          "properties": {
            "languages": { "type": "array", "items": { "type": "string" } },
            "genres": { "type": "array", "items": { "type": "string" } }
          }
        },
        "iabCategories": { "type": "array", "items": { "type": "string" } },
        "adFormats": { "type": "array", "items": { "type": "string" }, "description": "e.g., Video, Display" },
        "platforms": { "type": "array", "items": { "type": "string" }, "description": "e.g., CTV, mobile, desktop" },
        "delivery_type": { "type": "string", "description": "e.g., guaranteed, non_guaranteed" },
        "format_types": { "type": "array", "items": { "type": "string" }, "description": "e.g., display, video" },
        "standard_formats_only": { "type": "boolean" }
      }
    }
  },
  "required": ["brief"]
}
```
- Response (structuredContent excerpt):
```json
{
  "metaData": {
    "startIndex": 1,
    "endIndex": 24,
    "brief": "give me inventory for usa region and sports enthusiasts with a campaign budget of $250k",
    "filters": {
      "content": { "languages": ["en"], "genres": ["Sports"] },
      "iabCategories": ["IAB17"],
      "similarity": 0.9
    }
  },
  "packages": [
    {
      "id": 3084,
      "name": "USA Sports Audience Primary Targeting",
      "description": "Targets sports genres for English speakers in the USA.",
      "platforms": [ { "id": 7, "name": "CTV" } ],
      "adFormats": [ { "id": 13, "name": "Video" } ],
      "impressions": 2200658200,
      "ecpm": 14.0,
      "createdAt": "2025-10-28T02:33:44.000Z",
      "similarity": 0.95,
      "matchType": "primary_match",
      "matchExplanation": "Country, genre, and IAB17 (Sports) all match exactly; language is English as requested, and additional sports subcategories like cricket and basketball are included."
    },
    {
      "id": 3086,
      "name": "USA Sports Audience Primary Targeting",
      "description": "Targets sports genres for English speakers in the USA.",
      "platforms": [ { "id": 7, "name": "CTV" } ],
      "adFormats": [ { "id": 13, "name": "Video" } ],
      "impressions": 2200658200,
      "ecpm": 14.0,
      "createdAt": "2025-10-28T02:34:19.000Z",
      "similarity": 0.94,
      "matchType": "primary_match",
      "matchExplanation": "All key parameters—country, genre, IAB17 (Sports), and English language—match perfectly, with extra sports subgenres like cricket and football broadening the reach."
    },
    {
      "id": 202,
      "name": "CTV Video – US English, Spanish & Multilingual Sports & Entertainment",
      "description": "CTV video ads on US sports & entertainment, multilingual.",
      "platforms": [ { "id": 7, "name": "CTV" } ],
      "adFormats": [ { "id": 13, "name": "Video" } ],
      "impressions": 2693403000,
      "ecpm": 11.0,
      "createdAt": "2025-10-14T06:26:16.000Z",
      "similarity": 0.9,
      "matchType": "primary_match",
      "matchExplanation": "All user brief fields match: US, sports genres, English, and IAB17 (Sports); package also covers subgenres like football, cricket, and basketball for comprehensive sports reach."
    }
  ],
  "explanations": [
    "Ranked by match to objective and similarity",
    "Packages include rationale and trade-offs where applicable"
  ]
}
```

Note: Pagination parameters are ignored in the current version of this tool.

#### Example Request (aligned to user examples and AdCP filters)
```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "method": "tools/call",
  "params": {
    "name": "inventory_discovery",
    "parameters": {
      "brief": "give me inventory for usa region and sports enthusiasts with a campaign budget of $250k",
      "filters": {
        "similarity": 0.9,
        "content": { "languages": ["en"], "genres": ["Sports"] },
        "iabCategories": ["IAB17"],
        "adFormats": ["Video"],
        "platforms": ["CTV"],
        "delivery_type": "non_guaranteed",
        "format_types": ["video"],
        "standard_formats_only": true
      }
    }
  }
}
```

## Error Handling

- Validation errors include missing required parameters or incompatible filter combinations.
- Authentication failures return 401 with guidance to configure API keys.
- System errors return a user-presentable message and a machine-readable error code.

## Best Practices

- Provide a clear, concise campaign brief that covers objectives, audiences, markets, formats, constraints, and timing. The agent will infer filters and propose curated options.
- Use `structuredContent` for automation; prefer IDs over names when persisting.
- Capture rationales and trade-offs to inform deal strategy.

## Change Log

- v0.1: Simplified to a single `brief` parameter; agent infers filters and curates accordingly. Consolidated into single `inventory_discovery` tool with optional filters and shortlist.
