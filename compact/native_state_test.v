module main

import browserjs
import dom
import html

fn native_state_document(markup string, script string) (&dom.Document, &browserjs.Runtime, []string) {
	mut document := html.parse_document(markup)
	mut runtime := browserjs.Runtime.create()
	mut messages := []string{}
	run_document_javascript(document, 'about:blank', [script], runtime, mut messages)
	return document, runtime, messages
}

fn native_click(document &dom.Document, id string) {
	element := document.get_element_by_id(id) or { panic('missing ${id}') }
	html.html_element_click(unsafe { &dom.HTMLElement(element) })
}

// A user's click toggles state natively. The compact cache kept the old value:
// box.checked stayed false and details.hasAttribute("open") stayed false.
fn test_native_activation_state_is_visible_to_page_scripts() {
	mut document, mut runtime, messages := native_state_document('<!doctype html><input id="box" type="checkbox"><input id="first" type="radio" name="r" checked><input id="second" type="radio" name="r"><details id="det"><summary id="sum">More</summary>Body</details><dialog id="dlg">x</dialog>',
		r'globalThis.changes=[];box.addEventListener("change",event=>changes.push(event.isTrusted+":"+box.checked));box.onchange=()=>changes.push("inline");')
	defer {
		runtime.close()
		document.finalize()
	}
	assert messages == []string{}
	assert runtime.evaluate_host('box.checked+"|"+first.checked+"|"+det.open+"|"+dlg.open')! == 'false|true|false|false'
	native_click(document, 'box')
	native_click(document, 'second')
	native_click(document, 'sum')
	assert runtime.evaluate_host('box.checked+"|"+first.checked+"|"+second.checked+"|"+changes.join()')! == 'true|false|true|true:true,inline'
	assert runtime.evaluate_host('det.open+"|"+det.hasAttribute("open")')! == 'true|true'
	// The open setter writes the attribute, and the dialog reflects it too.
	runtime.evaluate_host('det.open=false;dlg.open=true;0')!
	assert runtime.evaluate_host('det.open+"|"+det.matches("[open]")+"|"+dlg.open+"|"+dlg.getAttribute("open")')! == 'false|false|true|'
	let_illegal := runtime.evaluate_host('(()=>{try{Object.getOwnPropertyDescriptor(HTMLDetailsElement.prototype,"open").get.call(box);return "no"}catch(error){return error instanceof TypeError?"type":"other"}})()')!
	assert let_illegal == 'type'
}

// The shell replays a native click into the compact layer; activation that
// happened during that native click must be visible to later reads.
fn test_click_replay_refreshes_activated_ancestors() {
	mut document, mut runtime, messages := native_state_document('<!doctype html><details id="det"><summary id="sum">More</summary>Body</details>',
		r'')
	defer {
		runtime.close()
		document.finalize()
	}
	assert messages == []string{}
	assert runtime.evaluate_host('det.hasAttribute("open")')! == 'false'
	runtime.evaluate_host('__ladybirdDispatch("click","sum")')!
	assert runtime.evaluate_host('det.hasAttribute("open")+"|"+det.getAttribute("open")')! == 'true|'
}
