# PubMatic MCP Server Extension Setup Guide for Microsoft Copilot Studio (External)

This document explains how to install and configure the PubMatic MCP Server extension in Microsoft Copilot Studio for external users.  
The `.yaml` file enables Copilot Studio to communicate with PubMatic's externally accessible MCP Server.

All screenshots referenced in this guide are stored in the `screenshots/` folder.

---

## Prerequisites

- Microsoft Copilot Studio (latest version)
- PubMatic `.yaml` API specification file
- External PubMatic authentication details:
  - PubToken (Bearer Token)
  - Resource ID
  - Resource Type (`PUBLISHER`, `DSP`, `BUYER` or `Activate Advertiser`)

## Refer to the PubMatic API documentation to learn how to generate a PubToken and obtain other required credentials:
## https://help.pubmatic.com/activate/reference/get-started-with-pubmatic-apis

---

## Installation and Configuration Steps

### Step 1: Access Copilot Studio  
Navigate to Microsoft Copilot Studio at https://copilotstudio.microsoft.com and sign in with your Microsoft account.

![Step 1](./screenshots/Step1_Access_Copilot_Studio.png)

---

### Step 2: Create or Open an Agent  
Create a new agent or open an existing one where you want to add the PubMatic MCP Server.

![Step 2](./screenshots/Step2_Open_Agent.png)

---

### Step 3: Access Plugin Settings  
In the agent editor, navigate to the **Plugins** section to manage integrations.

![Step 3](./screenshots/Step3_Access_Plugins.png)

---

### Step 4: Add a New Plugin  
Click **Add Plugin** and select **Create from OpenAPI** or **Upload Custom Plugin**.

![Step 4](./screenshots/Step4_Add_Plugin.png)

---

### Step 5: Upload the API Specification  
Upload or paste the PubMatic `.yaml` API specification file.

![Step 5](./screenshots/Step5_Upload_API_Spec.png)

---

### Step 6: Configure Authentication  
Provide the following authentication credentials:

- **PubToken**: Your PubMatic Bearer Token
- **Resource ID**: Your Resource ID
- **Resource Type**: Select from `PUBLISHER`, `DSP`, `BUYER`, or `Activate Advertiser`

Click **Save**.

![Step 6](./screenshots/Step6_Configure_Auth.png)

---

### Step 7: Verify Plugin Connection  
Test the connection to ensure the plugin is properly configured.

![Step 7](./screenshots/Step7_Verify_Connection.png)

---

### Step 8: Enable Plugin  
Ensure the PubMatic MCP Server plugin is enabled in your agent configuration.

![Step 8](./screenshots/Step8_Enable_Plugin.png)

---

### Step 9: Review Available Operations  
Open the plugin configuration to review the available operations and endpoints.

![Step 9](./screenshots/Step9_Review_Operations.png)

---

### Step 10: Test the Integration  
In the agent test panel, issue a query that leverages the PubMatic MCP Server.

![Step 10](./screenshots/Step10_Test_Integration.png)

---

### Step 11: Deploy Your Agent  
Once configured, deploy your agent to make it available to users.

![Step 11](./screenshots/Step11_Deploy_Agent.png)

---

### Step 12: Use MCP Server via Copilot Studio  
Users can now interact with the agent and leverage PubMatic MCP Server capabilities through natural language queries.

![Step 12](./screenshots/Step12_Query_Usage.png)

---

## Troubleshooting

- Verify your PubToken is valid and has not expired.
- Ensure the Resource ID and Resource Type are correctly specified.
- Check that the `.yaml` file follows OpenAPI 2.0 specification.
- Restart Copilot Studio if changes are not reflected immediately.
- Review the plugin logs for detailed error messages.

---

## API Specification

The PubMatic MCP Server API is defined in the `pubmatic_api_specification.yaml` file included in this folder. This file contains:

- **Host**: `apps.pubmatic.com`
- **Base Path**: `/`
- **Scheme**: `https`
- **Main Endpoint**: `/mcpserver/external/mcp`

Required headers for all requests:
- `pubToken`: Your PubMatic Bearer Token
- `Content-Type`: `application/json`
- `Accept`: `application/json, text/event-stream`

Optional headers:
- `resource-id`: Your Resource ID
- `resource-type`: Your Resource Type

---

## License
This document is provided for users integrating with the external PubMatic MCP Server.
