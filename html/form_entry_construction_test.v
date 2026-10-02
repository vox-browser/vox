module html

import dom
import fileapi

fn entry_test_form(document &dom.Document) &HTMLFormElementModel {
	return HTMLFormElementModel.create(unsafe {
		&dom.HTMLFormElement(document.get_element_by_id('form') or { panic('form') })
	})
}

fn entry_test_input(document &dom.Document, id string) &HTMLInputElementModel {
	return HTMLInputElementModel.create(unsafe {
		&dom.HTMLInputElement(document.get_element_by_id(id) or { panic(id) })
	})
}

fn entry_test_strings(entries []FormDataEntry) [][2]string {
	mut result := [][2]string{}
	for entry in entries {
		if entry.value is string {
			result << [entry.name, entry.value]!
		}
	}
	return result
}

fn test_construct_entries_uses_tree_order_checkedness_options_encoding_and_direction() {
	document := parse_document('<form id="form"><input id="text" name="text" value="initial" dirname="direction" dir="rtl"><input id="off" name="off" type="checkbox"><input id="on" name="on" type="checkbox" checked value=""><input id="radio" name="radio" type="radio" checked value="chosen"><select id="select" multiple name="select"><option selected value="first">First</option><option selected disabled value="skip">Skip</option><optgroup disabled><option selected value="group">Group</option></optgroup><option selected value="last">Last</option></select><input id="charset" type="hidden" name="_ChArSeT_" value="ignored"><datalist><input id="datalist" name="datalist" value="skip"></datalist><fieldset disabled><legend><input id="legend" name="legend" value="kept"></legend><input id="disabled" name="disabled" value="skip"></fieldset><button id="button" name="button" value="skip"></button></form>')
	form := entry_test_form(document)
	// Materialize in reverse order; associated DOM membership, rather than the
	// model registration order, supplies the source tree-order snapshot.
	for id in ['disabled', 'legend', 'datalist', 'charset', 'radio', 'on', 'off', 'text'] {
		entry_test_input(document, id)
	}
	select_element := document.get_element_by_id('select')?
	select_ := HTMLSelectElementModel.create(unsafe { &dom.HTMLSelectElement(select_element) })
	mut select_control := unsafe { &FormAssociatedElement(select_.control) }
	select_control.set_form(form.element)
	HTMLButtonElementModel.create(unsafe { &dom.HTMLButtonElement(document.get_element_by_id('button')?) })
	mut text := entry_test_input(document, 'text')
	text.set_value('live')!
	entries := form.construct_entry_list_with_encoding(none, 'windows-1251')?
	assert entry_test_strings(entries) == [
		['text', 'live']!,
		['direction', 'rtl']!,
		['on', 'on']!,
		['radio', 'chosen']!,
		['select', 'first']!,
		['select', 'last']!,
		['_ChArSeT_', 'windows-1251']!,
		['legend', 'kept']!,
	]
	assert !form.constructing_entry_list()
	utf8 := form.construct_entry_list_with_encoding(none, none)?
	assert entry_test_strings(utf8)[6] == ['_ChArSeT_', 'UTF-8']!
}

fn test_construct_entries_preserves_files_and_image_button_coordinates() {
	document := parse_document('<form id="form"><input id="empty" name="empty" type="file"><input id="files" name="files" type="file" multiple><input id="image" name="location" type="image"><input id="unnamed" type="image"></form>')
	form := entry_test_form(document)
	entry_test_input(document, 'empty')
	mut input := entry_test_input(document, 'files')
	mut files := fileapi.FileList.create()
	first := fileapi.File.create('one'.bytes(), 'one.txt', 'text/plain', 1234)
	second := fileapi.File.create([u8(0), 1], 'two.bin', 'application/octet-stream', 5678)
	files.add_file(first)
	files.add_file(second)
	input.set_file_list(files)
	mut image := entry_test_input(document, 'image')
	image.selected_x_ = 13
	image.selected_y_ = 29
	unnamed := entry_test_input(document, 'unnamed')
	entries := form.construct_entry_list_with_encoding(image.control, none)?
	assert entries.len == 5
	empty := entries[0].value as FormDataFile
	assert entries[0].name == 'empty'
	assert empty.name == '' && empty.mime_type == 'application/octet-stream'
	assert empty.bytes.len == 0
	assert empty.file != none
	assert (entries[1].value as FormDataFile).file? == first
	assert (entries[2].value as FormDataFile).file? == second
	assert entry_test_strings(entries) == [['location.x', '13']!, ['location.y', '29']!]
	other := form.construct_entry_list_with_encoding(unnamed.control, none)?
	assert entry_test_strings(other) == [['x', '0']!, ['y', '0']!]
}

