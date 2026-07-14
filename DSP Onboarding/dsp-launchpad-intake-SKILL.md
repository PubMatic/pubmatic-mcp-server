---
name: dsp-launchpad-intake
description: "This is the main skill used for DSP onboarding. DSP Launchpad intake form — collects all technical onboarding details from a demand-side platform (DSP). Use this skill whenever a DSP wants to onboard, integrate, register, or set up with PubMatic, or whenever someone submits RTB/bidder details, endpoint URLs, DC preferences, platform/ad-format support, or timeout configuration. Also trigger when a user pastes or summarizes a DSP's message containing any of those details, even informally. Pre-populate the form from whatever is already in the message, then prompt for the rest."
---

# DSP Launchpad Intake Form

This is the primary skill for DSP onboarding. It provides a **two-stage process**:

**Stage 1 (This Skill):** Interactive HTML form widget to collect DSP details with a user-friendly interface
**Stage 2 (MCP Backend):** AI-powered request generation, integration testing, and automatic SE approval submission

Your job is to collect all required onboarding details from the DSP using the interactive form widget, then automatically trigger the AI-powered backend processing. Follow the three steps below.

---

## Step 1 — Welcome & Introduction

**Welcome to PubMatic's DSP Onboarding Platform!**

Thank you for choosing PubMatic as your programmatic advertising partner. We're excited to help you integrate your Demand-Side Platform (DSP) with our premium supply ecosystem.

**What happens during onboarding:**
- **Technical Integration**: We'll configure your DSP endpoint for optimal bid request delivery across our global data centers
- **Integration Testing**: Our AI-powered system will run comprehensive integration and response validation tests  
- **Quality Assurance**: Each ad format and platform combination will be verified to ensure seamless campaign execution
- **Solutions Engineer Review**: Our technical team will review all test results before activating your integration

This streamlined process typically takes 15-30 minutes to complete the initial setup, with technical validation running automatically in the background. Let's get started!

---

## Step 2 — Render the intake form

Call `show_widget` with the HTML template below. Replace every `%%PREFILL_*%%` placeholder with the extracted value (or an empty string if nothing was found). The PubMatic logo is embedded directly in the template as a small base64 PNG (~2KB) — this is deliberate: the skill needs to work as a single self-contained file that can be shared with clients without extra assets to lose track of, so don't split it into a separate file even though that's normally better practice. The form uses `sendPrompt` on submission, so when the DSP fills it in and clicks Submit, their answers come back to you as a JSON string in the next message.

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
  input[type="text"], input[type="email"] { width: 100%; padding: 9px 12px; background: var(--surface-2); border: 0.5px solid var(--border); border-radius: var(--radius, 7px); color: var(--text-primary); font-size: 14px; outline: none; transition: border-color 0.15s; }
  input[type="text"]:focus, input[type="email"]:focus { border-color: var(--border-accent); box-shadow: 0 0 0 3px var(--bg-accent); }
  .section-label { font-size: 13px; font-weight: 500; color: var(--text-secondary); margin-bottom: 10px; display: block; letter-spacing: 0.03em; }
  .checkbox-group { display: flex; flex-direction: column; gap: 8px; }
  .checkbox-row { display: flex; align-items: center; gap: 10px; }
  .checkbox-row input[type="checkbox"] { width: 16px; height: 16px; accent-color: var(--text-accent); cursor: pointer; flex-shrink: 0; }
  .checkbox-row .cb-label { font-size: 14px; color: var(--text-primary); min-width: 110px; }
  .inline-input { flex: 1; padding: 6px 10px; background: var(--surface-2); border: 0.5px solid var(--border); border-radius: 6px; color: var(--text-primary); font-size: 13px; outline: none; opacity: 0.4; pointer-events: none; transition: opacity 0.15s, border-color 0.15s; }
  .inline-input.active { opacity: 1; pointer-events: auto; }
  .inline-input.active:focus { border-color: var(--border-accent); box-shadow: 0 0 0 3px var(--bg-accent); }
  .divider { border: none; border-top: 0.5px solid var(--border); margin: 20px 0; }
  .required { color: var(--text-danger); margin-left: 2px; }
  .submit-btn { width: 100%; padding: 11px; background: var(--fill-primary, var(--text-primary)); border: none; border-radius: var(--radius, 8px); color: var(--on-primary, var(--surface-0)); font-size: 15px; font-weight: 500; cursor: pointer; margin-top: 4px; transition: opacity 0.15s; }
  .submit-btn:hover { opacity: 0.88; }
</style>

