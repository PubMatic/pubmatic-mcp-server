# PubMatic Deal Creation and Copy Agent: Client Integration Guide

## Introduction

The PubMatic Deal Creation and Copy Agent enables programmatic creation and cloning of advertising deals through an AI-powered interface. The agent streamlines the deal setup process by validating fields according to business rules, enforcing required fields based on deal type, and providing a conversational interface for deal management operations.

This guide provides technical documentation for DSPs (Demand-Side Platforms), Buyers and publishers who want to integrate with PubMatic's Deal Creation and Copy Agent via the Model Context Protocol (MCP) Server.

> **Note**: For common architecture diagrams, authentication flows, and general integration approaches, please refer to the [Deal Management README](./README.md).

## Agent description

The agent facilitates the creation and cloning of various types of programmatic advertising deals (PMP, PG, Preferred, Acuction Packages) through natural language instructions, ensuring all business rules and field requirements are met.

## Key capabilities

- **Deal creation**: Create new deals with appropriate validation for required fields
- **Deal cloning**: Copy existing deals with the ability to modify specific attributes
- **Field validation**: Enforce business rules for different deal types
- **Deal type support**: Handle PMP, PG, Preferred and Auction Packages deal types with their specific requirements

## Deal type requirements

The agent enforces different field requirements based on deal type:

- **PMP (Private Marketplace)**: First/Second/Fixed Price + P11-P15 priority
- **PG (Programmatic Guaranteed)**: Fixed Price + P5-P7 + pacing + guaranteed impressions
- **Preferred**: Fixed Price + P8-P10

## Key benefits

The Deal Creation and Copy Agent delivers:

- **Streamlined workflow**: Quickly create or clone deals with natural language instructions
- **Error reduction**: Automatic validation prevents common setup errors
- **Efficiency**: Reduce time spent on repetitive deal setup tasks
- **Consistency**: Ensure all deals follow business rules and requirements
- **Flexibility**: Create various deal types with appropriate configurations

## API Endpoints for Deal Creation and Copy

> **Note**: For common API endpoints like authentication, please refer to the [Deal Management README](./README.md).

#### 1. Tool Discovery and Schema (JSON-RPC)

- Method: `tools/list`
- Transport: POST JSON-RPC 2.0 to your MCP server endpoint (e.g., `/v1/tools`)

Request:
```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "method": "tools/list",
  "params": {}
}
```

Response (excerpt showing deal_management):
```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "result": {
    "tools": [
      {
        "name": "deal_management",
        "description": "Creates or clones deals (PMP, PG, Preferred, Auction Packages)",
        "inputSchema": {
          "type": "object",
          "properties": {
            "query": { "type": "string", "description": "Current input from the user" },
            "message_history": {
              "type": "array",
              "description": "Conversation history as a list of messages. Each item: {role: 'user'|'assistant', content: string}.",
              "items": {
                "type": "object",
                "properties": {
                  "role": { "type": "string", "enum": ["user", "assistant"] },
                  "content": { "type": "string" }
                }
              }
            }
          },
          "required": ["query", "message_history"]
        }
      }
    ]
  }
}
```

#### 2. Tool Execution

**Endpoint**: `POST /v1/tools/deal_management`

**Description**: Execute the deal management tool with provided parameters.

**Request Format**:
```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "method": "tools/call",
  "params": {
    "name": "deal_management",
    "parameters": {
      "query": "Create a new PMP deal for advertiser ABC with a $5 CPM and priority P12",
      "message_history": [
        {
          "role": "user",
          "content": "I need to create a new deal for my advertiser"
        },
        {
          "role": "assistant",
          "content": "I'd be happy to help you create a new deal. Could you please provide more details about the deal you want to create? For example, what type of deal (PMP, PG, or Preferred), the advertiser name, CPM, and any other relevant details."
        }
      ]
    },
    "context": {
      "conversation_id": "optional-conversation-id"
    }
  }
}
```

**Response Format**:
```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "result": {
    "content": [
      {
        "type": "text",
        "text": "I'm creating a new PMP deal for advertiser ABC with the following details:\n\n- Deal Type: PMP\n- Advertiser: ABC\n- CPM: $5.00\n- Priority: P12\n\nBefore I proceed, I need a few more details:\n\n1. What should be the name of this deal?\n2. What is the start and end date for this deal?\n3. Are there any specific targeting requirements?"
      }
    ]
  }
}
```

**Example: Deal Creation Completion Response**:
```json
{
  "jsonrpc": "2.0",
  "id": 2,
  "result": {
    "content": [
      {
        "type": "text",
        "text": "I've successfully created a new PMP deal with the following details:\n\n- Deal ID: PMP12345\n- Deal Name: ABC Q3 Campaign\n- Deal Type: PMP\n- Advertiser: ABC\n- CPM: $5.00\n- Priority: P12\n- Start Date: 2025-07-01\n- End Date: 2025-09-30\n- Targeting: US, Desktop\n\nThe deal has been created in the system and is now ready for activation."
      }
    ],
    "structuredContent": {
      "deal_info": {
        "id": "PMP12345",
        "name": "ABC Q3 Campaign",
        "advertiser": "ABC",
        "start_date": "2025-07-01",
        "end_date": "2025-09-30",
        "deal_type": "PMP",
        "cpm": 5.00,
        "priority": "P12",
        "targeting": {
          "geo": "US",
          "device": "Desktop"
        },
        "status": "created"
      }
    }
  }
}
```

