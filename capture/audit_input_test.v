module main

import dom
import html
import json2

fn test_capture_audit_input_observes_live_value_without_materializing_models() {
	mut document := html.parse_document('<input id="edit" value="initial"><input id="cold" value="cold">')
	defer { document.finalize() }
	edit := document.get_element_by_id('edit') or { panic('edit') }
	cold := document.get_element_by_id('cold') or { panic('cold') }
	edit_input := unsafe { &dom.HTMLInputElement(edit) }
	cold_input := unsafe { &dom.HTMLInputElement(cold) }
	assert capture_audit_input(cold, true) == none
	assert cold_input.input_element_model_ == unsafe { nil }
	mut model := html.HTMLInputElementModel.create(unsafe { &dom.HTMLInputElement(edit) })
	model.set_value('ma')!
	model.text_control.set_selection_start_binding(u32(1))!
	model.text_control.set_selection_end_binding(u32(2))!
	before := edit_input.input_element_model_
	assert capture_audit_input(edit, false) == none
	state := capture_audit_input(edit, true) or { panic('existing input') }
	assert state.value == 'ma' && edit.get_attribute_value('value') == 'initial'
	assert state.selection_start or { u32(99) } == 1
	assert state.selection_end or { u32(99) } == 2
	assert edit_input.input_element_model_ == before && cold_input.input_element_model_ == unsafe { nil }
	mut app := BrowserApp{ document: document }
	audit := app.collect_capture_audit(CaptureAuditConfig{ selectors: [CaptureAuditSelector{ name: 'edit', selector: '#edit', input_state: true }] })!
	decoded := json2.decode[CaptureAudit](json2.encode(audit))!
	assert (decoded.selections[0].elements[0].input or { panic('input snapshot') }).value == 'ma'
}