<div class="form-card">
  <div class="brand-row">
    <span class="brand-chip"><img src="data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAM0AAAAeCAMAAAC4yGraAAAAflBMVEVMyO0BBAQXcHBl4/UAAAAAAABMyO5MyO5MtudUqaoN8vkzqax7f/slMn8ob7I2qNlfX19VVaoAAP8AagD///8Af/9/AH8AAABMyO4AAABR1PsAAAAAAAAAAABMyO5LxusAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAACM0xdjAAAAIHRSTlOjLAMLTNDTUhEDAgUCAwQIAgMBAgECAgH8/P6tdI9wKwYU5O8AAATPSURBVHjarZjrYqMqEIBFQNCkSbu752AE4vu/5XIZYPDWxO38aUS08zF3m+ZIpGpVklbN9U0xK3R7IbB7Vh+LG0RHsWWJwRJRLwnhD7tzqxn3ZRpn1eedVD2n6u7UNVTddt57V43bPT1XvPYBUnTnsGIPCKzN/H6reZ9mdDR0l8YDdbP6b/u9l0TT79EUhdKK3qcx5Ql2sPU7GuxpQDMFydZrj2l2bZMtwV6gsT9N0wNNF2WconXuQ3uOhlfn/rptlHY/2TmafkUzD3IYBinik5NY+dKLNDlw9Js0yliifipupPofHvWXU+P0/dP3NGvdUkqHQnOhtHdyrWg0R+frf+vXPe1I3ve0ebi1TvpBdmEP3cnQkSbfbVukl9UlcIj3OvuObX6SRkIJiafv91xmIYRUv/3qh5LuYi62cS7Zdc1TKvWJbGNK4PiftqZhVnPOtQXrEcai7Qgj8RKFTdirwffe9zSqotcMQCOUAL396pW61ckbLNKIlAJdbaKFxhvkgYIa0xieQyuaA13zaMucEEsUhtr7Ok2fab6ibYZE49dd/NwCIu2m8GBk7VBtosHQoPcjB47XlSAa/cCiQf0kVYYmHN9iZ3Ja8rQ2exrQkLBY01Slll4/Mk0OnBA2qtDYRy1mn4YstpIT1VP+illA0bhH1jRyQTO5AgU4wXygt0kqhbApNATcxolJxrE65MAH19pgmmQZzpMbnokbuI7qNirRtBue5u7PdKDPcjigN0tpwIbzzzQGBRApZWmrszEltEh0T3aiekrpKgot1TPRfG7Yxi0HEWOqTaA3SYETwqbQ2MeiEu3TcFyDY9I70aflDjsoKNuY03Y8jfo600K+7u6ZJuhi4PwVihtjrIG8bA9tQ6reNV69b5tlEy0TTbvOArCq+kFAxsh62/iHlStUPZnRvGqANmhM1ez5mcGyf54IrhdMs4ib6TmE4/hS87iggcCJYaP26s0BzVb78L5tpimNBN3TT2uX2jaVp7moukQvpSnILHYUAmGDVGN8lXe3afTGgPd+3KRB+inuysfKUdw49dv4rFzSQOBAT5BXWSn72vCfpuk3eugstzb0awLntNrTxK9gm+va08IPS3AqK4mK29CRfU+j/3UimOVVSp+lrwN0n0DjL+mQ1cZZgK6zQKyfBs4XR1NJVPzbuEFZwBhDzvfQtQdOTXtxDcIlIac+7e6yhPpIGVqqRdVPc47dDO1DGvbApSnuPdHZLGhuKp+7k7nDtvGttbpf2uhouHqixoTs0bDH99WTE9RM8/MTQZmZQ6EfO0HlLLqxohnHMK+JxPiF9NXo+0BFA/WdHec02MtZKDbRQ89PBEmuKg6hob2cxiXN1DVNN2bT4KqPvt3UccON6zn1Nxk6G9c1o692nf3K0+jy8+UtN/8TerAswucqNxF8VpWFPIrn28S1rDZHNGyxk52oN6uPsb+HWGMw0Ma0Bi9DkYG03ag3FY0txQVNa2wxCbn/eSArT3PSLeNGqT9uOoAmdGpm/8Y4STsRTzCMmwziu8xiyuSq1rb0Ajr2+UvbEDwzlEE1xE/zPBKpBmQb6lbEvPGp5KYG4YOja8SgZr+Lxt0uBcxwQ6aDMb4w5BIBP8Nq+j6jQyUicQNb3WflKb/F96dcx21/ATgGDTv5fhVUAAAAAElFTkSuQmCC" alt="PubMatic"></span>
  </div>
  <div class="form-title">DSP Launchpad intake</div>

  <div class="field">
    <label>DSP name <span class="required">*</span></label>
    <input type="text" id="dspName" placeholder="e.g. Acme DSP" value="%%PREFILL_DSP_NAME%%">
  </div>

  <div class="field">
    <label>DSP email <span class="required">*</span></label>
    <input type="email" id="dspEmail" placeholder="e.g. acme-test@pubmatic.com" value="%%PREFILL_DSP_EMAIL%%">
    <p class="help">Email created by PubMatic SE</p>
  </div>

  <div class="field">
    <label>PubMatic DSP ID <span class="required">*</span></label>
    <input type="text" id="dspId" placeholder="e.g. 12345" value="%%PREFILL_DSP_ID%%">
    <p class="help">The DSP ID assigned by PubMatic (provided by your SE)</p>
  </div>


  <hr class="divider">

  <div class="field">
    <span class="section-label">DCs supported <span class="required">*</span></span>
    <div class="checkbox-group">
      <div class="checkbox-row">
        <input type="checkbox" id="dc-usw" onchange="toggleField('dc-usw','ep-usw')" %%PREFILL_DC_USW_CHECKED%%>
        <span class="cb-label">US-West</span>
        <input type="text" id="ep-usw" class="inline-input %%PREFILL_DC_USW_ACTIVE%%" placeholder="Override endpoint (optional)" value="%%PREFILL_EP_USW%%">
      </div>
      <div class="checkbox-row">
        <input type="checkbox" id="dc-use" onchange="toggleField('dc-use','ep-use')" %%PREFILL_DC_USE_CHECKED%%>
        <span class="cb-label">US-East</span>
        <input type="text" id="ep-use" class="inline-input %%PREFILL_DC_USE_ACTIVE%%" placeholder="Override endpoint (optional)" value="%%PREFILL_EP_USE%%">
      </div>
      <div class="checkbox-row">
        <input type="checkbox" id="dc-eu" onchange="toggleField('dc-eu','ep-eu')" %%PREFILL_DC_EU_CHECKED%%>
        <span class="cb-label">Europe</span>
        <input type="text" id="ep-eu" class="inline-input %%PREFILL_DC_EU_ACTIVE%%" placeholder="Override endpoint (optional)" value="%%PREFILL_EP_EU%%">
      </div>
      <div class="checkbox-row">
        <input type="checkbox" id="dc-sg" onchange="toggleField('dc-sg','ep-sg')" %%PREFILL_DC_SG_CHECKED%%>
        <span class="cb-label">Singapore</span>
        <input type="text" id="ep-sg" class="inline-input %%PREFILL_DC_SG_ACTIVE%%" placeholder="Override endpoint (optional)" value="%%PREFILL_EP_SG%%">
      </div>
      <div class="checkbox-row">
        <input type="checkbox" id="dc-jp" onchange="toggleField('dc-jp','ep-jp')" %%PREFILL_DC_JP_CHECKED%%>
        <span class="cb-label">Japan</span>
        <input type="text" id="ep-jp" class="inline-input %%PREFILL_DC_JP_ACTIVE%%" placeholder="Override endpoint (optional)" value="%%PREFILL_EP_JP%%">
      </div>
    </div>
  </div>

  <div class="field">
    <span class="section-label">Ad formats <span class="required">*</span></span>
    <div class="checkbox-group">
      <div class="checkbox-row">
        <input type="checkbox" id="fmt-banner" onchange="toggleFieldWithJSON('fmt-banner','req-banner','banner')" %%PREFILL_FMT_BANNER_CHECKED%%>
        <span class="cb-label">Banner</span>
        <input type="text" id="req-banner" class="inline-input %%PREFILL_FMT_BANNER_ACTIVE%%" placeholder="Sample request JSON (optional)" value="%%PREFILL_REQ_BANNER%%">
      </div>
      <div class="checkbox-row">
        <input type="checkbox" id="fmt-video" onchange="toggleFieldWithJSON('fmt-video','req-video','video')" %%PREFILL_FMT_VIDEO_CHECKED%%>
        <span class="cb-label">Video</span>
        <input type="text" id="req-video" class="inline-input %%PREFILL_FMT_VIDEO_ACTIVE%%" placeholder="Sample request JSON (optional)" value="%%PREFILL_REQ_VIDEO%%">
      </div>
      <div class="checkbox-row">
        <input type="checkbox" id="fmt-native" onchange="toggleFieldWithJSON('fmt-native','req-native','native')" %%PREFILL_FMT_NATIVE_CHECKED%%>
        <span class="cb-label">Native</span>
        <input type="text" id="req-native" class="inline-input %%PREFILL_FMT_NATIVE_ACTIVE%%" placeholder="Sample request JSON (optional)" value="%%PREFILL_REQ_NATIVE%%">
      </div>
    </div>
  </div>

  <hr class="divider">

  <div class="field">
    <label>Timeout (ms)</label>
    <input type="text" id="timeout" placeholder="e.g. 150" value="%%PREFILL_TIMEOUT%%" style="max-width: 160px;" oninput="this.value=this.value.replace(/[^0-9]/g,'')">
  </div>

  <button class="submit-btn" onclick="submitForm()">Submit onboarding details →</button>