fn test_formdata_event_mutates_result_bubbles_and_blocks_recursive_construction() {
	document := parse_document('<div id="parent"><form id="form"><input id="a" name="a" value="old"><input id="b" name="b" value="remove"></form></div>')
	form := entry_test_form(document)
	entry_test_input(document, 'a')
	entry_test_input(document, 'b')
	mut bubbled := &[]int{}
	parent := document.get_element_by_id('parent')?
	unsafe { &dom.EventTarget(parent.as_node()) }.add_event_listener_without_options('formdata',
		dom.IDLEventListener.create(&dom.CallbackType{
			handle_event: fn [mut bubbled] (event &dom.Event, _ ?&dom.EventTarget) dom.JSValue {
				assert event.interface_ == .form_data_event
				bubbled << 1
				return dom.js_undefined()
			}
		}))
	form.event_target().add_event_listener_without_options('formdata', dom.IDLEventListener.create(&dom.CallbackType{
		handle_event: fn [form] (event &dom.Event, _ ?&dom.EventTarget) dom.JSValue {
			assert form.constructing_entry_list()
			assert HTMLFormElementModel.create(form.element) == form
			assert form.construct_entry_list_with_encoding(none, none) == none
			assert event.bubbles() && !event.cancelable()
			mut data := unsafe { &FormDataEvent(event) }.form_data() or { panic('formData') }
			data.set(create_form_data_string_entry('a', 'changed'))
			data.delete('b')
			data.append(create_form_data_string_entry('added', 'listener'))
			return dom.js_undefined()
		}
	}))
	entries := form.construct_entry_list_with_encoding(none, none)?
	assert entry_test_strings(entries) == [['a', 'changed']!, ['added', 'listener']!]
	assert bubbled.len == 1
	assert !form.constructing_entry_list()
}

fn test_form_submission_serializes_formdata_listener_changes() {
	mut document := parse_document('<form id="form" action="/submit" method="post" enctype="text/plain"><input id="text" name="field" value="old"></form>')
	document.set_url(dom.URL{ value: 'https://example.test/form' })
	mut navigable := &dom.Navigable{
		active_document_: document
		is_top_level_traversable_: true
	}
	navigable.traversable_navigable_ = navigable
	document.set_cached_navigable(navigable)
	mut form := entry_test_form(document)
	entry_test_input(document, 'text')
	form.event_target().add_event_listener_without_options('formdata', dom.IDLEventListener.create(&dom.CallbackType{
		handle_event: fn (event &dom.Event, _ ?&dom.EventTarget) dom.JSValue {
			mut data := unsafe { &FormDataEvent(event) }.form_data() or { panic('formData') }
			data.set(create_form_data_string_entry('field', 'sent'))
			return dom.js_undefined()
		}
	}))
	form.submit()!
	submission := form.last_submission() or { panic('missing submission') }
	assert submission.body.bytestr() == 'field=sent\r\n'
	assert entry_test_strings(submission.entries) == [['field', 'sent']!]
}

fn test_custom_form_entries_expand_lists_without_name_and_preserve_file_identity() {
	mut document := parse_document('<form id="form"></form>')
	form := entry_test_form(document)
	mut form_node := unsafe { &dom.Element(form.element) }.as_node()
	mut list_element := document.create_element_ns('http://www.w3.org/1999/xhtml', 'x-list')!
	list_element.setup_custom_element_from_constructor(&dom.CustomElementDefinition{
		name_:            'x-list'
		form_associated_: true
	}, none)
	form_node.append_child(list_element.as_node())!
	mut list_target := unsafe { &dom.HTMLElement(list_element) }
	mut list_internals := ElementInternals.create(list_target)
	list_target.set_attached_internals_handle(voidptr(list_internals))
	list_internals.set_form_value(ElementInternalsFormData{
		entries: [create_form_data_string_entry('custom-a', 'one'),
			create_form_data_string_entry('custom-b', 'two')]
	}, none)!
	mut file_element := document.create_element_ns('http://www.w3.org/1999/xhtml', 'x-file')!
	file_element.setup_custom_element_from_constructor(&dom.CustomElementDefinition{
		name_:            'x-file'
		form_associated_: true
	}, none)
	file_element.set_attribute_value('name', 'custom-file')
	form_node.append_child(file_element.as_node())!
	mut file_target := unsafe { &dom.HTMLElement(file_element) }
	mut file_internals := ElementInternals.create(file_target)
	file_target.set_attached_internals_handle(voidptr(file_internals))
	file := fileapi.File.create('data'.bytes(), 'test.txt', 'text/plain', 42)
	file_value := create_form_data_native_file_entry('ignored', file).value as FormDataFile
	file_internals.set_form_value(file_value, none)!
	entries := form.construct_entry_list_with_encoding(none, none)?
	assert entries.len == 3
	assert entry_test_strings(entries) == [['custom-a', 'one']!, ['custom-b', 'two']!]
	assert entries[2].name == 'custom-file'
	assert (entries[2].value as FormDataFile).file? == file
	file_internals.submission_value = none
	assert form.construct_entry_list_with_encoding(none, none)?.len == 2
}
