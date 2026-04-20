# PubMatic MCP Server Extension Setup Guide for Microsoft Copilot Studio (External)

This document explains how to install and configure the PubMatic MCP Server extension in Microsoft Copilot Studio for external users using custom header authentication.  

The `.yaml` file enables Copilot Studio to communicate with PubMatic's externally accessible MCP Server.

All screenshots referenced in this guide are stored in the `screenshots/` folder.

---

## Prerequisites

- Microsoft Copilot Studio (latest version)
- PubMatic `.yaml` API specification file
- External PubMatic authentication details:
  - PubToken (Bearer Token)
  - Resource ID
  - Resource Type (`PUBLISHER`, `BUYER` or `Activate Advertiser`)

## Refer to the PubMatic API documentation to learn how to generate a PubToken and obtain other required credentials:
## https://help.pubmatic.com/activate/reference/get-started-with-pubmatic-apis

---

## Steps to Create and Use a Custom Connector

Prerequisite : Define the API
Ensure you have the OpenAPI definition (Swagger file) or the API endpoint details ready for the service you want to connect to. For PubMatic, you can use the **`pubmatic_connector.yaml`** file provided in this folder, which contains:
- Connector name
- Host Name
- **Authentication details**: PubToken (Bearer Token), Resource ID, and Resource Type
- **Base URL**: `https://apps.pubmatic.com`
- **Main Endpoint**: `/mcpserver/external/mcp`

## Step-by-Step Configuration

### **Step 1: Access Copilot Studio**

1. Open your web browser
2. Navigate to: **https://copilotstudio.microsoft.com**
3. Click **Sign in** 
4. Enter your Microsoft account credentials

**What you'll see:**
- Home dashboard
- Left sidebar with navigation options

---

### **Step 2: Navigate to Tools Section**

1. On the left sidebar, click the **Tools** icon (grid/square icon)
2. You'll see the **Tools** page with:
   - **+ New tool** button (top-left)
   - List of existing tools
   - Search functionality

---

### **Step 3: Create a New Tool**

1. Click the **+ New tool** button
2. A modal dialog appears: **"New tool"**
3. Review the available tool types:
   - **Prompt** - Apply AI to text, documents, or images
   - **Agent Flow** - Predictable automations
   - **Computer use** - Web and desktop interaction
   - **Model Context Protocol** - Open standard for connecting agents to data
   - **Custom Connector** ← **✅ SELECT THIS ONE**
   - **REST API**

4. Click on **Custom Connector** option
   - **Description**: "External services and data sources"

---

### **Step 4: Redirect to Power Apps**

After selecting **Custom Connector**, you will be redirected to **Power Apps** (make.powerapps.com):

1. The page automatically opens the **Custom connectors** section
2. Click **+ New custom connector** button
3. A dropdown menu appears with options:
   - **Create from blank**
   - **Import an OpenAPI file** ← **✅ SELECT THIS ONE**
   - **Import from GitHub**
   - **Create from Azure Service (Preview)**

4. Select **Import an OpenAPI file**

---

### **Step 5: Upload and Configure API File**

1. **Select the OpenAPI/Swagger file**:
   - Choose the **pubmatic_connector.yaml** file from your system
   
2. **Enter Connector Name**:
   - Name: `PubMatic MCP Server` (or your preferred name)
   - This name will be displayed in Copilot Studio

3. Click **Continue** or **Create**

---

### **Step 6: Configure General Information**

The connector editor opens with the **General** tab selected.

**Required Configuration:**

| Field | Value | Example |
|-------|-------|---------|
| **Connector icon** | Upload a .PNG or .JPG file (max 1MB) | PubMatic logo |
| **Icon background color** | Hex color code | `#007BA7` (PubMatic blue) |
| **Description** | Brief description | "PubMatic MCP Server for managing publisher/advertiser data" |
| **Host** | API host domain | `apps.pubmatic.com` |
| **Base URL** | API base path | `/` |

**Steps:**

1. Click **Upload connector icon** 
2. Select your icon file (PNG or JPF, recommended 32x32 px)
3. Click on the **color picker** and set background color (or enter hex code)
4. Enter **Host**: `apps.pubmatic.com`
5. Enter **Base URL**: `/`
6. Enter **Description**: "PubMatic MCP Server for external API access"

---

### **Step 7: Configure Authentication**

1. Click the **Security** tab
2. Under **Authentication type**, select: **No authentication**


**Note**: If custom headers option isn't visible in Security, you can add them as part of the action definition in the next step.

---

### **Step 8: Define API Actions**

1. Click the **Definition** tab
2. Keep it same as it is.
3. Click **Save** for each action
4. Repeat for additional endpoints

---

### **Step 9: Test the Connector**

1. Click the **Test** tab (within the custom connector editor)
2. For each action you created:
   - Click **Test operation**
   - Fill in required parameters:
     - `pubToken`: Paste your valid PubMatic Bearer Token
     - `resource-id`: Enter your Resource ID
     - `resource-type`: Select PUBLISHER, BUYER, or Activate Advertiser
   - Click **Test operation**
   
3. **Expected Result**: 
   - ✅ Response status: **200 OK**
   - ✅ Response body contains valid data
   - ✅ No error messages

**Troubleshooting Test Failures:**
- ❌ **401 Unauthorized**: Verify PubToken is correct and not expired
- ❌ **404 Not Found**: Verify resource-id and resource-type are valid
- ❌ **500 Server Error**: Contact PubMatic support

---

### **Step 10: Save and Publish Connector**

1. Click **Update connector** button (top-right)
2. Wait for the connector to be saved (status: "Saved")

---

### **Step 11: Return to Copilot Studio**

1. Go back to **Copilot Studio** (https://copilotstudio.microsoft.com)
2. Navigate to your **Agent**.
3. Creae a blank Agent. 
4. Save the Agent and click on agent which was created.
3. Go to on the Tool Tab of that Agent
4. Click  **+ Add a tool**
5. Select All and Search for your newly created connector: **"PubMatic MCP Server"**
6. Select it to add to your agent after making the new connection.

---

### **Step 12: Configure Tools Details**

1. Within your agent, go to the **Tools** tab
2. You will see 4 sections
    - Details **Check the details. Make sure connection is established**
    - Inputs **Check the input fields. Fill the details**
    - Tools **List of Tools been shown**
    - Resources **List of resource if any**.

3. Enter the inputs fields
  - Pub Token
  - Resource ID
  - Resource Type

4. Save it and make sure it is enabled.
5. Once Saved, Click on Refresh icon on Tools section
6. Tools will be Loaded

---

### **Step 13: Test the Agent**

1. In Copilot Studio, open your agent
2. Click **Test your agent**
3. Ask the queries related to features provided by PubMatic to which it will get connected to PubMatic MCP Server
4. Shown in such a way

---

## Troubleshooting

- Verify your PubToken is valid and has not expired.
- Ensure the Resource ID and Resource Type are correctly specified.
- Check that the `.yaml` file follows OpenAPI 2.0 specification.
- Restart Copilot Studio if changes are not reflected immediately.

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
- `resource-id`: Your Resource ID
- `resource-type`: Your Resource Type

---

## License
This document is provided for users integrating with the external PubMatic MCP Server.