</div>

<script>
const DEFAULT_JSONS = {
  'banner': '{"id":"0B0AAA76-6F68-409A-AEEE-8DA01C140224B","at":1,"tmax":386,"imp":[{"id":"1","tagid":"1952438","bidfloor":0.26213,"secure":1,"banner":{"w":300,"h":250,"format":[{"w":300,"h":250},{"w":250,"h":250},{"w":320,"h":100}],"topframe":0,"battr":[1,2,6,7,8,9,10,14],"mimes":["text/html"]},"ext":{"headerbidding":{"present":1}}}],"site":{"id":"551452","cat":["IAB17","IAB12-1","IAB12","IAB1-5","IAB1"],"page":"https://www.espn.com/nba/boxscore/_/gameId/401810752","domain":"espn.com","mobile":1,"publisher":{"id":"156307","cat":["IAB12"]},"content":{"title":"Hawks vs. Bucks (Mar 4, 2026) Box Score - ESPN","gtax":9}},"device":{"ip":"226.129.60.253","lmt":0,"ua":"Mozilla/5.0 (Linux; Android 16.0.0; SM-S901U) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/145.0.7632.120 Mobile Safari/537.36","language":"en","model":"SM-S901U","make":"Samsung","os":"Android","osv":"16.0.0","js":1,"connectiontype":1,"devicetype":4,"ifa":"29630edf-ddfa-457b-a34e-6c6f1ebabe85","geo":{"lat":44.18,"lon":-88.489998,"type":2,"city":"neenah","metro":"658","zip":"54956","country":"US","region":"WI","utcoffset":0},"geofetch":0,"hwv":"SM-S901U","ext":{"res":"-1x-1","freq":0,"pf":2}},"user":{"id":"748B7403-3280-4D0C-A350-A37A34C8B825","buyeruid":"uid:BAC0B231F57140B2804C164AA51FDABC","eids":[{"source":"adserver.org","uids":[{"id":"cd37d1d9-750c-4c15-9c44-e70944e8b838","ext":{"rtiPartner":"TDID"}}]}],"ext":{"eids":[{"source":"adserver.org","uids":[{"id":"cd37d1d9-750c-4c15-9c44-e70944e8b838","ext":{"rtiPartner":"TDID"}}]}]}},"bcat":["IAB17-18","IAB25","IAB26","IAB7-39","IAB9-9"],"regs":{"gpp":"DBABLA~BVQqAAAAAAJY.QA","gpp_sid":[7],"us_privacy":"1YNY","ext":{"us_privacy":"1YNY","gpp":"DBABLA~BVQqAAAAAAJY.QA","gpp_sid":[7]}},"source":{"fd":1,"pchain":"-5d62403b186f2ace:156307","schain":{"complete":1,"ver":"1.0","nodes":[{"asi":"taboola.com","sid":"1201218","rid":"4192990604869467338","hp":1},{"asi":"pubmatic.com","sid":"156307","rid":"0B0AAA76-6F68-409A-AEEE-8DA01C140224B","hp":1}]},"ext":{"schain":{"complete":1,"ver":"1.0","nodes":[{"asi":"taboola.com","sid":"1201218","rid":"4192990604869467338","hp":1},{"asi":"pubmatic.com","sid":"156307","rid":"0B0AAA76-6F68-409A-AEEE-8DA01C140224B","hp":1}]}}}}',
  'video': '{"id":"B74838BF-9B41-4D4D-AE28-4A427567ABA6M","at":1,"tmax":400,"imp":[{"id":"1","tagid":"5375001","displaymanager":"Nimbus","displaymanagerver":"2.33.2","bidfloor":0.707317,"secure":1,"video":{"mimes":["video/mp4"],"linearity":1,"placement":2,"plcmt":4,"minduration":1,"maxduration":30,"skip":0,"protocols":[1,2,3,4,5,6,7,8,11,12,13,14],"startdelay":0,"battr":[1,2,3,4,5,6,8,9,10,11,13,14,17],"boxingallowed":1,"playbackmethod":[2],"api":[3,5,6,7],"h":250,"w":300,"delivery":[2,3],"pos":0,"ext":{"ploc":"-1x-1","skip":0,"bidfloor":0.707317}},"banner":{"w":300,"h":250,"topframe":1,"battr":[1,2,3,4,5,6,8,9,10,11,13,14,17],"api":[3,5,6,7],"ext":{"bidfloor":0.707317}},"pmp":{"private_auction":0,"deals":[{"id":"PM-OYGV-7406","bidfloor":1,"wseat":["1"],"at":1}]},"ext":{"headerbidding":{"present":1},"tid":"8607295e-eb64-444d-a580-1238f86301fd/adsbynimbus"}}],"app":{"id":"jp.gocro.smartnews.android","name":"SmartNews","ver":"26.3.10","bundle":"jp.gocro.smartnews.android","domain":"https://www.smartnews.com","privacypolicy":1,"storeurl":"https://play.google.com/store/apps/details?id=jp.gocro.smartnews.android","publisher":{"id":"163743"},"ext":{"pmid":"1110600"}},"device":{"ip":"73.117.204.81","lmt":0,"ua":"Mozilla/5.0 (Linux; Android 16; SM-S906U Build/BP2A.250605.031.A3; wv) AppleWebKit/537.36 (KHTML, like Gecko) Version/4.0 Chrome/145.0.7632.120 Mobile Safari/537.36","language":"en","model":"SM-S906U","make":"samsung","os":"android","osv":"16.0.0","js":1,"connectiontype":2,"devicetype":4,"ifa":"3b56274c-e718-4d86-90ff-70764d0a2c2b","geo":{"lat":39.440899,"lon":-78.9739,"type":1,"city":"Keyser","metro":"511","country":"USA","region":"WV","utcoffset":0},"h":2340,"w":1080,"geofetch":0,"ext":{"res":"-1x-1","freq":0,"pf":5}},"regs":{"us_privacy":"1YNN","ext":{"us_privacy":"1YNN"}},"source":{"fd":1,"pchain":"5d62403b186f2ace:163743","schain":{"complete":1,"ver":"1.0","nodes":[{"asi":"pubmatic.com","sid":"163743","rid":"B74838BF-9B41-4D4D-AE28-4A427567ABA6M","hp":1}]},"ext":{"omidpn":"Adsbynimbus","omidpv":"2.33.2","schain":{"complete":1,"ver":"1.0","nodes":[{"asi":"pubmatic.com","sid":"163743","rid":"B74838BF-9B41-4D4D-AE28-4A427567ABA6M","hp":1}]}}}}',
  'native': '{"id":"cb8f655a-68c7-46b0-8e15-a3e4ed671a89","at":1,"tmax":260,"imp":[{"id":"1","tagid":"/ntv/1087872/WSB-TV_Android_App_Home_2","bidfloor":1.15,"secure":1,"exp":2400,"native":{"request":"{ \\"ver\\": \\"1.2\\", \\"plcmttype\\": 1, \\"plcmtcnt\\": 1, \\"assets\\": [ { \\"id\\": 0, \\"required\\": 1, \\"title\\": { \\"len\\": 60 } }, { \\"id\\": 1, \\"required\\": 0, \\"img\\": { \\"type\\": 1, \\"wmin\\": 120, \\"hmin\\": 45 } }, { \\"id\\": 2, \\"required\\": 0, \\"img\\": { \\"type\\": 2, \\"wmin\\": 120, \\"hmin\\": 45 } }, { \\"id\\": 3, \\"required\\": 1, \\"img\\": { \\"type\\": 3, \\"wmin\\": 300, \\"hmin\\": 169 } }, { \\"id\\": 4, \\"required\\": 1, \\"data\\": { \\"type\\": 1, \\"len\\": 90 } }, { \\"id\\": 6, \\"required\\": 0, \\"data\\": { \\"type\\": 2, \\"len\\": 120 } } ], \\"context\\": 1, \\"eventtrackers\\": [ { \\"event\\": 1, \\"methods\\": [ 1, 2 ] }, { \\"event\\": 2, \\"methods\\": [ 1, 2 ] }, { \\"event\\": 4, \\"methods\\": [ 1 ] }, { \\"event\\": 555, \\"methods\\": [ 2 ] } ], \\"privacy\\": 1 }","ver":"1.2"},"pmp":{"private_auction":1,"deals":[{"id":"PM-HLJU-5001","bidfloor":2.25,"wseat":["1427"],"at":3}]},"metric":[{"type":"viewability","value":0.8624,"vendor":"nativo"}],"ext":{"headerbidding":{"present":1},"gpid":"/ntv/1087872/WSB-TV_Android_App_Home_2"}}],"app":{"id":"12413","name":"WSB-TV News","ver":"8.8.10","bundle":"com.cmgdigital.wsbtvhandset","domain":"http://www.nativo.com","cat":["IAB12"],"pagecat":["IAB12"],"privacypolicy":0,"paid":0,"storeurl":"https://play.google.com/store/apps/details?id=com.cmgdigital.wsbtvhandset","publisher":{"id":"156500","name":"Nativo, Inc.","cat":["IAB12"]},"ext":{"pmid":"220138"}},"device":{"ip":"172.56.99.107","lmt":0,"ua":"Mozilla/5.0 (Linux; Android 14; SM-G991U Build/UP1A.231005.007; wv) AppleWebKit/537.36 (KHTML, like Gecko) Version/4.0 Chrome/141.0.7390.43 Mobile Safari/537.36_Nativo_SDK_UA","carrier":"t-mobile","language":"en","model":"SM-G991U","make":"Samsung","os":"Android","osv":"14.0","js":1,"devicetype":4,"geo":{"country":"USA","region":"fl","city":"seminole","metro":"539","lat":28.16,"lon":-82.519997,"type":2,"zip":"33776"},"geofetch":0,"ext":{"res":"-1x-1","freq":0,"pf":5}},"user":{"geo":{"country":"USA","region":"FL","city":"Lutz","zip":"33558","metro":"42"}},"bseat":["3055","54","4750"],"bcat":["IAB1-7","IAB11","IAB11-2"],"badv":["actualidad.rt.com","burrforsenate.com","clubw.com"],"regs":{"us_privacy":"1YNY","ext":{"us_privacy":"1YNY"}},"source":{"fd":1,"pchain":"59521ca7cc5e9fee:12413-5d62403b186f2ace:156500","tid":"8888efa3-05c6-4483-8da8-8a81ccecabd7","schain":{"complete":1,"ver":"1.0","nodes":[{"asi":"nativo.com","sid":"4845","rid":"a41afb82-f6ff-4597-91fa-cd637e53bbe5","hp":1},{"asi":"pubmatic.com","sid":"156500","rid":"9F32A8B6-5E49-4EB3-A37B-3607174A08BDN","hp":1}]},"ext":{"omidpn":"ntv_sdk","omidpv":"60006","schain":{"complete":1,"ver":"1.0","nodes":[{"asi":"nativo.com","sid":"4845","rid":"a41afb82-f6ff-4597-91fa-cd637e53bbe5","hp":1},{"asi":"pubmatic.com","sid":"156500","rid":"9F32A8B6-5E49-4EB3-A37B-3607174A08BDN","hp":1}]}}}}'
};

