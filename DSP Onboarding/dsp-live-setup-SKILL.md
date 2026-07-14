---
name: dsp-live-setup
description: "This skill collects live setup details from a DSP after successful integration testing. Use this skill immediately after the dsp-launchpad-intake skill completes successfully to gather campaign configuration for the live environment."
---

# DSP Live Setup Form

This skill provides an interactive HTML form widget to collect live campaign setup details from a DSP.

Your job is to render the form, collect the details, and confirm the submission.

---

## Step 1 — Render the live setup form

Call `show_widget` with the HTML template below. The form uses `sendPrompt` on submission, so when the DSP fills it in and clicks Submit, their answers come back to you as a JSON string in the next message.

### HTML Widget Template

```html
<style>
  * { box-sizing: border-box; margin: 0; padding: 0; }
  body { font-family: var(--font-sans, -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif); background: transparent; color: var(--text-primary); }
  .form-card { background: var(--surface-1); border: 0.5px solid var(--border); border-radius: 12px; padding: 24px; max-width: 680px; }
  .brand-row { display: flex; align-items: center; justify-content: center; margin-bottom: 18px; }
  .brand-chip { background: #ffffff; border-radius: 8px; padding: 5px 9px; display: flex; align-items: center; border: 0.5px solid var(--border); }
  .brand-chip img { height: 15px; width: auto; display: block; }
  .form-title { color: var(--text-primary); font-size: 18px; font-weight: 500; margin-bottom: 20px; text-align: center; }
  .field { margin-bottom: 18px; }
  .field label { display: block; font-size: 13px; font-weight: 500; color: var(--text-secondary); margin-bottom: 6px; letter-spacing: 0.03em; }
  .help { font-size: 11px; color: var(--text-muted); margin-top: 3px; }
  input[type="text"] { width: 100%; padding: 9px 12px; background: var(--surface-2); border: 0.5px solid var(--border); border-radius: var(--radius, 7px); color: var(--text-primary); font-size: 14px; outline: none; transition: border-color 0.15s; }
  input[type="text"]:focus { border-color: var(--border-success); box-shadow: 0 0 0 3px var(--bg-success); }
  .section-label { font-size: 13px; font-weight: 500; color: var(--text-secondary); margin-bottom: 10px; display: block; letter-spacing: 0.03em; }
  .checkbox-group { display: flex; flex-direction: column; gap: 8px; }
  .checkbox-row { display: flex; align-items: center; gap: 10px; }
  .checkbox-row input[type="checkbox"] { width: 16px; height: 16px; accent-color: var(--text-success); cursor: pointer; flex-shrink: 0; }
  .checkbox-row .cb-label { font-size: 14px; color: var(--text-primary); min-width: 110px; }
  .inline-input { flex: 1; padding: 6px 10px; background: var(--surface-2); border: 0.5px solid var(--border); border-radius: 6px; color: var(--text-primary); font-size: 13px; outline: none; opacity: 0.4; pointer-events: none; transition: opacity 0.15s, border-color 0.15s; }
  .inline-input.qps-input { flex: 0 0 70px; }
  .inline-input.active { opacity: 1; pointer-events: auto; }
  .inline-input.active:focus { border-color: var(--border-success); box-shadow: 0 0 0 3px var(--bg-success); }
  .two-col { display: grid; grid-template-columns: repeat(auto-fit, minmax(200px, 1fr)); gap: 20px; }
  .divider { border: none; border-top: 0.5px solid var(--border); margin: 20px 0; }
  .required { color: var(--text-danger); margin-left: 2px; }
  .submit-btn { width: 100%; padding: 11px; background: var(--fill-success, var(--text-success)); border: none; border-radius: var(--radius, 8px); color: var(--on-success, var(--surface-0)); font-size: 15px; font-weight: 500; cursor: pointer; margin-top: 4px; transition: opacity 0.15s; }
  .submit-btn:hover { opacity: 0.88; }
</style>

<div class="form-card">
  <div class="brand-row">
    <span class="brand-chip"><img src="data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAM0AAAAeCAMAAAC4yGraAAAAflBMVEVMyO0BBAQXcHBl4/UAAAAAAABMyO5MyO5MtudUqaoN8vkzqax7f/slMn8ob7I2qNlfX19VVaoAAP8AagD///8Af/9/AH8AAABMyO4AAABR1PsAAAAAAAAAAABMyO5LxusAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAACM0xdjAAAAIHRSTlOjLAMLTNDTUhEDAgUCAwQIAgMBAgECAgH8/P6tdI9wKwYU5O8AAATPSURBVHjarZjrYqMqEIBFQNCkSbu752AE4vu/5XIZYPDWxO38aUS08zF3m+ZIpGpVklbN9U0xK3R7IbB7Vh+LG0RHsWWJwRJRLwnhD7tzqxn3ZRpn1eedVD2n6u7UNVTddt57V43bPT1XvPYBUnTnsGIPCKzN/H6reZ9mdDR0l8YDdbP6b/u9l0TT79EUhdKK3qcx5Ql2sPU7GuxpQDMFydZrj2l2bZMtwV6gsT9N0wNNF2WconXuQ3uOhlfn/rptlHY/2TmafkUzD3IYBinik5NY+dKLNDlw9Js0yliifipupPofHvWXU+P0/dP3NGvdUkqHQnOhtHdyrWg0R+frf+vXPe1I3ve0ebi1TvpBdmEP3cnQkSbfbVukl9UlcIj3OvuObX6SRkIJiafv91xmIYRUv/3qh5LuYi62cS7Zdc1TKvWJbGNK4PiftqZhVnPOtQXrEcai7Qgj8RKFTdirwffe9zSqotcMQCOUAL396pW61ckbLNKIlAJdbaKFxhvkgYIa0xieQyuaA13zaMucEEsUhtr7Ok2fab6ibYZE49dd/NwCIu2m8GBk7VBtosHQoPcjB47XlSAa/cCiQf0kVYYmHN9iZ3Ja8rQ2exrQkLBY01Slll4/Mk0OnBA2qtDYRy1mn4YstpIT1VP+illA0bhH1jRyQTO5AgU4wXygt0kqhbApNATcxolJxrE65MAH19pgmmQZzpMbnokbuI7qNirRtBue5u7PdKDPcjigN0tpwIbzzzQGBRApZWmrszEltEh0T3aiekrpKgot1TPRfG7Yxi0HEWOqTaA3SYETwqbQ2MeiEu3TcFyDY9I70aflDjsoKNuY03Y8jfo600K+7u6ZJuhi4PwVihtjrIG8bA9tQ6reNV69b5tlEy0TTbvOArCq+kFAxsh62/iHlStUPZnRvGqANmhM1ez5mcGyf54IrhdMs4ib6TmE4/hS87iggcCJYaP26s0BzVb78L5tpimNBN3TT2uX2jaVp7moukQvpSnILHYUAmGDVGN8lXe3afTGgPd+3KRB+inuysfKUdw49dv4rFzSQOBAT5BXWSn72vCfpuk3eugstzb0awLntNrTxK9gm+va08IPS3AqK4mK29CRfU+j/3UimOVVSp+lrwN0n0DjL+mQ1cZZgK6zQKyfBs4XR1NJVPzbuEFZwBhDzvfQtQdOTXtxDcIlIac+7e6yhPpIGVqqRdVPc47dDO1DGvbApSnuPdHZLGhuKp+7k7nDtvGttbpf2uhouHqixoTs0bDH99WTE9RM8/MTQZmZQ6EfO0HlLLqxohnHMK+JxPiF9NXo+0BFA/WdHec02MtZKDbRQ89PBEmuKg6hob2cxiXN1DVNN2bT4KqPvt3UccON6zn1Nxk6G9c1o692nf3K0+jy8+UtN/8TerAswucqNxF8VpWFPIrn28S1rDZHNGyxk52oN6uPsb+HWGMw0Ma0Bi9DkYG03ag3FY0txQVNa2wxCbn/eSArT3PSLeNGqT9uOoAmdGpm/8Y4STsRTzCMmwziu8xiyuSq1rb0Ajr2+UvbEDwzlEE1xE/zPBKpBmQb6lbEvPGp5KYG4YOja8SgZr+Lxt0uBcxwQ6aDMb4w5BIBP8Nq+j6jQyUicQNb3WflKb/F96dcx21/ATgGDTv5fhVUAAAAAElFTkSuQmCC" alt="PubMatic"></span>
  </div>
  <div class="form-title">DSP go-live configuration</div>

  <div class="two-col">
    <div class="field">
      <span class="section-label">Platform <span class="required">*</span></span>
      <div class="checkbox-group">
        <div class="checkbox-row">
          <input type="checkbox" id="plat-web" value="Web">
          <span class="cb-label">Web</span>
        </div>
        <div class="checkbox-row">
          <input type="checkbox" id="plat-mweb" value="Mobile Web">
          <span class="cb-label">Mobile Web</span>
        </div>
        <div class="checkbox-row">
          <input type="checkbox" id="plat-ios" value="Mobile App iOS">
          <span class="cb-label">Mobile App iOS</span>
        </div>
        <div class="checkbox-row">
          <input type="checkbox" id="plat-android" value="Mobile App Android">
          <span class="cb-label">Mobile App Android</span>
        </div>
        <div class="checkbox-row">
          <input type="checkbox" id="plat-ctv" value="CTV">
          <span class="cb-label">CTV</span>
        </div>
      </div>
    </div>

    <div class="field">
      <span class="section-label">Ad format <span class="required">*</span></span>
      <div class="checkbox-group">
        <div class="checkbox-row">
          <input type="checkbox" id="fmt-banner" value="Banner">
          <span class="cb-label">Banner</span>
        </div>
        <div class="checkbox-row">
          <input type="checkbox" id="fmt-video" value="Video">
          <span class="cb-label">Video</span>
        </div>
        <div class="checkbox-row">
          <input type="checkbox" id="fmt-native" value="Native">
          <span class="cb-label">Native</span>
        </div>
      </div>
    </div>
  </div>

  <div class="field">
    <span class="section-label">RTB API specification <span class="required">*</span></span>
    <div class="checkbox-group">
      <div class="checkbox-row">
        <input type="checkbox" id="rtb-21" value="PubMatic OpenRTB 2.1 API">
        <span class="cb-label">PubMatic OpenRTB 2.1 API</span>
      </div>
      <div class="checkbox-row">
        <input type="checkbox" id="rtb-23" value="PubMatic OpenRTB 2.3 API">
        <span class="cb-label">PubMatic OpenRTB 2.3 API</span>
      </div>
      <div class="checkbox-row">
        <input type="checkbox" id="rtb-25" value="PubMatic OpenRTB 2.5 API">
        <span class="cb-label">PubMatic OpenRTB 2.5 API</span>
      </div>
      <div class="checkbox-row">
        <input type="checkbox" id="rtb-26" value="PubMatic OpenRTB 2.6 API">
        <span class="cb-label">PubMatic OpenRTB 2.6 API</span>
      </div>
    </div>
  </div>

  <hr class="divider">

  <div class="field">
    <span class="section-label">Live environment data centers <span class="required">*</span></span>
    <div class="checkbox-group">
      <div class="checkbox-row">
        <input type="checkbox" id="dc-usw" onchange="toggleField('dc-usw','ep-usw'); toggleField('dc-usw','qps-usw')">
        <span class="cb-label">US-West</span>
        <input type="text" id="ep-usw" class="inline-input" placeholder="Live endpoint URL">
        <input type="text" id="qps-usw" class="inline-input qps-input" placeholder="QPS" oninput="this.value=this.value.replace(/[^0-9]/g,'')">
      </div>
      <div class="checkbox-row">
        <input type="checkbox" id="dc-use" onchange="toggleField('dc-use','ep-use'); toggleField('dc-use','qps-use')">
        <span class="cb-label">US-East</span>
        <input type="text" id="ep-use" class="inline-input" placeholder="Live endpoint URL">
        <input type="text" id="qps-use" class="inline-input qps-input" placeholder="QPS" oninput="this.value=this.value.replace(/[^0-9]/g,'')">
      </div>
      <div class="checkbox-row">
        <input type="checkbox" id="dc-eu" onchange="toggleField('dc-eu','ep-eu'); toggleField('dc-eu','qps-eu')">
        <span class="cb-label">Europe</span>
        <input type="text" id="ep-eu" class="inline-input" placeholder="Live endpoint URL">
        <input type="text" id="qps-eu" class="inline-input qps-input" placeholder="QPS" oninput="this.value=this.value.replace(/[^0-9]/g,'')">
      </div>
      <div class="checkbox-row">
        <input type="checkbox" id="dc-sg" onchange="toggleField('dc-sg','ep-sg'); toggleField('dc-sg','qps-sg')">
        <span class="cb-label">Singapore</span>
        <input type="text" id="ep-sg" class="inline-input" placeholder="Live endpoint URL">
        <input type="text" id="qps-sg" class="inline-input qps-input" placeholder="QPS" oninput="this.value=this.value.replace(/[^0-9]/g,'')">
      </div>
      <div class="checkbox-row">
        <input type="checkbox" id="dc-jp" onchange="toggleField('dc-jp','ep-jp'); toggleField('dc-jp','qps-jp')">
        <span class="cb-label">Japan</span>
        <input type="text" id="ep-jp" class="inline-input" placeholder="Live endpoint URL">
        <input type="text" id="qps-jp" class="inline-input qps-input" placeholder="QPS" oninput="this.value=this.value.replace(/[^0-9]/g,'')">
      </div>
    </div>
  </div>

  <button class="submit-btn" onclick="submitForm()">Submit live setup details →</button>
</div>

<script>
function toggleField(cbId, fieldId) {
  const cb = document.getElementById(cbId);
  const f = document.getElementById(fieldId);
  if (cb.checked) { f.classList.add('active'); }
  else { f.classList.remove('active'); f.value = ''; }
}
function submitForm() {
  const platforms = ['plat-web', 'plat-mweb', 'plat-ios', 'plat-android', 'plat-ctv']
    .filter(id => document.getElementById(id).checked)
    .map(id => document.getElementById(id).value);
    
  const formats = ['fmt-banner', 'fmt-video', 'fmt-native']
    .filter(id => document.getElementById(id).checked)
    .map(id => document.getElementById(id).value);
    
  const rtbSpecs = ['rtb-21', 'rtb-23', 'rtb-25', 'rtb-26']
    .filter(id => document.getElementById(id).checked)
    .map(id => document.getElementById(id).value);

  const dcMap = { 'dc-usw': { name: 'US-West', epId: 'ep-usw', qpsId: 'qps-usw' }, 'dc-use': { name: 'US-East', epId: 'ep-use', qpsId: 'qps-use' }, 'dc-eu': { name: 'Europe', epId: 'ep-eu', qpsId: 'qps-eu' }, 'dc-sg': { name: 'Singapore', epId: 'ep-sg', qpsId: 'qps-sg' }, 'dc-jp': { name: 'Japan', epId: 'ep-jp', qpsId: 'qps-jp' } };
  const dcs = Object.entries(dcMap)
    .filter(([id]) => document.getElementById(id).checked)
    .map(([id, meta]) => ({ dc: meta.name, endpoint: document.getElementById(meta.epId).value.trim(), qps: document.getElementById(meta.qpsId).value.trim() || null }));

  const data = { 
    platforms,
    formats,
    rtbSpecs,
    dcsSupported: dcs
  };
  
  sendPrompt('DSP_LIVE_SETUP_SUBMISSION:' + JSON.stringify(data));
}
</script>
```

---

## Step 2 — Handle the submission

When the next message starts with `DSP_LIVE_SETUP_SUBMISSION:`, parse the JSON payload. Then:

**Validate** — flag any of the following as errors and ask the DSP to correct and resubmit:
- `platforms` array is empty
- `formats` array is empty
- `rtbSpecs` array is empty
- `dcsSupported` array is empty
- Any selected DC is missing its endpoint URL
- Any selected DC is missing its QPS value

**Confirm** — if valid, respond with a clean summary:

> ✅ **Live Setup Details Received**
> - **Platforms:** Web, Mobile App iOS
> - **Ad Formats:** Banner, Video
> - **RTB Specs:** PubMatic OpenRTB 2.5 API
> - **Live DCs:** US-West (`https://live-usw.bidder.example.com`, 8000 QPS), Europe (`https://live-eu.bidder.example.com`, 5000 QPS)
>
> Your live campaign details have been recorded and sent to your Solutions Engineer for final activation.

*(Note: Currently this just records the details in the chat. In the future, this will call an MCP tool to save the live config.)*
