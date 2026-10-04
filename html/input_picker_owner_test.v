module html

import dom
import highresolutiontime
import math
import page

fn input_picker_owner_document(address string, markup string) !(&dom.Document, &WindowModel, &page.Page) {
	owner := page.Page.create(1)!
	url := dom.URL{address}
	mut document := create_navigation_document_for_page(url, url.origin(), none, unsafe { &dom.Page(owner) })!
	document.set_document_type(.html)
	parse_html_from_a_string(document, markup)
	native := document.get_window() or { return error('missing actual Window') }
	return document, unsafe { &WindowModel(native) }, owner
}

fn input_picker_owner_activate(document &dom.Document) {
	mut native := document.get_window() or { panic('missing actual Window') }
	native.set_last_activation_timestamp(highresolutiontime.current_high_resolution_time(highresolutiontime.TimeOriginContext{
		time_origin: document.load_timing_info.navigation_start_time
	}))
}

fn input_picker_owner_model(document &dom.Document, id string) !&HTMLInputElementModel {
	element := document.get_element_by_id(id) or { return error('missing input ${id}') }
	return HTMLInputElementModel.create(unsafe { &dom.HTMLInputElement(element) })
}

fn test_input_picker_uses_real_trusted_window_activation_and_consumes_shared_control_permission() {
	mut document, window, owner := input_picker_owner_document('https://input-picker-owner.example/', '<input id=file type=file accept=.png multiple><input id=color type=color value=#123456>')!
	defer { document.finalize() }
	mut file := input_picker_owner_model(document, 'file')!
	mut color := input_picker_owner_model(document, 'color')!
	before := owner.client().events.len
	mut rejected := false
	file.show_picker() or {
		rejected = true
		assert err.msg().starts_with('NotAllowedError:')
	}
	assert rejected && owner.client().events.len == before
	target := unsafe { &dom.EventTarget(file.element) }
	assert target.dispatch_event(dom.Event.create('mousedown', dom.EventInit{}))
	assert window.has_transient_activation()
	file.show_picker()!
	assert file.is_open()
	assert owner.client().events.len == before + 1
	assert owner.client().events.last().name == 'request-file-picker'
	assert owner.client().events.last().text == '.png:true'
	assert math.is_inf(window.last_activation_timestamp(), -1)
	assert window.has_sticky_activation() && !window.has_transient_activation()
	rejected = false
	color.show_picker() or {
		rejected = true
		assert err.msg().starts_with('NotAllowedError:')
	}
	assert rejected && !color.is_open()
	assert owner.client().events.len == before + 1
	mut mutable_owner := unsafe { &page.Page(owner) }
	mutable_owner.file_picker_closed([])
	input_picker_owner_activate(document)
	color.show_picker()!
	assert owner.client().events.last().name == 'request-color-picker'
	assert owner.client().events.last().text == '#123456'
	assert !window.has_transient_activation()
}

fn test_input_picker_preserves_source_error_order_origin_exemptions_and_unsupported_consumption() {
	mut document, window, owner := input_picker_owner_document('https://input-picker-origin.example/', '<input id=text><input id=file type=file><input id=color type=color>')!
	defer { document.finalize() }
	mut text := input_picker_owner_model(document, 'text')!
	mut file := input_picker_owner_model(document, 'file')!
	mut color := input_picker_owner_model(document, 'color')!
	mut settings := window.environment_settings_.settings
	settings.environment_.top_level_origin = dom.URL{'https://foreign-picker-top.example/'}.origin()
	mut element := document.get_element_by_id('text')?
	element.set_attribute_value('disabled', '')
	mut rejection := ''
	text.show_picker() or { rejection = err.msg() }
	assert rejection.starts_with('InvalidStateError:')
	element.remove_attribute('disabled')
	text.show_picker() or { rejection = err.msg() }
	assert rejection.starts_with('SecurityError:')
	input_picker_owner_activate(document)
	text.show_picker() or { rejection = err.msg() }
	assert rejection.starts_with('SecurityError:') && window.has_transient_activation()
	file.show_picker()!
	assert file.is_open() && !window.has_transient_activation()
	assert owner.client().events.last().name == 'request-file-picker'
	mut mutable_owner := unsafe { &page.Page(owner) }
	mutable_owner.file_picker_closed([])
	input_picker_owner_activate(document)
	color.show_picker()!
	assert color.is_open() && !window.has_transient_activation()
	assert owner.client().events.last().name == 'request-color-picker'
	settings.environment_.top_level_origin = document.origin()
	text.show_picker() or { rejection = err.msg() }
	assert rejection.starts_with('NotAllowedError:')
	before := owner.client().events.len
	input_picker_owner_activate(document)
	text.show_picker()!
	assert !text.is_open() && !window.has_transient_activation()
	assert owner.client().events.len == before
}

