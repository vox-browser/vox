module main

import browserjs
import dom
import html
import page
import time

const can_owner_foreign = 'urn:compact-attribute-owner'

fn can_owner_fixture(markup string) !(&BrowserApp, &dom.Document, &browserjs.Runtime) {
	mut owner := page.Page.create(1)!
	document := parse_browser_navigation_document_for_page_with_response_time(markup, dom.URL{
		value: 'https://compact-attribute-owner.example.test/'
	}, none, none, unsafe { &dom.Page(owner) }, time.sys_mono_now())
	runtime := browserjs.Runtime.create()
	app := &BrowserApp{ page_model: owner, document: document, js_runtime: runtime, viewport_width: 320, viewport_height: 240 }
	return app, document, runtime
}

fn can_owner_element(document &dom.Document, id string) !&dom.Element {
	return document.get_element_by_id(id) or { return error('Missing compact namespace element ${id}') }
}

fn can_owner_attr(element &dom.Element, namespace ?string, local_name string) !&dom.Attr_ {
	return element.get_attribute_node_ns(namespace, local_name) or { return error('Missing compact namespace attribute ${local_name}') }
}

fn can_owner_start(document &dom.Document, runtime &browserjs.Runtime, source string) {
	mut messages := []string{}
	run_document_javascript(document, document.url.serialize(), [source], runtime, mut messages)
	assert messages == []
}

fn can_owner_flush(document &dom.Document, runtime &browserjs.Runtime) ! {
	snapshot := runtime.evaluate_host('__ladybirdFinalize()')!
	mut messages := []string{}
	apply_javascript_state(document, snapshot, runtime.canvas_elements_for_binding(), mut messages)
	assert messages == []
	_ = runtime.evaluate_host('__ladybirdClearLogs();0')!
}

fn can_owner_balance(app &BrowserApp, document &dom.Document, runtime &browserjs.Runtime) {
	settings := unsafe { &html.EnvironmentSettingsObject(document.relevant_settings_object()) }
	assert settings.realm().reported_exceptions.len == 0
	assert settings.realm().script_execution_depth == 0 && settings.realm().callback_execution_depth == 0
	assert !runtime.libjs_vm().has_running_execution_context()
	assert runtime.libjs_vm().execution_context_stack().len == 0 && runtime.libjs_vm().interpreter_stack().depth() == 0
	assert app.js_messages == []
}

fn test_compact_attribute_owner_keeps_duplicate_order_identity_and_public_remove_set_sequences() {
	$if !darwin && !linux { return }
	mut app, mut document, mut runtime := can_owner_fixture('<!doctype html><body><div id="can-first"></div><div id="can-second"></div>')!
	defer { runtime.close(); document.finalize() }
	first := can_owner_element(document, 'can-first')!
	second := can_owner_element(document, 'can-second')!
	for index, item in [first, second] {
		mut element := unsafe { &dom.Element(item) }
		if index == 1 {
			element.set_attribute_value('data-key', 'null raw')
			element.set_attribute_value('p:token', 'null prefix raw')
		}
		element.set_attribute_ns_for_bindings(can_owner_foreign, 'data-key', 'foreign raw')!
		element.set_attribute_ns_for_bindings(can_owner_foreign, 'p:token', 'foreign prefix raw')!
		if index == 0 {
			element.set_attribute_value('data-key', 'null raw')
			element.set_attribute_value('p:token', 'null prefix raw')
		}
	}
	can_owner_start(document, runtime, 'globalThis.canFirst=document.getElementById("can-first");globalThis.canSecond=document.getElementById("can-second");0')
	for index, element in [first, second] {
		name := if index == 0 { 'canFirst' } else { 'canSecond' }
		first_raw := if index == 0 { 'foreign raw' } else { 'null raw' }
		second_raw := if index == 0 { 'null raw' } else { 'foreign raw' }
		second_prefix_raw := if index == 0 { 'null prefix raw' } else { 'foreign prefix raw' }
		foreign := can_owner_attr(element, can_owner_foreign, 'data-key')!
		null_attr := can_owner_attr(element, none, 'data-key')!
		prefixed := can_owner_attr(element, can_owner_foreign, 'token')!
		null_prefixed := can_owner_attr(element, none, 'p:token')!
		assert runtime.evaluate_host('${name}.getAttribute("DATA-KEY")==="${first_raw}"&&${name}.hasAttribute("data-key")')! == 'true'
		assert runtime.evaluate_host('${name}.setAttribute("data-dirty","retained");${name}.matches("[data-dirty]")')! == 'true'
		assert voidptr(can_owner_attr(element, can_owner_foreign, 'data-key')!) == voidptr(foreign)
		assert voidptr(can_owner_attr(element, none, 'data-key')!) == voidptr(null_attr)
		assert foreign.value() == 'foreign raw' && null_attr.value() == 'null raw'
		assert prefixed.prefix()? == 'p' && prefixed.namespace_uri()? == can_owner_foreign
		assert null_prefixed.prefix() == none && null_prefixed.local_name() == 'p:token'
		assert runtime.evaluate_host('${name}.setAttribute("DATA-KEY","first changed");${name}.setAttribute("p:token","prefix changed");${name}.getAttribute("data-key")==="first changed"')! == 'true'
		can_owner_flush(document, runtime)!
		assert foreign.value() == if index == 0 { 'first changed' } else { 'foreign raw' }
		assert null_attr.value() == if index == 0 { 'null raw' } else { 'first changed' }
		assert prefixed.value() == if index == 0 { 'prefix changed' } else { 'foreign prefix raw' }
		assert null_prefixed.value() == if index == 0 { 'null prefix raw' } else { 'prefix changed' }
		assert voidptr(can_owner_attr(element, can_owner_foreign, 'token')!) == voidptr(prefixed)
		assert voidptr(can_owner_attr(element, none, 'p:token')!) == voidptr(null_prefixed)
		assert runtime.evaluate_host('${name}.removeAttribute("data-key");${name}.getAttribute("data-key")==="${second_raw}"&&${name}.hasAttribute("data-key")')! == 'true'
		assert runtime.evaluate_host('${name}.setAttribute("data-key","survivor changed");${name}.removeAttribute("p:token");${name}.getAttribute("p:token")==="${second_prefix_raw}"')! == 'true'
		can_owner_flush(document, runtime)!
		remaining := if index == 0 { null_attr } else { foreign }
		removed := if index == 0 { foreign } else { null_attr }
		assert voidptr(element.get_attribute_node('data-key')?) == voidptr(remaining)
		assert remaining.value() == 'survivor changed' && removed.owner_element() == none
		assert runtime.evaluate_host('${name}.removeAttribute("data-key");!${name}.hasAttribute("data-key")&&${name}.getAttribute("data-key")===null')! == 'true'
		assert runtime.evaluate_host('${name}.setAttribute("data-key","new null");${name}.getAttribute("data-key")==="new null"')! == 'true'
		can_owner_flush(document, runtime)!
		created := can_owner_attr(element, none, 'data-key')!
		assert created.value() == 'new null' && created.namespace_uri() == none && created.prefix() == none
		assert voidptr(created) != voidptr(null_attr) && voidptr(created) != voidptr(foreign)
		assert foreign.owner_element() == none && null_attr.owner_element() == none
		assert !element.has_attribute_ns(can_owner_foreign, 'data-key')
		assert element.get_attribute_names().filter(it == 'data-key').len == 1
	}
	app.relayout(320, 240 + app.chrome_height())
	can_owner_balance(app, document, runtime)
}