function toggleField(cbId, fieldId) {
  const cb = document.getElementById(cbId);
  const f = document.getElementById(fieldId);
  if (cb.checked) { f.classList.add('active'); }
  else { f.classList.remove('active'); f.value = ''; }
}

function toggleFieldWithJSON(cbId, fieldId, formatType) {
  const cb = document.getElementById(cbId);
  const f = document.getElementById(fieldId);
  if (cb.checked) { 
    f.classList.add('active'); 
    if (!f.value && DEFAULT_JSONS[formatType]) {
      f.value = DEFAULT_JSONS[formatType];
    }
  } else { 
    f.classList.remove('active'); 
    f.value = ''; 
  }
}

function submitForm() {
  const dcMap = { 'dc-usw': { name: 'US-West', epId: 'ep-usw' }, 'dc-use': { name: 'US-East', epId: 'ep-use' }, 'dc-eu': { name: 'Europe', epId: 'ep-eu' }, 'dc-sg': { name: 'Singapore', epId: 'ep-sg' }, 'dc-jp': { name: 'Japan', epId: 'ep-jp' } };
  const dcs = Object.entries(dcMap).filter(([id]) => document.getElementById(id).checked).map(([id, meta]) => ({ dc: meta.name, overrideEndpoint: document.getElementById(meta.epId).value.trim() || null }));
  const formatMap = { 'fmt-banner': { name: 'Banner', reqId: 'req-banner' }, 'fmt-video': { name: 'Video', reqId: 'req-video' }, 'fmt-native': { name: 'Native', reqId: 'req-native' } };
  const adFormats = Object.entries(formatMap).filter(([id]) => document.getElementById(id).checked).map(([id, meta]) => ({ format: meta.name, sampleRequest: document.getElementById(meta.reqId).value.trim() || null }));
  const data = { 
    dspName: document.getElementById('dspName').value.trim(), 
    dspEmail: document.getElementById('dspEmail').value.trim(), 
    dspId: document.getElementById('dspId').value.trim(), 
    dcsSupported: dcs, 
    adFormats, 
    timeoutMs: document.getElementById('timeout').value.trim() || null
  };
  sendPrompt('DSP_INTAKE_SUBMISSION:' + JSON.stringify(data));
}
</script>
```

---

## Step 3 — Handle the submission

When the next message starts with `DSP_INTAKE_SUBMISSION:`, parse the JSON payload. Then:

**Validate** — flag any of the following as errors and ask the DSP to correct and resubmit:
- `dspName` is empty
- `dspEmail` is empty or not a valid email
- `dspId` is empty
- `dcsSupported` array is empty (at least one DC must be selected)
- `adFormats` array is empty (at least one ad format must be selected)

**Confirm** — if valid, respond with a clean summary:

> ✅ **Intake received for [DSP Name]**
> - **Email:** …
> - **DSP ID:** …
> - **DCs:** US-West (default), Europe (`https://eu.bidder.example.com`)
> - **Ad Formats:** Banner (sample request provided), Video, Native
> - **Timeout:** 150 ms

