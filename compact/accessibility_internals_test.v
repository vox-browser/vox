module main

import browserjs
import html

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