fn test_compact_attribute_owner_preserves_svg_case_and_xlink_identity_through_public_mutations() {
	$if !darwin && !linux { return }
	mut app, mut document, mut runtime := can_owner_fixture('<!doctype html><body><svg id="can-svg" width="20" height="20"></svg>')!
	defer { runtime.close(); document.finalize() }
	mut element := can_owner_element(document, 'can-svg')!
	element.set_attribute_value('viewBox', '0 0 20 20')
	element.set_attribute_value('viewbox', 'lowercase raw')
	element.set_attribute_ns_for_bindings('http://www.w3.org/1999/xlink', 'xlink:href', 'real xlink raw')!
	element.set_attribute_value('xlink:href', 'null qualified raw')
	upper := can_owner_attr(element, none, 'viewBox')!
	lower := can_owner_attr(element, none, 'viewbox')!
	xlink := can_owner_attr(element, 'http://www.w3.org/1999/xlink', 'href')!
	null_link := can_owner_attr(element, none, 'xlink:href')!
	can_owner_start(document, runtime, 'globalThis.canSVG=document.getElementById("can-svg");0')
	assert runtime.evaluate_host('canSVG.getAttribute("viewBox")==="0 0 20 20"&&canSVG.getAttribute("viewbox")==="lowercase raw"&&canSVG.getAttribute("VIEWBOX")===null&&canSVG.getAttribute("xlink:href")==="real xlink raw"')! == 'true'
	assert runtime.evaluate_host('canSVG.setAttribute("data-dirty","SVG unchanged");document.querySelector("#can-svg")===canSVG')! == 'true'
	assert xlink.value() == 'real xlink raw' && null_link.value() == 'null qualified raw'
	assert runtime.evaluate_host('canSVG.setAttribute("viewBox","0 0 30 30");canSVG.setAttribute("viewbox","lower changed");canSVG.setAttribute("xlink:href","real changed");canSVG.getAttribute("xlink:href")==="real changed"')! == 'true'
	can_owner_flush(document, runtime)!
	assert voidptr(can_owner_attr(element, none, 'viewBox')!) == voidptr(upper) && upper.value() == '0 0 30 30'
	assert voidptr(can_owner_attr(element, none, 'viewbox')!) == voidptr(lower) && lower.value() == 'lower changed'
	assert voidptr(can_owner_attr(element, 'http://www.w3.org/1999/xlink', 'href')!) == voidptr(xlink)
	assert xlink.value() == 'real changed' && xlink.prefix()? == 'xlink' && xlink.local_name() == 'href'
	assert null_link.value() == 'null qualified raw' && null_link.namespace_uri() == none && null_link.prefix() == none
	assert runtime.evaluate_host('canSVG.removeAttribute("xlink:href");canSVG.getAttribute("xlink:href")==="null qualified raw"&&canSVG.hasAttribute("xlink:href")')! == 'true'
	assert runtime.evaluate_host('canSVG.setAttribute("xlink:href","null changed");canSVG.setAttribute("data-dirty","after removal");canSVG.matches("[data-dirty]")')! == 'true'
	assert !element.has_attribute_ns('http://www.w3.org/1999/xlink', 'href') && xlink.owner_element() == none
	assert voidptr(can_owner_attr(element, none, 'xlink:href')!) == voidptr(null_link) && null_link.value() == 'null changed'
	assert runtime.evaluate_host('canSVG.removeAttribute("xlink:href");canSVG.setAttribute("data-dirty","twice removed");document.querySelector("#can-svg")===canSVG&&!canSVG.hasAttribute("xlink:href")')! == 'true'
	can_owner_flush(document, runtime)!
	assert !element.has_attribute_ns(none, 'xlink:href') && null_link.owner_element() == none
	assert upper.value() == '0 0 30 30' && lower.value() == 'lower changed'
	app.relayout(320, 240 + app.chrome_height())
	can_owner_balance(app, document, runtime)
}

