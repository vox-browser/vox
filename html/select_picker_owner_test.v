module html

import dom
import highresolutiontime
import math
import page

@[heap]
struct SelectPickerOwnerObservation {
mut:
	calls int
	items []SelectItem
}

fn select_picker_owner_document(address string, markup string) !(&dom.Document, &WindowModel) {
	owner := page.Page.create(1)!
	url := dom.URL{address}
	mut document := create_navigation_document_for_page(url, url.origin(), none, unsafe { &dom.Page(owner) })!
	document.set_document_type(.html)
	parse_html_from_a_string(document, markup)
	native := document.get_window() or { return error('missing actual Window') }
	return document, unsafe { &WindowModel(native) }
}

fn select_picker_owner_activate(document &dom.Document) {
	mut native := document.get_window() or { panic('missing actual Window') }
	native.set_last_activation_timestamp(highresolutiontime.current_high_resolution_time(highresolutiontime.TimeOriginContext{
		time_origin: document.load_timing_info.navigation_start_time
	}))
}

fn select_picker_owner_model(document &dom.Document) !&HTMLSelectElementModel {
	element := document.get_element_by_id('select') or { return error('missing actual select') }
	return HTMLSelectElementModel.create(unsafe { &dom.HTMLSelectElement(element) })
}

fn test_select_picker_real_trusted_activation_is_consumed_before_existing_ui_hook_and_other_control() {
	mut document, window := select_picker_owner_document('https://select-picker-owner.example/', '<select id=select><option value=a>Alpha</option><optgroup label=Group><option value=b>Beta</option></optgroup></select><input id=color type=color>')!
	defer { document.finalize() }
	mut model := select_picker_owner_model(document)!
	state := &SelectPickerOwnerObservation{}
	model.set_picker_hook(fn [window, state] (items []SelectItem) {
		assert window.has_sticky_activation() && !window.has_transient_activation()
		assert math.is_inf(window.last_activation_timestamp(), -1)
		mut observation := unsafe { &SelectPickerOwnerObservation(state) }
		observation.calls++
		observation.items = items.clone()
	})
	mut rejected := false
	model.show_picker() or {
		rejected = true
		assert err.msg().starts_with('NotAllowedError:')
	}
	assert rejected && state.calls == 0
	target := unsafe { &dom.EventTarget(model.element) }
	assert target.dispatch_event(dom.Event.create('mousedown', dom.EventInit{}))
	assert window.has_transient_activation()
	model.show_picker()!
	assert model.is_open() && state.calls == 1
	assert state.items.len == 2
	assert state.items[0] is SelectItemOption
	assert state.items[1] is SelectItemOptionGroup
	color_element := document.get_element_by_id('color')?
	mut color := HTMLInputElementModel.create(unsafe { &dom.HTMLInputElement(color_element) })
	rejected = false
	color.show_picker() or {
		rejected = true
		assert err.msg().starts_with('NotAllowedError:')
	}
	assert rejected && !color.is_open()
}

fn test_select_picker_source_error_order_origin_gate_and_non_rendered_fixme() {
	mut document, window := select_picker_owner_document('https://select-picker-origin.example/', '<select id=select><option>Alpha</option></select>')!
	defer { document.finalize() }
	mut model := select_picker_owner_model(document)!
	mut element := document.get_element_by_id('select')?
	mut settings := window.environment_settings_.settings
	settings.environment_.top_level_origin = dom.URL{'https://foreign-select-top.example/'}.origin()
	element.set_attribute_value('disabled', '')
	mut rejection := ''
	model.show_picker() or { rejection = err.msg() }
	assert rejection.starts_with('InvalidStateError:')
	element.remove_attribute('disabled')
	model.show_picker() or { rejection = err.msg() }
	assert rejection.starts_with('SecurityError:')
	select_picker_owner_activate(document)
	model.show_picker() or { rejection = err.msg() }
	assert rejection.starts_with('SecurityError:') && window.has_transient_activation()
	settings.environment_.top_level_origin = document.origin()
	mut node := element.as_node()
	node.remove(false)
	assert !element.is_connected()
	assert element.as_node().paintable_box() == none
	model.show_picker()!
	assert model.is_open() && !window.has_transient_activation()
	assert model.select_items_.len == 1
}

fn test_select_picker_adoption_and_trusted_activation_behavior_use_actual_current_global() {
	mut original, original_window := select_picker_owner_document('https://select-picker-adoption.example/', '<select id=select><option>Alpha</option></select>')!
	mut replacement, replacement_window := select_picker_owner_document('https://adopted-select.example/', '<main id=host></main>')!
	defer {
		original.finalize()
		replacement.finalize()
	}
	mut model := select_picker_owner_model(original)!
	select_picker_owner_activate(original)
	_ = replacement.adopt_node_binding(unsafe { &dom.Node(model.element) })!
	host := replacement.get_element_by_id('host')?
	mut host_node := host.as_node()
	host_node.append_child(unsafe { &dom.Node(model.element) })!
	mut rejected := false
	model.show_picker() or {
		rejected = true
		assert err.msg().starts_with('NotAllowedError:')
	}
	assert rejected && original_window.has_transient_activation() && !model.is_open()
	select_picker_owner_activate(replacement)
	untrusted := dom.Event.construct_impl('click', dom.EventInit{})!
	model.activation_behavior(untrusted)
	assert !model.is_open() && replacement_window.has_transient_activation()
	model.activation_behavior(dom.Event.create('click', dom.EventInit{}))
	assert model.is_open() && !replacement_window.has_transient_activation()
	assert original_window.has_transient_activation()
}

fn test_select_picker_consumption_uses_actual_logical_parent_despite_independent_contexts() {
	mut top, top_window := select_picker_owner_document('https://select-picker-tree.example/top', '<iframe id=child></iframe>')!
	mut child, child_window := select_picker_owner_document('https://select-picker-tree.example/child', '<select id=select><option>Alpha</option></select>')!
	defer {
		top.finalize()
		child.finalize()
	}
	container := top.get_element_by_id('child')?
	mut navigable := child.navigable()?
	navigable.parent_ = top.navigable()?
	navigable.is_top_level_traversable_ = false
	navigable.container_ = container.as_node()
	navigable.container_document_ = top
	mut settings := child_window.environment_settings_.settings
	settings.environment_.top_level_origin = top.origin()
	assert child_window.browsing_context().parent() == none
	select_picker_owner_activate(top)
	select_picker_owner_activate(child)
	mut model := select_picker_owner_model(child)!
	model.show_picker()!
	assert model.is_open()
	assert math.is_inf(top_window.last_activation_timestamp(), -1)
	assert math.is_inf(child_window.last_activation_timestamp(), -1)
}