**Submit to AI-Powered Integration Testing** — after confirming, immediately call the MCP tool:

The `submit_dsp_details` tool accepts only ONE `custom_samples` string per call — it has no way to carry multiple per-format payloads in a single request. Do not attempt to merge or encode multiple samples into one JSON blob; there is no evidence the backend test harness supports that, and a malformed guess here produces a misleading "test ran" result that is actually testing nothing.

**If only one entry in `data.adFormats` has a non-null `sampleRequest`** (or only one ad format was selected), submit once:

```
Call: dsp-onboarding:submit_dsp_details with:
- dsp_company_name: data.dspName
- contact_email: data.dspEmail
- pubmatic_dsp_id: data.dspId
- dsp_bid_endpoint_url: data.dcsSupported[0].overrideEndpoint or "https://default-endpoint.example.com"
- campaign_platforms: "Web, Mobile, CTV"
- campaign_ad_formats: data.adFormats.map(f => f.format).join(", ")
- infrastructure_data_centers: data.dcsSupported[0].dc
- num_requests: 5
- custom_samples: the exact, unmodified string from data.adFormats[0].sampleRequest (if provided). Do NOT trim, summarize, re-serialize, strip fields, or otherwise edit this JSON in any way — pass the raw string through byte-for-byte. If it is null/absent, omit the parameter entirely rather than fabricating a payload.
```

