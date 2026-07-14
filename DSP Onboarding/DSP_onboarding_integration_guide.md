# DSP Onboarding Integration Guide

## Overview

The DSP Onboarding Agent enables Demand-Side Platforms (DSPs) to seamlessly verify, test, and onboard their OpenRTB endpoints programmatically via MCP (Model Context Protocol). It provides a conversational interface to collect integration details, run live bid requests, and return structured, actionable feedback including validation scores and ad previews.

## Capabilities

- **Automated Intake**: Collect DSP configuration details (endpoints, platforms, ad formats, data centers) conversationally.
- **Integration Testing**: Automatically send OpenRTB bid requests to the DSP's endpoint from selected data centers.
- **Response Validation**: Validate bid responses against OpenRTB 2.5 standards and PubMatic-specific requirements.
- **Ad Rendering**: Preview and verify ad creatives (HTML/Native/VAST) directly from the DSP's bid response.
- **Structured Feedback**: Return detailed, machine-readable test results, latency metrics, and validation scores.

## Integration Steps

1. Download .mcpb file from https://github.com/PubMatic/pubmatic-mcp-server/tree/main/Claude_Desktop_Extension
2. Install the .mcpb file by double clicking on file
3. This will open PubMatic's configuration window in Claude 

![PubMatic MCP Configuration](https://github.com/PubMatic/pubmatic-mcp-server/blob/34010d9e253c580996d27ab358b08cbaa66961f0/Claude_Desktop_Extension/screenshots/Step5_Install_Extension.png) 

![Configuration Fields](https://github.com/PubMatic/pubmatic-mcp-server/blob/34010d9e253c580996d27ab358b08cbaa66961f0/Claude_Desktop_Extension/screenshots/Step7_Enter_Credential_Details.png)

4. Add PubMatic's Bearer token which you have generated using PubMatic's API / UI
5. Add Resournce Id which PubMatic's Solution Engineer have shared to you
6. Add Resource Type as Demand Partner and save the changes.   
7. Once saving all the fields, kindly confirm whether PubMatic MCP server is enable or not like below

![Enable PubMatc MCP server](https://github.com/PubMatic/pubmatic-mcp-server/blob/34010d9e253c580996d27ab358b08cbaa66961f0/Claude_Desktop_Extension/screenshots/Step8_Enable_Extension.png)

8. Download DSP onboarding related skills from [Here](https://github.com/PubMatic/pubmatic-mcp-server/blob/main/DSP%20Onboarding/)

9. This contains two skill files dsp-launchpad-intake.skill, dsp-live-setup.skill 
10. Double click on those files, it will installed those on your claude setup
11. Thats it! For safer side, restart claude 
12. Open new chat session and type "Hey I wanted to onboard on PubMatic platform as new DSP"


## Error Handling

- **Configuration Errors**: Returns a `configuration_error` status with details if the endpoint is invalid or required parameters are missing.
- **Integration Testing Failures**: Returns an `error` or `blocked` status if the DSP endpoint is unreachable, times out, or fails OpenRTB validation consistently.
- **System Errors**: Returns a user-presentable error message and logs the exception for debugging.

## Best Practices

- **Provide correct prompt**: Ensure the prompt contains `DSP onboarding` like text
- **Provide Accurate Endpoints**: Ensure the `dsp_bid_endpoint_url` is publicly accessible and capable of handling OpenRTB 2.5 POST requests.
- **Use Custom Samples**: For specific testing scenarios, provide `custom_samples` with valid OpenRTB JSON payloads mapped to your ad formats to override the default templates.
- **Render Artifacts**: AI assistants should render the returned `html_results` as a rich UI artifact (e.g., `dsp_test_results.html`) to display the dashboard, validation checks, and ad previews clearly to the user.
- **Follow the Workflow**: Use the `dsp-launchpad-intake` skill for initial testing. Once successful (>50% success rate), transition to the `dsp-live-setup` skill to finalize campaign creation.

## Change Log

- v0.1: Initial release of the `submit_dsp_details` tool for direct DSP intake, automated integration testing, and SE approval preparation.
