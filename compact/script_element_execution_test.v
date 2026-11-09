module main

import browserjs
import dom
import html

fn test_inserted_inline_and_document_written_scripts_execute_with_current_script() {
	mut document := parse_browser_navigation_document('<!doctype html><body><script id="writer"></script></body>',dom.URL{value:'https://inline.test/'},none)
	document.update_readiness(.interactive)
	writer := document.get_element_by_id('writer') or { panic('writer') }
	mut runtime := browserjs.Runtime.create()
	defer { runtime.close(); document.finalize() }
	mut messages := []string{}
	run_document_script_sources(document,'https://inline.test/',[browserjs.ScriptSource{element:writer,url:'https://inline.test/',code:r'
const script=document.createElement("script");script.id="dynamic-script";script.textContent=`document.currentScript.setAttribute("executed","yes");globalThis.dynamicExecuted=true`;
document.body.appendChild(script);
if(!globalThis.dynamicExecuted||script.getAttribute("executed")!=="yes")throw new Error("dynamic: "+globalThis.dynamicExecuted+" "+script.getAttribute("executed")+" "+script.textContent+" "+script.isConnected);
document.write("<script id=written>globalThis.writtenExecuted=document.currentScript.id</scr"+"ipt>");
if(globalThis.writtenExecuted!=="written")throw new Error("written "+globalThis.writtenExecuted);
const svg=document.createElementNS("http://www.w3.org/2000/svg","svg"),svgScript=document.createElementNS(svg.namespaceURI,"script");
svgScript.textContent="globalThis.svgOwner=document.currentScript;globalThis.svgCount=(globalThis.svgCount||0)+1";
svg.appendChild(svgScript);document.body.appendChild(svg);
if(globalThis.svgOwner!==svgScript||globalThis.svgCount!==1)throw new Error("SVG owner");
svg.appendChild(svgScript.cloneNode(true));if(globalThis.svgCount!==1)throw new Error("SVG clone");
console.log("script owners passed");
'}],runtime,mut messages)
	assert messages == ['script owners passed']
}
