module main

import adblock
import browserjs
import dom

fn test_compact_get_attribute_names_returns_fresh_ordered_lists_after_mutations() {
	$if !darwin { return }
	mut document := parse_browser_navigation_document('<!doctype html><body><p id="attributes" 2="two" 1="one" data-empty="" DATA-Keep="yes"></p></body>',
		dom.url_about_blank(), none)
	mut runtime := browserjs.Runtime.create()
	defer { runtime.close(); document.finalize() }
	mut messages := []string{}
	run_document_javascript(document, 'about:blank', []string{}, runtime, mut messages)
	assert messages == []
	assert runtime.evaluate_host(r'(()=>{
 const element=document.getElementById("attributes"), names=element.getAttributeNames();
 if(!Array.isArray(names)||JSON.stringify(names)!==JSON.stringify(["id","2","1","data-empty","data-keep"]))return false;
 names[0]="changed";names.push("invented");
 if(element.getAttributeNames()[0]!=="id"||element.getAttributeNames().length!==5)return false;
 const snapshot=element.getAttributeNames();
 element.setAttribute("DATA-New","");element.setAttribute("data-keep","updated");element.removeAttribute("data-empty");element.setAttribute("data-empty","restored");
 if(JSON.stringify(snapshot)!==JSON.stringify(["id","2","1","data-empty","data-keep"]))return false;
 if(JSON.stringify(element.getAttributeNames())!==JSON.stringify(["id","2","1","data-keep","data-new","data-empty"]))return false;
 const created=document.createElement("a");
 if(created.getAttributeNames().length!==0)return false;
 created.setAttribute("DATA-OUTBOUND-URL","tracking");created.setAttribute("href","https://example.test/");
 return JSON.stringify(created.getAttributeNames())===JSON.stringify(["data-outbound-url","href"]);
})()')! == 'true'
}

fn test_compact_get_attribute_names_preserves_qualified_names_and_checks_receivers() {
	$if !darwin { return }
	mut document := parse_browser_navigation_document('<!doctype html><body><svg id="attributes" viewBox="0 0 10 10"></svg></body>',
		dom.url_about_blank(), none)
	mut element := document.get_element_by_id('attributes') or { panic('missing SVG') }
	element.set_attribute_ns_for_bindings('urn:first', 'q:Mixed', 'first')!
	element.set_attribute_ns_for_bindings('urn:second', 'q:Mixed', 'second')!
	mut runtime := browserjs.Runtime.create()
	defer { runtime.close(); document.finalize() }
	mut messages := []string{}
	run_document_javascript(document, 'about:blank', []string{}, runtime, mut messages)
	assert messages == []
	assert runtime.evaluate_host(r'(()=>{
 const descriptor=Object.getOwnPropertyDescriptor(Element.prototype,"getAttributeNames"),method=descriptor&&descriptor.value;
 if(typeof method!=="function"||method.name!=="getAttributeNames"||method.length!==0||!descriptor.writable||!descriptor.enumerable||!descriptor.configurable)return false;
 for(const receiver of [null,undefined,{},document,{__state:{attributeRecords:[]}}]){
  try{method.call(receiver);return false;}catch(error){if(!(error instanceof TypeError))return false;}
 }
 try{new method();return false;}catch(error){if(!(error instanceof TypeError))return false;}
 const svg=document.getElementById("attributes");
 if(JSON.stringify(method.call(svg))!==JSON.stringify(["id","viewBox","q:Mixed","q:Mixed"]))return false;
 const created=document.createElementNS("http://www.w3.org/2000/svg","g");created.setAttribute("viewBox","");
 return JSON.stringify(created.getAttributeNames())===JSON.stringify(["viewBox"]);
})()')! == 'true'
}

fn test_old_reddit_privacy_filter_removes_tracking_attributes_without_console_errors() {
	$if !darwin { return }
	address := 'https://old.reddit.com/r/DotA2/comments/1x78he9/was_it_worth_it_no_i_am_happy_no/'
	mut document := parse_browser_navigation_document('<!doctype html><body><a id="outbound" class="outbound" data-outbound-url="https://tracking.test/" href="https://example.test/" data-keep="yes">Story</a><a id="ordinary" data-outbound-url="keep" href="/r/DotA2/">Comments</a></body>',
		dom.URL{value: address}, none)
	selected := adblock.document_filters(address, browser_adblock_tokens(document))!
	assert selected.procedural.any(it.contains('data-outbound-url'))
	mut runtime := browserjs.Runtime.create()
	defer { runtime.close(); document.finalize() }
	mut messages := []string{}
	run_document_javascript(document, address, []string{}, runtime, mut messages)
	refresh_browser_adblock(document, runtime, mut messages)
	assert messages == [], '${messages}'
	outbound := document.get_element_by_id('outbound') or { panic('missing outbound link') }
	ordinary := document.get_element_by_id('ordinary') or { panic('missing ordinary link') }
	assert !outbound.has_attribute('data-outbound-url')
	assert outbound.get_attribute_value('href') == 'https://example.test/'
	assert outbound.get_attribute_value('data-keep') == 'yes'
	assert ordinary.get_attribute_value('data-outbound-url') == 'keep'
	runtime.evaluate_host('(()=>{const link=document.createElement("a");link.id="late-outbound";link.className="outbound";link.setAttribute("data-outbound-url","tracking");link.setAttribute("href","https://example.test/late");document.body.appendChild(link);})()')!
	refresh_browser_adblock(document, runtime, mut messages)
	refresh_browser_adblock(document, runtime, mut messages)
	assert messages == [], '${messages}'
	late := document.get_element_by_id('late-outbound') or { panic('missing late outbound link') }
	assert !late.has_attribute('data-outbound-url')
	assert late.get_attribute_value('href') == 'https://example.test/late'
}