NOTE — testing_max_budget, testing_qps, reporting_currency_id, and reporting_timezone_id are intentionally omitted above (as of 2026-07-10, decided by Mayyur). They are optional per the tool schema and the call succeeds without them. However, a live test found that omitting them changed a 0%-success submission (all requests returned 204 no-bid) from a "blocked" result to a plain "success" / ready-for-SE-approval result — a single test, not confirmed as causal, but not yet ruled out either. If SE-review submissions start looking artificially clean despite real bid failures, reintroduce these fields as the first thing to check.

**If two or more entries in `data.adFormats` have a non-null `sampleRequest`**, submit one separate `submit_dsp_details` call PER format that has a sample, back to back:

```
For each format f in data.adFormats where f.sampleRequest is not null:
  Call: dsp-onboarding:submit_dsp_details with:
  - dsp_company_name: data.dspName
  - contact_email: data.dspEmail
  - pubmatic_dsp_id: data.dspId
  - dsp_bid_endpoint_url: data.dcsSupported[0].overrideEndpoint or "https://default-endpoint.example.com"
  - campaign_platforms: "Web, Mobile, CTV"
  - campaign_ad_formats: f.format   (single format for this call, not the joined list)
  - infrastructure_data_centers: data.dcsSupported[0].dc
  - num_requests: 5
  - custom_samples: the exact, unmodified string from f.sampleRequest — byte-for-byte, no edits
```
(testing_max_budget, testing_qps, reporting_currency_id, reporting_timezone_id intentionally omitted here too — see NOTE above.)

