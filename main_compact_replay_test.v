module main

import browserjs
import dom

fn test_selector_replay_preserves_absent_attributes_and_explicit_empty_writes() {
	$if !darwin { return }
	address := dom.URL{value: 'https://replay.example.test/'}
	document := parse_browser_navigation_document('<!doctype html><body><div id="changed"></div><p id="untouched">text</p></body>', address, none)
	mut runtime := browserjs.Runtime.create()
	defer { runtime.close() }
	mut messages := []string{}
	run_document_javascript(document, address.serialize(), [r'
const target=document.getElementById("changed");
target.className="changed";
if(document.querySelectorAll("[class]").length!==1)throw new Error("replay added unrelated class attributes");
if(document.querySelectorAll("[style]").length!==0)throw new Error("replay added unrelated style attributes");
target.className="";target.setAttribute("style","");
if(document.querySelector("[class]")!==target||document.querySelector("[style]")!==target)throw new Error("explicit empty attributes lost");
target.removeAttribute("class");target.removeAttribute("style");
if(document.querySelector("[class],[style]")!==null)throw new Error("removed attributes restored");
'], runtime, mut messages)
	assert messages == []
	for id in ['changed', 'untouched'] {
		element := document.get_element_by_id(id) or { panic('missing ${id}') }
		assert !element.has_attribute('class')
		assert !element.has_attribute('style')
	}
}

fn test_selector_replay_flushes_control_state_and_retains_console_messages() {
	$if !darwin { return }
	address := dom.URL{value: 'https://replay.example.test/controls'}
	document := parse_browser_navigation_document('<!doctype html><title>unchanged</title><body><input id="check" type="checkbox"><div id="parent"></div></body>', address, none)
	mut runtime := browserjs.Runtime.create()
	defer { runtime.close() }
	mut messages := []string{}
	run_document_javascript(document, address.serialize(), [r'
const parent=document.getElementById("parent");
console.log("before");
check.checked=true;if(!check.matches(":checked"))throw new Error("pending checked state not applied");
check.checked=false;if(document.querySelector(":checked")!==null)throw new Error("unchecked state not applied");
parent.innerHTML="<span id=imported>first</span>";
const imported=parent.querySelector("span");imported.textContent="second";
if(document.getElementById("imported")!==imported||imported.textContent!=="second")throw new Error("delta lost imported identity or text");
console.log("after");
'], runtime, mut messages)
	assert messages == ['before', 'after']
	assert document_title(document) == 'unchanged'
	imported := document.get_element_by_id('imported') or { panic('missing imported element') }
	assert imported.as_node().text_content() or { '' } == 'second'
}
