module main

import browserjs
import html

fn test_compact_adjacent_html_preserves_nodes_and_updates_live_content() {
	mut document := html.parse_document('<!doctype html><div id="outer"><div id="host">old<b id="saved">bold</b></div></div>')
	mut runtime := browserjs.Runtime.create()
	defer {
		runtime.close()
		document.finalize()
	}
	mut messages := []string{}
	run_document_javascript(document, 'about:blank', [r'
const list=host.childNodes,old=host.firstChild,bold=saved;
if(host.textContent!=="oldbold"||outer.innerHTML.indexOf("old")<0)throw new Error("initial content");
if(host.insertAdjacentHTML("afterbegin","<i>first</i>")!==undefined)throw new Error("return value");
host.insertAdjacentHTML("BEFOREEND","last<!--tail-->");
host.insertAdjacentHTML("beforebegin","<p>before</p>");
host.insertAdjacentHTML("afterend","<p>after</p>");
if(list!==host.childNodes||list.length!==5||list[1]!==old||list[2]!==bold||bold.parentNode!==host)throw new Error("identity and live list");
if(host.textContent!=="firstoldboldlast"||outer.textContent!=="beforefirstoldboldlastafter")throw new Error("content invalidation");
if(outer.firstChild.textContent!=="before"||outer.lastChild.textContent!=="after")throw new Error("sibling order");
globalThis.adjacentHTMLPassed=true;
'], runtime, mut messages)
	assert messages == []string{}
	assert runtime.evaluate_host('adjacentHTMLPassed')! == 'true'
	assert document.get_element_by_id('outer')?.as_node().text_content()? == 'beforefirstoldboldlastafter'
}

fn test_compact_adjacent_html_converts_arguments_and_reports_dom_exceptions() {
	mut document := html.parse_document('<!doctype html><div id="host"></div>')
	mut runtime := browserjs.Runtime.create()
	defer {
		runtime.close()
		document.finalize()
	}
	mut messages := []string{}
	run_document_javascript(document, 'about:blank', [r'
const insert=Element.prototype.insertAdjacentHTML,descriptor=Object.getOwnPropertyDescriptor(Element.prototype,"insertAdjacentHTML");
if(insert.name!=="insertAdjacentHTML"||insert.length!==2||!descriptor.writable||!descriptor.enumerable||!descriptor.configurable)throw new Error("method metadata");
function rejects(callback,name){try{callback();throw new Error("missing exception");}catch(error){if(error.name!==name||(name!=="TypeError"&&!(error instanceof DOMException)))throw error;}}
for(const receiver of [null,{},document,new Proxy(host,{})])rejects(()=>insert.call(receiver,"beforeend","x"),"TypeError");
rejects(()=>insert.call(host,"beforeend"),"TypeError");
rejects(()=>insert.call(host,Symbol(),"x"),"TypeError");
rejects(()=>insert.call(host,"beforeend",Symbol()),"TypeError");
rejects(()=>insert.call(host,"invalid","x"),"SyntaxError");
rejects(()=>insert.call(document.createElement("div"),"beforebegin","x"),"NoModificationAllowedError");
rejects(()=>insert.call(document.documentElement,"afterend","x"),"NoModificationAllowedError");
const conversions=[];
insert.call(host,{toString(){conversions.push("position");return "beforeend";}},{toString(){conversions.push("markup");return "<em>converted</em>";}});
if(conversions.join(",")!=="position,markup"||host.firstChild.localName!=="em"||host.textContent!=="converted")throw new Error("DOMString conversion");
globalThis.adjacentErrorsPassed=true;
'], runtime, mut messages)
	assert messages == []string{}
	assert runtime.evaluate_host('adjacentErrorsPassed')! == 'true'
}

fn test_compact_adjacent_html_uses_table_and_svg_fragment_contexts() {
	mut document := html.parse_document('<!doctype html><table><tbody id="rows"></tbody></table><svg id="drawing"></svg>')
	mut runtime := browserjs.Runtime.create()
	defer {
		runtime.close()
		document.finalize()
	}
	mut messages := []string{}
	run_document_javascript(document, 'about:blank', [r'
rows.insertAdjacentHTML("beforeend","<tr><td>cell</td></tr>");
if(!rows.hasChildNodes())throw new Error("child state");
drawing.insertAdjacentHTML("beforeend",`<linearGradient id="paint"><stop offset="0"/></linearGradient>`);
document.head.insertAdjacentHTML("beforeend",`<meta name="maps-test" content="ready"><style>#rows { color: rgb(1, 2, 3); }</style><script>globalThis.fragmentScriptRan=true</script>`);
if(rows.firstChild.localName!=="tr"||rows.firstChild.firstChild.localName!=="td"||rows.textContent!=="cell")throw new Error("table context");
const gradient=drawing.firstChild;
if(gradient.localName!=="linearGradient"||gradient.namespaceURI!=="http://www.w3.org/2000/svg"||gradient.firstChild.namespaceURI!==gradient.namespaceURI)throw new Error("SVG context");
if(globalThis.fragmentScriptRan!==undefined)throw new Error("fragment script executed");
if(document.querySelector(`meta[name="maps-test"]`).getAttribute("content")!=="ready")throw new Error("head insertion");
const detached=document.createElement("div");detached.textContent="pending";
detached.insertAdjacentHTML("beforeend","<b>inserted</b>");
if(detached.textContent!=="pendinginserted"||!detached.hasChildNodes())throw new Error("detached insertion and pending content");
globalThis.adjacentContextPassed=true;
'], runtime, mut messages)
	assert messages == []string{}
	assert runtime.evaluate_host('adjacentContextPassed')! == 'true'
	assert document.get_element_by_id('paint')?.local_name() == 'linearGradient'
}
