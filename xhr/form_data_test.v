module xhr

import fileapi
import dom
import html
import time

@[heap]
struct FormDataVisitLog {
mut:
	names []string
}

fn test_form_data_append_get_all_delete_set_and_blob_files() {
	mut data := FormData.create()
	data.append('a', 'one')
	data.append('a', 'two')
	assert data.has('a')
	first := data.get('a') or { panic('missing') }
	assert first is string
	assert first == 'one'
	assert data.get_all('a').len == 2
	data.set('a', 'replacement')
	assert data.get_all('a').len == 1
	assert data.get('a') or { panic('missing') } == FormDataEntryValue('replacement')
	blob := fileapi.Blob.create([u8(1), 2], 'application/octet-stream')
	before := time.now().unix_milli()
	data.append_blob('file', blob, 'x.bin')
	file_value := data.get('file') or { panic('missing') }
	assert file_value is FormDataFile
	file := (file_value as FormDataFile).file
	assert file.name() == 'x.bin'
	assert file.raw_bytes() == [u8(1), 2]
	assert file.last_modified() >= before
	original := fileapi.File.create([u8(9)], 'original.bin', 'application/octet-stream', 42)
	data.set_file('file', original, 'renamed.bin')
	replacement := (data.get('file') or { panic('missing') } as FormDataFile).file
	assert replacement.name() == 'renamed.bin'
	assert replacement.last_modified() == 42
	data.delete('a')
	assert !data.has('a')
}

fn test_form_data_iterator_kinds_and_live_entry_list() {
	mut data := FormData.from_query_entries([['x', '1']!, ['y', '2']!])
	mut entries := data.iterator(.key_value)
	assert entries.prototype_initialized
	first := entries.next()
	assert first.has_key && first.has_value
	assert first.key == 'x'
	assert (first.value as string) == '1'
	data.append('z', '3')
	assert entries.next().key == 'y'
	assert entries.next().key == 'z'
	assert entries.next().done
}

fn test_form_data_for_each_can_stop_iteration() {
	mut data := FormData.from_query_entries([['a', '1']!, ['b', '2']!])
	mut log := &FormDataVisitLog{}
	data.for_each(fn [mut log] (_ FormDataEntryValue, name string) IterationDecision {
		log.names << name
		return .break_
	})
	assert log.names == ['a']
}

fn test_form_data_create_from_form_validates_submitter_and_converts_entries() {
	mut document := dom.Document.create(dom.URL{ value: 'https://example.test/' })
	form_node := document.create_element_ns('http://www.w3.org/1999/xhtml', 'form')!
	form_element := unsafe { &dom.HTMLFormElement(form_node) }
	mut form := html.HTMLFormElementModel.create(form_element)
	mut input_element := document.create_element_ns('http://www.w3.org/1999/xhtml', 'input')!
	input_element.set_attribute_value('name', 'field')
	mut input := html.FormAssociatedElement.create(input_element)
	input.value_ = 'value'
	form.add_control(mut input)
	data := FormData.create_from_form(form, none)!
	assert data.get('field')? == FormDataEntryValue('value')

	mut button_element := document.create_element_ns('http://www.w3.org/1999/xhtml', 'button')!
	button_element.set_attribute_value('name', 'send')
	mut button := html.FormAssociatedElement.create(button_element)
	button.value_ = 'yes'
	form.add_control(mut button)
	with_submitter := FormData.create_from_form(form, button)!
	assert with_submitter.get('send')? == FormDataEntryValue('yes')

	mut non_submit_element := document.create_element_ns('http://www.w3.org/1999/xhtml', 'input')!
	non_submit_element.set_attribute_value('type', 'text')
	non_submit := html.FormAssociatedElement.create(non_submit_element)
	if _ := FormData.create_from_form(form, non_submit) {
		assert false
	} else {
		assert err.msg().starts_with('TypeError:')
	}

	other_form_node := document.create_element_ns('http://www.w3.org/1999/xhtml', 'form')!
	other_form_element := unsafe { &dom.HTMLFormElement(other_form_node) }
	mut other_form := html.HTMLFormElementModel.create(other_form_element)
	foreign_button_element := document.create_element_ns('http://www.w3.org/1999/xhtml', 'button')!
	mut foreign_button := html.FormAssociatedElement.create(foreign_button_element)
	other_form.add_control(mut foreign_button)
	if _ := FormData.create_from_form(form, foreign_button) {
		assert false
	} else {
		assert err.msg().starts_with('NotFoundError:')
	}
}

fn test_form_data_from_form_retains_native_file_and_event_mutations() {
	document := html.parse_document('<form id="f"><input id="file" type="file" name="upload"></form>')
	form := html.HTMLFormElementModel.create(unsafe {
		&dom.HTMLFormElement(document.get_element_by_id('f')?)
	})
	mut input := html.HTMLInputElementModel.create(unsafe {
		&dom.HTMLInputElement(document.get_element_by_id('file')?)
	})
	mut files := fileapi.FileList.create()
	file := fileapi.File.create([u8(1), 2], 'selected.bin', 'application/octet-stream', 123)
	files.add_file(file)
	input.set_file_list(files)
	form.event_target().add_event_listener_without_options('formdata', dom.IDLEventListener.create(&dom.CallbackType{
		handle_event: fn [form] (event &dom.Event, _ ?&dom.EventTarget) dom.JSValue {
			if _ := FormData.create_from_form(form, none) {
				assert false, 'recursive FormData construction must throw'
			} else {
				assert err.msg().starts_with('InvalidStateError:')
			}
			mut data := unsafe { &html.FormDataEvent(event) }.form_data() or { panic('formData') }
			data.append(html.create_form_data_string_entry('listener', 'value'))
			return dom.js_undefined()
		}
	}))
	data := FormData.create_from_form(form, none)!
	assert (data.get('upload')? as FormDataFile).file == file
	assert data.get('listener')? == FormDataEntryValue('value')
	button := document.create_element_ns('http://www.w3.org/1999/xhtml', 'button')!
	unowned := html.HTMLButtonElementModel.create(unsafe { &dom.HTMLButtonElement(button) })
	if _ := FormData.create_from_form(form, unowned.control) {
		assert false
	} else {
		assert err.msg().starts_with('NotFoundError:')
	}
}

fn test_progress_event_inherits_event_init_members() {
	event := ProgressEvent.construct('progress', ProgressEventInit{
		bubbles:           true
		cancelable:        true
		composed:          true
		length_computable: true
		loaded:            2
		total:             4
	})
	assert event.bubbles && event.cancelable && event.composed
	assert event.length_computable() && event.loaded() == 2 && event.total() == 4
}

fn test_exact_form_data_progress_and_iterator_entry_points() {
	mut data := FormData.construct_impl([FormDataEntry{ name: 'a', value: 'one' }])
	data.append_impl('a', FormDataAppendValue('two'), none)
	assert data.entry_list().len == 2
	data.set_impl('a', FormDataAppendValue('three'), none)
	assert data.entry_list().len == 1
	data.delete_('a')
	assert data.entry_list().len == 0
	mut iterator := FormDataIterator.create(data, .key)
	assert iterator.next().done

	event := ProgressEvent.construct_impl('progress', ProgressEventInit{
		length_computable: true
		loaded:            3
		total:             5
	})
	assert event.length_computable()
	assert event.loaded() == 3
	assert event.total() == 5

	mut target := XMLHttpRequestEventTarget{}
	target.set_onprogress(true)
	assert target.onprogress()
	target.dispatch('progress', 3, 5)
	assert target.events[0].loaded() == 3
}
