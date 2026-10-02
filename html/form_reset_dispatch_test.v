module html

import dom

fn form_reset_control(document &dom.Document, id string) &dom.Element {
	return document.get_element_by_id(id) or { panic('Missing ${id}') }
}

fn test_form_reset_invokes_concrete_control_algorithms() {
	document := parse_document('<form id="f"><input id="check" type="checkbox" checked><input id="files" type="file"><input id="text" value="initial"><textarea id="area">original</textarea><select id="select"><option>A</option><option selected>B</option></select><output id="out">default</output></form>')
	mut form := HTMLFormElementModel.create(unsafe { &dom.HTMLFormElement(form_reset_control(document, 'f')) })
	mut checkbox := HTMLInputElementModel.create(unsafe { &dom.HTMLInputElement(form_reset_control(document, 'check')) })
	mut files := HTMLInputElementModel.create(unsafe { &dom.HTMLInputElement(form_reset_control(document, 'files')) })
	mut input := HTMLInputElementModel.create(unsafe { &dom.HTMLInputElement(form_reset_control(document, 'text')) })
	mut textarea := HTMLTextAreaElementModel.create(unsafe { &dom.HTMLTextAreaElement(form_reset_control(document, 'area')) })
	mut select_ := HTMLSelectElementModel.create(unsafe { &dom.HTMLSelectElement(form_reset_control(document, 'select')) })
	mut output := HTMLOutputElementModel.create(unsafe { &dom.HTMLOutputElement(form_reset_control(document, 'out')) })
	mut output_control := FormAssociatedElement.create(unsafe { &dom.Element(output.element) })
	form.add_control(mut checkbox.control)
	form.add_control(mut files.control)
	// Input creation already associates its DOM identity with its ancestor
	// form. Reset must include it without separate model-array registration.
	form.add_control(mut textarea.control)
	mut select_control := unsafe { &FormAssociatedElement(select_.control) }
	form.add_control(mut select_control)
	form.add_control(mut output_control)
	checkbox.set_checked(false)
	files.set_files([SelectedFile.from_contents('sample.txt', 'data'.bytes())])
	input.set_value('changed')!
	textarea.set_value('changed')
	select_.options().set_selected_index(0)
	output.set_value('changed')
	checkbox.user_validity_ = true
	select_.user_validity_ = true
	assert checkbox.element.dirty_checkedness_
	assert files.files()?.len == 1
	assert input.dirty_value_
	assert textarea.dirty_value
	form.reset()
	assert checkbox.checked()
	assert !checkbox.element.dirty_checkedness_
	assert !checkbox.user_validity_
	assert files.files()?.len == 0
	assert input.value() == 'initial'
	assert !input.dirty_value_
	assert input.text_control.relevant_value() == 'initial'
	assert textarea.value() == 'original'
	assert !textarea.dirty_value
	assert textarea.text.relevant_value() == 'original'
	assert select_.options().selected_index() == 1
	assert !select_.user_validity_
	assert output.value() == 'default'
	assert output.default_value_override_ == none
}

fn test_cancelled_form_reset_leaves_concrete_control_state_intact() {
	document := parse_document('<form id="f"><input id="check" type="checkbox" checked></form>')
	mut form := HTMLFormElementModel.create(unsafe { &dom.HTMLFormElement(form_reset_control(document, 'f')) })
	mut checkbox := HTMLInputElementModel.create(unsafe { &dom.HTMLInputElement(form_reset_control(document, 'check')) })
	form.add_control(mut checkbox.control)
	checkbox.set_checked(false)
	form.event_target().add_event_listener_without_options('reset', dom.IDLEventListener.create(&dom.CallbackType{
		handle_event: fn (event &dom.Event, _ ?&dom.EventTarget) dom.JSValue {
			mut mutable_event := unsafe { &dom.Event(event) }
			mutable_event.prevent_default()
			return dom.js_undefined()
		}
	}))
	form.reset()
	assert !checkbox.checked()
	assert checkbox.element.dirty_checkedness_
}