fn test_compact_attribute_owner_hydrates_late_nodes_and_retains_created_disconnected_reordered_identity() {
	$if !darwin && !linux { return }
	mut app, mut document, mut runtime := can_owner_fixture('<!doctype html><body><div id="can-parent"></div><div id="can-other"></div>')!
	defer { runtime.close(); document.finalize() }
	parent := can_owner_element(document, 'can-parent')!
	other := can_owner_element(document, 'can-other')!
	can_owner_start(document, runtime, 'globalThis.canParent=document.getElementById("can-parent");globalThis.canOther=document.getElementById("can-other");0')
	mut late := document.create_element('div')!
	late.set_attribute_value('id', 'can-late')
	late.set_attribute_ns_for_bindings(can_owner_foreign, 'data-state', 'late foreign raw')!
	late.set_attribute_ns_for_bindings(can_owner_foreign, 'p:token', 'late prefixed raw')!
	foreign := can_owner_attr(late, can_owner_foreign, 'data-state')!
	prefixed := can_owner_attr(late, can_owner_foreign, 'token')!
	mut parent_node := parent.as_node()
	parent_node.append_child(late.as_node())!
	assert runtime.evaluate_host('globalThis.canLate=document.querySelector("#can-late");canLate.getAttribute("data-state")==="late foreign raw"&&canLate.getAttribute("p:token")==="late prefixed raw"')! == 'true'
	assert runtime.evaluate_host('canLate.setAttribute("data-dirty","late only");canLate.matches("[data-dirty]")')! == 'true'
	assert !late.has_attribute_ns(none, 'data-state') && !late.has_attribute_ns(none, 'p:token')
	assert voidptr(can_owner_attr(late, can_owner_foreign, 'data-state')!) == voidptr(foreign)
	assert runtime.evaluate_host('canLate.setAttribute("data-state","late changed");canOther.appendChild(canLate);document.querySelector("#can-other>#can-late")===canLate')! == 'true'
	assert voidptr(late.parent_element()?) == voidptr(other) && foreign.value() == 'late changed'
	assert voidptr(can_owner_attr(late, can_owner_foreign, 'token')!) == voidptr(prefixed) && prefixed.prefix()? == 'p'
	assert runtime.evaluate_host('globalThis.canCreated=document.createElement("span");canCreated.id="can-created";canCreated.setAttribute("data-life","first");canParent.appendChild(canCreated);document.querySelector("#can-created")===canCreated')! == 'true'
	created := can_owner_element(document, 'can-created')!
	life := can_owner_attr(created, none, 'data-life')!
	assert life.value() == 'first'
	assert runtime.evaluate_host('canCreated.remove();document.querySelector("#can-created")===null')! == 'true'
	assert !created.as_node().is_connected()
	assert runtime.evaluate_host('canCreated.setAttribute("data-life","second");canOther.appendChild(canCreated);document.querySelector("#can-other>#can-created")===canCreated')! == 'true'
	assert voidptr(can_owner_element(document, 'can-created')!) == voidptr(created)
	assert voidptr(can_owner_attr(created, none, 'data-life')!) == voidptr(life) && life.value() == 'second'
	assert runtime.evaluate_host('canOther.moveBefore(canCreated,canLate);canLate.setAttribute("data-dirty","reordered");document.querySelector("#can-other>#can-created")===canCreated')! == 'true'
	assert voidptr(other.as_node().first_child()?) == voidptr(created.as_node())
	assert voidptr(can_owner_attr(late, can_owner_foreign, 'data-state')!) == voidptr(foreign) && foreign.value() == 'late changed'
	assert !late.has_attribute_ns(none, 'data-state') && prefixed.value() == 'late prefixed raw'
	can_owner_flush(document, runtime)!
	app.relayout(320, 240 + app.chrome_height())
	can_owner_balance(app, document, runtime)
}