**Example: Deal Copy Request**:
```json
{
  "jsonrpc": "2.0",
  "id": 3,
  "method": "tools/call",
  "params": {
    "name": "deal_management",
    "parameters": {
      "query": "Clone deal PMP12345 but change the CPM to $6 and name it 'ABC Q4 Campaign'",
      "message_history": [
        {
          "role": "user",
          "content": "I need to copy an existing deal with some modifications"
        },
        {
          "role": "assistant",
          "content": "I'd be happy to help you copy an existing deal with modifications. Could you please provide the ID of the deal you want to copy and what modifications you'd like to make?"
        }
      ]
    },
    "context": {
      "conversation_id": "optional-conversation-id"
    }
  }
}
```

**Example: Deal Copy Response**:
```json
{
  "jsonrpc": "2.0",
  "id": 3,
  "result": {
    "content": [
      {
        "type": "text",
        "text": "I've successfully cloned deal PMP12345 with the following modifications:\n\n- New Deal ID: PMP12346\n- Deal Name: ABC Q4 Campaign (changed from 'ABC Q3 Campaign')\n- CPM: $6.00 (changed from $5.00)\n\nAll other settings remain the same:\n- Deal Type: PMP\n- Advertiser: ABC\n- Priority: P12\n- Start Date: 2025-07-01\n- End Date: 2025-09-30\n- Targeting: US, Desktop\n\nThe new deal has been created in the system and is now ready for activation."
      }
    ],
    "structuredContent": {
      "deal_info": {
        "id": "PMP12346",
        "name": "ABC Q4 Campaign",
        "advertiser": "ABC",
        "start_date": "2025-07-01",
        "end_date": "2025-09-30",
        "deal_type": "PMP",
        "cpm": 6.00,
        "priority": "P12",
        "targeting": {
          "geo": "US",
          "device": "Desktop"
        },
        "status": "created",
        "cloned_from": "PMP12345"
      }
    }
  }
}
```

## Common Use Cases

### 1. Creating a New Deal

The Deal Creation and Copy Agent can create various types of deals with appropriate validation:

**PMP Deal Creation Example**:
```
"Create a new PMP deal called 'Premium Video Q3' for advertiser XYZ with $8 CPM, priority P12, running from July 1 to September 30, 2025, targeting US mobile users"
```

**PG Deal Creation Example**:
```
"Create a new Programmatic Guaranteed deal for advertiser ABC with $10 CPM, priority P6, 1M guaranteed impressions, even pacing, running for Q3 2025"
```

**Preferred Deal Creation Example**:
```
"Set up a new Preferred deal named 'High Viewability Display' for advertiser DEF with $7 CPM, priority P9, running for the next 3 months"
```

### 2. Copying Existing Deals

The agent can clone existing deals with modifications:

**Simple Copy Example**:
```
"Clone deal PMP12345 but change the name to 'Q4 Campaign'"
```

**Copy with Multiple Modifications**:
```
"Copy deal PG45678 but update the CPM to $12, change the dates to Q4, and increase guaranteed impressions to 1.5M"
```

**Copy with Deal Type Change**:
```
"Clone deal PMP98765 but convert it to a Preferred deal with priority P9"
```

## Best Practices

1. **Be specific with instructions**: Provide clear details about the deal you want to create or copy.
2. **Expect follow-up questions**: The agent will ask for clarification if required fields are missing.
3. **Review before confirming**: The agent will typically ask for confirmation before creating or modifying deals.
4. **Use natural language**: You don't need to use technical terms; the agent can interpret conversational requests.
5. **Leverage conversation history**: The agent maintains context, so you can refer to previous deals or information.

## Troubleshooting

### Common Issues

1. **Missing required fields**: If the agent repeatedly asks for specific fields, ensure you're providing all required information for the deal type.
2. **Authentication errors**: Verify your API key is correctly configured and has the necessary permissions.
3. **Invalid deal types or parameters**: Ensure you're specifying valid deal types (PMP, PG, Preferred) and parameters within acceptable ranges.
4. **Deal not found for copying**: Verify the deal ID exists when attempting to clone a deal.

### Error Handling

The Deal Creation and Copy Agent provides detailed error messages to help diagnose issues:

```json
{
  "jsonrpc": "2.0",
  "id": 4,
  "error": {
    "code": 400,
    "message": "Invalid deal parameters",
    "data": {
      "details": "Priority P4 is not valid for PMP deals. Valid priorities are P11-P15."
    }
  }
}
```