module main

import browserjs
import dom
import html
import page
import time

fn test_disabled_reflection_reaches_native_controls_before_event_dispatch_returns() {
	for initial in [false, true] {
		mut document := html.parse_document('<!doctype html><button id="control" ${if initial { 'disabled' } else { '' }}>Send</button>')
		mut runtime := browserjs.Runtime.create()
		mut messages := []string{}
		run_document_javascript(document, 'https://control-reflection.test/', [
			'control.addEventListener("click",()=>{control.disabled=${!initial}});',
		], runtime, mut messages)
		control := document.get_element_by_id('control') or { panic('control') }
		event := dom.MouseEvent.create('click', dom.MouseEventInit{
			bubbles: true
			cancelable: true
		})
		dom.event_target_dispatch_event(unsafe { &dom.EventTarget(control) }, unsafe { &dom.Event(event) })
		assert control.has_attribute('disabled') == !initial
		assert messages == []string{}
		runtime.close()
		document.finalize()
	}
}

fn test_disabled_attribute_mutation_coerces_once_and_updates_native_state() {
	mut document := html.parse_document('<!doctype html><input id="control">')
	mut runtime := browserjs.Runtime.create()
	defer { runtime.close(); document.finalize() }
	mut messages := []string{}
	run_document_javascript(document, 'about:blank', [r'
globalThis.conversions=0;
globalThis.attributeName={toString(){conversions++;return "DISABLED"}};
control.setAttribute(attributeName,"false");
'], runtime, mut messages)
	control := document.get_element_by_id('control') or { panic('control') }
	assert control.has_attribute('disabled')
	assert runtime.evaluate_host('conversions===1&&control.disabled')! == 'true'
	runtime.evaluate_host('control.removeAttribute(attributeName);0')!
	assert !control.has_attribute('disabled')
	assert runtime.evaluate_host('conversions===2&&!control.disabled')! == 'true'
	assert messages == []string{}
}

fn test_click_default_uses_disabled_state_written_by_its_listener() {
	for initial in [false, true] {
		mut owner := page.Page.create(1)!
		mut document := parse_browser_navigation_document_for_page_with_response_time(
			'<!doctype html><form id="form"><button id="control" ${if initial { 'disabled' } else { '' }}><span id="label">Send</span></button></form>',
			dom.URL{value: 'https://control-reflection.test/'}, none, none,
			unsafe { &dom.Page(owner) }, time.sys_mono_now())
		owner.set_local_root_navigable(document.navigable() or { panic('navigable') })!
		mut runtime := browserjs.Runtime.create()
		mut messages := []string{}
		run_document_javascript(document, 'https://control-reflection.test/', [
			'globalThis.submissions=0;EventTarget.prototype.addEventListener.call(form,"submit",event=>{submissions++;event.preventDefault()});control.addEventListener("click",()=>{control.disabled=${!initial}});',
		], runtime, mut messages)
		label := document.get_element_by_id('label') or { panic('label') }
		assert document.is_fully_active()
		event := dom.MouseEvent.create('click', dom.MouseEventInit{bubbles: true, cancelable: true})
		dom.event_target_dispatch_event(unsafe { &dom.EventTarget(label) }, unsafe { &dom.Event(event) })
		actual := runtime.evaluate_host('submissions')!
		expected := if initial { '1' } else { '0' }
		assert actual == expected, 'initial disabled=${initial}: ${actual} submissions, expected ${expected}; ${messages.join("|")}'
		assert messages == []string{}
		runtime.close()
		document.finalize()
	}
}
