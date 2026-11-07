module main

import browserjs
import dom
import html
import page
import time

fn element_click_document(markup string) (&dom.Document, &browserjs.Runtime) {
	document := html.parse_document(markup)
	return document, browserjs.Runtime.create()
}

fn test_html_element_click_runs_native_listeners_and_inline_handlers() {
	mut document, mut runtime := element_click_document('<!doctype html><div id="outer" onclick="order.push(\'outer-raw:\'+(this===outer))"><a id="link" onclick="order.push(\'link-raw:\'+event.type+(this===link))">load more<span id="count"> (1 reply)</span></a></div><svg id="vector"></svg><button id="off" disabled onclick="order.push(\'disabled\')">x</button>')
	defer {
		runtime.close()
		document.finalize()
	}
	mut messages := []string{}
	run_document_javascript(document, 'about:blank', [r'
const descriptor=Object.getOwnPropertyDescriptor(HTMLElement.prototype,"click");
if(!descriptor||typeof descriptor.value!=="function"||descriptor.value.name!=="click"||descriptor.value.length!==0||!descriptor.writable||!descriptor.enumerable||!descriptor.configurable)throw new Error("click descriptor");
if("click" in vector)throw new Error("SVG elements are not HTMLElements");
let brands=0;for(const receiver of [{},null,vector])try{HTMLElement.prototype.click.call(receiver)}catch(error){if(error instanceof TypeError)brands++}
if(brands!==3)throw new Error("click receiver checks");
globalThis.order=[];
document.addEventListener("click",event=>order.push("doc-capture:"+event.isTrusted+":"+(event instanceof MouseEvent)+":"+event.bubbles+":"+event.cancelable),true);
link.addEventListener("click",()=>order.push("link-listener"));
outer.addEventListener("click",()=>order.push("outer-listener"));
if(link.click()!==undefined)throw new Error("click returns undefined");
const expected=["doc-capture:false:true:true:true","link-listener","link-raw:clicktrue","outer-listener","outer-raw:true"].join();
if(order.join()!==expected)throw new Error("click order "+order.join());
order=[];count.click();
if(order.join()!==expected)throw new Error("descendant click "+order.join());
order=[];const stop=event=>{event.stopPropagation();order.push("stopped")};link.addEventListener("click",stop);link.click();link.removeEventListener("click",stop);
if(order.join()!==["doc-capture:false:true:true:true","link-listener","stopped","link-raw:clicktrue"].join())throw new Error("native stopPropagation "+order.join());
order=[];link.onclick=function(event){order.push("property:"+(this===link));};link.click();
if(order.filter(item=>item==="property:true").length!==1||order.some(item=>item.indexOf("link-raw")===0))throw new Error("on* property replaces the attribute "+order.join());
order=[];off.addEventListener("click",()=>order.push("disabled-listener"));off.click();
if(order.length)throw new Error("disabled control "+order.join());
order=[];let nested=0;link.onclick=function(){nested++;link.click();};link.click();
if(nested!==1)throw new Error("nested click of the same element");
'], runtime, mut messages)
	assert messages == []string{}
}

fn test_html_element_click_toggles_checkboxes_unless_an_inline_handler_cancels() {
	mut document, mut runtime := element_click_document('<!doctype html><input id="box" type="checkbox"><input id="kept" type="checkbox" onclick="return false"><input id="radio" type="radio" name="r"><details id="details"><summary id="summary">More</summary>Body</details>')
	defer {
		runtime.close()
		document.finalize()
	}
	mut messages := []string{}
	run_document_javascript(document, 'about:blank', [r'
box.click();
if(box.checked!==true||!box.matches(":checked"))throw new Error("checkbox activation");
box.click();
if(box.checked!==false||box.matches(":checked"))throw new Error("checkbox second activation");
kept.click();
if(kept.checked!==false||kept.matches(":checked"))throw new Error("return false restores the checkbox");
radio.click();
if(radio.checked!==true)throw new Error("radio activation");
summary.click();
if(!details.matches("[open]"))throw new Error("summary activation");
'], runtime, mut messages)
	assert messages == []string{}
	box := document.get_element_by_id('box') or { panic('box') }
	assert !unsafe { &dom.HTMLInputElement(box) }.checked()
	radio := document.get_element_by_id('radio') or { panic('radio') }
	assert unsafe { &dom.HTMLInputElement(radio) }.checked()
}

fn test_html_element_click_follows_links_unless_an_inline_handler_returns_false() {
	mut owner := page.Page.create(1)!
	mut document := parse_browser_navigation_document_for_page_with_response_time('<!doctype html><a id="go" href="/next">go</a><a id="stay" href="/stay" onclick="return false">stay</a><a id="script" href="javascript:void(0)" onclick="clicked=true;return false">more</a>',
		dom.URL{ value: 'https://click.example.test/start' }, none, none, unsafe { &dom.Page(owner) }, time.sys_mono_now())
	mut runtime := browserjs.Runtime.create()
	defer {
		runtime.close()
		document.finalize()
	}
	mut messages := []string{}
	run_document_javascript(document, 'https://click.example.test/start', []string{}, runtime, mut messages)
	mut app := BrowserApp{ document: document, page_model: owner, js_runtime: runtime, layout_tree_only: true, viewport_width: 320, viewport_height: 200 }
	app.install_compact_navigation_handler()
	runtime.evaluate_host('stay.click();script.click()')!
	assert app.pending_native_navigation == none
	assert runtime.evaluate_host('String(globalThis.clicked)')! == 'true'
	runtime.evaluate_host('go.click()')!
	assert app.pending_native_navigation? == 'https://click.example.test/next'
	assert messages == []string{}
}