Each call returns its own session ID and its own `html_results`. Do NOT present these as separate files. Instead:

1. **Prefer a structured field if the tool ever returns one** — check the raw tool result for `success_rate`, `successful_requests`, and `total_requests` (or similarly named fields) before falling back to HTML parsing. If present, use them directly and skip steps 1b/1c below.
1b. **Fallback: extract the success rate from `html_results`.** There is no structured `success_rate` field on the tool result today — it only exists as rendered text. For each call's `html_results`, find the stat card whose label is exactly "Success Rate":
   ```
   <div class="dsp-stat">
       <div class="dsp-stat-value">0.0%</div>
       <div class="dsp-stat-label">Success Rate</div>
   </div>
   ```
   Read the `.dsp-stat-value` text immediately paired with that label, strip the `%`, and parse it as a number (e.g. `"0.0%"` → `0.0`, `"80.0%"` → `80.0`).
   Do NOT infer the rate from anything else (badge colors, session status text, etc.) — only this specific stat card.
1c. **Cross-check the parsed stat-card rate against the row badges** in that call's "Detailed Test Results" table: count rows whose badge is `NO BID` / `ERROR` / `TIMEOUT` vs. rows with a valid-bid badge, and compute `row_success_pct = 100 * valid_bid_rows / total_rows`. If `row_success_pct` and the stat-card percentage disagree by more than a couple of percentage points, treat the parse as UNRELIABLE for that call — do not use either number, flag it, and stop before making any pass/fail decision (see refusal rule below). This exists because a single string-slice on rendered HTML is fragile; the two signals should agree if parsing is correct.
2. **Get the actual request count for that call** by counting the `<tr>` rows in that call's "Detailed Test Results" table, not by trusting the `num_requests` value that was sent — the tool may run a different number than requested. Then `successful_requests_this_call = round(success_rate_pct / 100 * total_requests_this_call)`.
3. **Compute the aggregate**: `aggregate_pct = 100 * (sum of successful_requests_this_call across all calls) / (sum of total_requests_this_call across all calls)`.
4. **Build ONE combined file** at `/mnt/user-data/outputs/dsp_test_results.html`:
   - A summary section at the top: DSP name, list of formats tested, per-format pass rate, and the aggregate pass rate with the >50% threshold shown explicitly (e.g. "Aggregate: 3/10 = 30% — below 50% threshold, not proceeding to live setup").
   - Each format's original `html_results` content stacked below the summary, in the order the formats were submitted, each still showing its own session ID.
