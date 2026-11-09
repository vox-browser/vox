module main

import browserjs
import html
import platform

fn test_compact_internals_compute_accessible_names_and_roles() {
	mut document := html.parse_document('<!doctype html><button id="plain">Save <span>file</span></button><div id="labelled" role="button" aria-label="Close"></div><input id="field" aria-labelledby="caption"><span id="caption">Name</span><img id="image" alt="Logo"><nav id="navigation"></nav><div id="none"></div>')
	mut runtime := browserjs.Runtime.create()
	defer {
		runtime.close()
		document.finalize()
	}
	mut messages := []string{}
	run_document_javascript(document, 'about:blank', [r'
const fail=message=>{throw new Error(message);};
const label=id=>window.internals.getComputedLabel(document.getElementById(id)),role=id=>window.internals.getComputedRole(document.getElementById(id));
if(label("plain")!=="Save file"||role("plain")!=="button")fail("button "+label("plain")+" "+role("plain"));
if(label("labelled")!=="Close"||role("labelled")!=="button")fail("aria-label");
if(role("field")!=="textbox")fail("textbox role "+role("field"));
if(label("field")!=="Name")fail("aria-labelledby "+label("field"));
if(label("image")!=="Logo"||role("image")!=="image")fail("img "+label("image")+" "+role("image"));
if(role("navigation")!=="navigation"||role("none")!=="generic")fail("roles "+role("navigation")+" "+role("none"));
document.getElementById("labelled").setAttribute("aria-label","Dismiss");
if(label("labelled")!=="Dismiss")fail("live label");
let threw=false;try{window.internals.getComputedLabel({});}catch(error){threw=error instanceof TypeError;}
if(!threw)fail("receiver");
console.log("accessibility passed");
'], runtime, mut messages)
	assert messages == ['accessibility passed']
}


fn test_wpt_accessibility_backend_uses_native_names_roles_and_independent_capabilities() {
	mut document := html.parse_document('<!doctype html><button id="save" aria-label="Save">fallback</button>')
	mut runtime := browserjs.Runtime.create()
	defer { runtime.close(); document.finalize() }
	vendor := platform.embedded_text($embed_file('@VMODROOT/tools/wpt_testdriver_vendor.js'))
	mut messages := []string{}
	run_document_javascript(document, 'about:blank', [r'
globalThis.test_driver_internal={in_automation:false,click:async()=>{throw new Error("unsupported input")}};
const stockClick=test_driver_internal.click;
delete internals.testDriverClick;
' + vendor + r'
if(test_driver_internal.click!==stockClick||!test_driver_internal.in_automation)throw new Error("independent capabilities");
internals.getComputedLabel=()=>{throw new Error("author replacement")};
internals.getComputedRole=()=>{throw new Error("author replacement")};
const before=test_driver_internal.get_computed_label(save),role=test_driver_internal.get_computed_role(save);
if(!(before instanceof Promise)||!(role instanceof Promise))throw new Error("backend promise");
save.setAttribute("aria-label","Store");
const after=test_driver_internal.get_computed_label(save);
const rejected=test_driver_internal.get_computed_label({}).then(()=>false,error=>error instanceof TypeError);
Promise.all([before,role,after,rejected]).then(values=>{globalThis.accessibilityBackendResult=values});
'], runtime, mut messages)
	assert messages == []string{}
	assert runtime.evaluate_host('JSON.stringify(accessibilityBackendResult)')! == '["Save","button","Store",true]'
}
