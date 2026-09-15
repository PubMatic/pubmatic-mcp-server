# Connect to the PubMatic MCP server in Claude

The PubMatic MCP connector connects Claude to your PubMatic account through the PubMatic MCP server. By connecting Claude and the PubMatic MCP server, you can create, manage, and troubleshoot deals and campaigns through Claude chat, using natural language.
For example, you could ask Claude to:
- Pull a report or troubleshoot delivery issues
- Create or update campaigns, media buys, or deals
- Look up targeting options, inventory, or catalog data
- The specific tools you can access depend on the type of account you have and your PubMatic permissions.
- Use the following information to set up the Claude connector.

## How the PubMatic MCP connector works
After you enable the connector in Claude, Claude uses the tools in the PubMatic MCP Server to interact with your data. The PubMatic MCP Server connector grants Claude permission to access and modify your PubMatic data – your deals and campaigns – based on your account permissions. Claude can only see and access what your account has access to.

See [PubMatic MCP Server Specifications](https://github.com/PubMatic/pubmatic-mcp-server/blob/main/README.md) for information about the specific tools available.

## Prerequisites
Before you connect, make sure you have:
- The latest version of Claude Desktop
- An active PubMatic account, with access to the connector
- Your PubMatic credentials - you'll log into your account as part of the connection process.

## Connect to the PubMatic MCP server in Claude Desktop
Follow the instructions in "[Use connectors to extend Claude's capabilities](https://support.claude.com/en/articles/11176164-use-connectors-to-extend-claude-s-capabilities)" to set up the connection between Claude and the PubMatic MCP Server.
During the setup, you'll be prompted to select the platform you want to use (**Publisher**, **Media Console**, or **Activate**) - choose the platform associated with your account and then log into your account.

If your user ID is mapped to multiple accounts, choose the account you want to use for this specific Claude session.
Need to access multiple accounts? See "Disconnect or switch accounts" below for information on how to switch between accounts.

## Verify your connection
After you've added the connector in Claude, use the following steps to verify the connection:

1. Open a new chat in Claude Desktop.
2. Select **+** in the lower left corner of the chat interface, and then select **Connectors**. Select the PubMatic MCP server to enable it.
3. Back in your chat, ask Claude what tools are available. You should see information about the PubMatic MCP server tools.
4. Try a simple prompt. For example, "list my active deals."

That's it - you've successfully connected your PubMatic account to Claude Desktop.

If you run into problems or you don't see any PubMatic tools, see the Troubleshooting section.

## Disconnect or switch accounts
If for whatever reason you want to disconnect the connection, see the information in the [Manage your connectors](https://support.claude.com/en/articles/11176164-use-connectors-to-extend-claude-s-capabilities#h_ed1689f55d) section of **Use connectors to extend Claude's capabilities**.

If you work in multiple PubMatic accounts, you need to disconnect the connector and then reconnect to a different account (by going through the full login workflow - choose the platform, enter your credentials, and then choose the specific account).

## Sample prompts
Now that you're set up, here are some sample prompts to show you what's possible.

### Deal management
- "Create a new deal"
- "Set up a new Preferred deal named "High Viewability Display" for advertiser DEF with $7 CPM, priority P9, running for the next 3 months"
- "Change the CPM for deals PMP12345 and PMP23456 to $12"

### Troubleshoot deals
- "What are the deals with the lowest win rate?"
- "Troubleshoot deal PMP12345"

### Activate
- "List available geos and devices I can use for a new media buy."
- "Create a media buy targeting US mobile users with a $10K budget."
- "Set up a brand lift study for our Q4 campaign."
- "Why is delivery pacing behind on media buy [MEDIA_BUY_ID]?"

## Data handling
- Claude sends tool requests to PubMatic to perform actions you ask for.
- PubMatic processes tool inputs and API responses needed to fulfill those requests.
- Access is limited to data your authenticated PubMatic account is permitted to see.
- PubMatic does not need full Claude conversation transcripts to operate the connector.

For legal details on collection, storage, retention, and third parties, see the PubMatic Properties Privacy Policy.

## FAQ

**Do I need a PubMatic account?** Yes. Log in with your PubMatic credentials during connection. You must have an active Publisher, Activate, or Media Console account.

**Can I use multiple PubMatic accounts in one Claude session?** No - you can only use one account at a time. To change accounts, disconnect the connector and reconnect - choose a different account when you log in.
**Does PubMatic store my Claude chats?** The connector uses tool inputs and responses needed for each request. See the Properties Privacy Policy for details.

**Is PubMatic MCP verified by Anthropic?** New directory listings are typically Community connectors unless Anthropic verifies them separately.

## Troubleshooting
|Problem	|What to try|
|-|-|
|Authentication fails	|Verify username/password and correct login type (Publisher, Media Console, or Activate). Disconnect and connect again.|
|PubMatic tools not visible	|Enable PubMatic MCP in the chat via + > Connectors. Confirm the connector shows as connected under Customize > Connectors.|
|Wrong account data	|Disconnect and reconnect; select the correct mapped account at sign-in.|
|Permission denied on a tool	|Your PubMatic role may not allow that action; contact your PubMatic admin.|
|Write action blocked	|Approve in Claude when prompted; check Enterprise Tool permissions if on Team or Enterprise.|
|Connection errors	|Disconnect and reconnect. If the issue persists, contact support (below).|

For general Claude connector issues, see the Anthropic support article, [Troubleshoot connection issues](https://support.claude.com/en/articles/11176164-use-connectors-to-extend-claude-s-capabilities#h_bbcedba6ca).

## Get help
Support email: support@pubmatic.com

When contacting support, include:
- PubMatic account ID (not your password)
- Platform (Publisher, Media Console, or Activate)
- Tool name or action you attempted
- Approximate date and time
- Screenshot of the error (if any)