5. `create_file` this combined content, then `present_files` — one file, not one per format.

**Decision rule:** if any call's success rate was flagged UNRELIABLE in step 1c, STOP — do not compute an aggregate, do not say the congratulations line, do not proceed to live setup. Tell the user parsing was unreliable for that format's result and show them both the stat-card number and the row-count number so they can judge manually. Otherwise: if `aggregate > 50%`, treat this submission as passed: say exactly "Congratulations !!! Integration tests has been passed successfully. Next Step would be to provide live setup details. These details will be needed to setup campaigns on live environment", then immediately use the `dsp-live-setup` skill, passing the DSP ID into `%%PREFILL_DSP_ID%%`. If `aggregate <= 50%`, do not say the congratulations line and do not proceed to live setup — report the aggregate and per-format numbers plainly and let the user decide whether to fix something and resubmit. This aggregate rule applies only when the per-format loop (2+ samples) ran; the single-call case keeps using the tool's own `status` field as before.

**Handle the Result (single-call case only — see aggregate decision rule above for the multi-format loop)** — after the tool returns:
- If `status` is `"error"` and mentions the user is not registered, politely ask the user to get registered with PubMatic SE for further onboarding process.
- **Render the dashboard** — If the tool returns a success or blocked status and includes `html_results` (an HTML string), you MUST create a file artifact using `create_file` saved to `/mnt/user-data/outputs/dsp_test_results.html` and then call `present_files` to share it. Do NOT use `show_widget` for this output.
- If `status` is `"success"`, say exactly: "Congratulations !!! Integration tests has been passed successfully. Next Step would be to provide live setup details. These details will be needed to setup campaigns on live environment". Then immediately use the `dsp-live-setup` skill to collect the live setup details, making sure to pass the DSP ID you collected earlier into the `%%PREFILL_DSP_ID%%` placeholder.

---

## Pre-fill placeholder reference

| Placeholder | Replace with |
|---|---|
| `%%PREFILL_DSP_NAME%%` | Extracted DSP name, or `""` |
| `%%PREFILL_DSP_EMAIL%%` | Extracted email, or `""` |
| `%%PREFILL_DSP_ID%%` | Extracted DSP ID, or `""` |
| `%%PREFILL_DC_USW_CHECKED%%` | `checked` if US-West mentioned, else `""` |
| `%%PREFILL_DC_USW_ACTIVE%%` | `active` if US-West has override endpoint, else `""` |
| `%%PREFILL_EP_USW%%` | Override endpoint for US-West, or `""` |
| *(same pattern for USE, EU, SG, JP)* | |
| `%%PREFILL_FMT_BANNER_CHECKED%%` | `checked` if Banner mentioned, else `""` |
| `%%PREFILL_FMT_BANNER_ACTIVE%%` | `active` if Banner has sample request, else `""` |
| `%%PREFILL_REQ_BANNER%%` | Sample request for Banner, or `""` |
| *(same pattern for VIDEO, NATIVE)* | |
| `%%PREFILL_TIMEOUT%%` | Extracted timeout, or `""` |