fn test_input_picker_adoption_reads_new_native_global_and_actual_page() {
	mut original, original_window, original_owner := input_picker_owner_document('https://input-picker-adoption.example/', '<input id=file type=file><input id=text>')!
	mut replacement, replacement_window, replacement_owner := input_picker_owner_document('https://adopted-picker.example/', '<main id=host></main>')!
	defer {
		original.finalize()
		replacement.finalize()
	}
	mut file := input_picker_owner_model(original, 'file')!
	mut text := input_picker_owner_model(original, 'text')!
	mut original_settings := original_window.environment_settings_.settings
	original_settings.environment_.top_level_origin = dom.URL{'https://foreign-original-picker-top.example/'}.origin()
	input_picker_owner_activate(original)
	mut rejection := ''
	text.show_picker() or { rejection = err.msg() }
	assert rejection.starts_with('SecurityError:')
	_ = replacement.adopt_node_binding(unsafe { &dom.Node(file.element) })!
	host := replacement.get_element_by_id('host')?
	mut host_node := host.as_node()
	host_node.append_child(unsafe { &dom.Node(file.element) })!
	_ = replacement.adopt_node_binding(unsafe { &dom.Node(text.element) })!
	host_node.append_child(unsafe { &dom.Node(text.element) })!
	assert unsafe { &dom.Element(file.element) }.document() == replacement
	text.show_picker() or { rejection = err.msg() }
	assert rejection.starts_with('NotAllowedError:')
	mut rejected := false
	file.show_picker() or {
		rejected = true
		assert err.msg().starts_with('NotAllowedError:')
	}
	assert rejected && original_window.has_transient_activation()
	before_original := original_owner.client().events.len
	before_replacement := replacement_owner.client().events.len
	target := unsafe { &dom.EventTarget(file.element) }
	assert target.dispatch_event(dom.Event.create('mousedown', dom.EventInit{}))
	assert replacement_window.has_transient_activation()
	assert original_window.has_transient_activation()
	file.show_picker()!
	assert replacement_owner.client().events.len == before_replacement + 1
	assert replacement_owner.client().events.last().name == 'request-file-picker'
	assert original_owner.client().events.len == before_original
	assert original_window.has_transient_activation()
	assert !replacement_window.has_transient_activation()
}

fn test_input_picker_consumes_actual_logical_top_and_child_windows() {
	mut top, top_window, top_owner := input_picker_owner_document('https://input-picker-top.example/', '<iframe id=child></iframe>')!
	mut child, child_window, child_owner := input_picker_owner_document('https://cross-origin-picker-child.example/', '<input id=file type=file>')!
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
	assert !picker_origin_is_same_as_top_level(unsafe { &dom.Element(input_picker_owner_model(child, 'file')!.element) })
	input_picker_owner_activate(top)
	input_picker_owner_activate(child)
	before_top := top_owner.client().events.len
	before_child := child_owner.client().events.len
	mut file := input_picker_owner_model(child, 'file')!
	file.show_picker()!
	assert math.is_inf(top_window.last_activation_timestamp(), -1)
	assert math.is_inf(child_window.last_activation_timestamp(), -1)
	assert child_owner.client().events.len == before_child + 1
	assert child_owner.client().events.last().name == 'request-file-picker'
	assert top_owner.client().events.len == before_top
}
