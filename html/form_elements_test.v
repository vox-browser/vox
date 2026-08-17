module html

import dom

fn form_elements_find(node &dom.Node, name string) ?&dom.Element {
	if element := node.as_element() {
		if element.local_name() == name {
			return element
		}
	}
	for child in node.children_as_vector() {
		if element := form_elements_find(child, name) {
			return element
		}
	}
	return none
}

fn test_textarea_value_constraints_dimensions_selection_and_reset() {
	document :=
		parse_document('<textarea required minlength="3" maxlength="5" placeholder="hint\nignored">ab</textarea>')
	element := form_elements_find(unsafe { &dom.Node(document) }, 'textarea') or {
		panic('textarea')
	}
	mut textarea := HTMLTextAreaElementModel.create(unsafe { &dom.HTMLTextAreaElement(element) })
	assert textarea.default_value() == 'ab'
	assert textarea.value() == 'ab'
	assert textarea.cols() == 20
	assert textarea.rows() == 2
	assert textarea.placeholder_value()? == 'hint'
	textarea.set_value('abcdef')
	assert textarea.control.suffering_from_being_too_long()
	assert textarea.text.selection_start() == 6
	textarea.set_max_length(10)!
	textarea.set_min_length(2)!
	textarea.set_cols(40)
	textarea.set_rows(8)
	assert textarea.cols() == 40
	assert textarea.rows() == 8
	textarea.text.set_selection_range(1, 3, 'forward')!
	textarea.text.set_range_text('Z', 1, 3, .select)!
	assert textarea.value() == 'aZdef'
	textarea.reset()
	assert textarea.value() == 'ab'
	textarea.clear()
	assert textarea.control.suffering_from_being_missing()
}

fn test_button_type_value_and_command() {
	document := parse_document('<button value="go">Go</button>')
	element := form_elements_find(unsafe { &dom.Node(document) }, 'button') or { panic('button') }
	button := unsafe { &dom.HTMLButtonElement(element) }
	assert html_button_element_type_state(button) == .auto
	assert html_button_element_is_submit_button(button)
	assert html_button_element_type(button) == 'submit'
	assert html_button_element_value(button) == 'go'
	set_html_button_element_command(button, '--custom')
	assert html_button_element_command(button) == '--custom'
	assert !html_button_element_is_submit_button(button)
	set_html_button_element_type(button, 'reset')
	assert html_button_element_type(button) == 'reset'
}

fn test_form_validation_entries_get_post_and_reset() {
	document :=
		parse_document('<form action="/submit" method="get"><input name="q" value="hello world"><button name="send" value="yes"></button></form>')
	form_element := form_elements_find(unsafe { &dom.Node(document) }, 'form') or { panic('form') }
	input_element := form_elements_find(unsafe { &dom.Node(document) }, 'input') or {
		panic('input')
	}
	button_element_ := form_elements_find(unsafe { &dom.Node(document) }, 'button') or {
		panic('button')
	}
	mut form := HTMLFormElementModel.create(unsafe { &dom.HTMLFormElement(form_element) })
	mut input := FormAssociatedElement.create(input_element)
	input.value_ = 'hello world'
	mut button := FormAssociatedElement.create(button_element_)
	button.value_ = 'yes'
	form.add_control(mut input)
	form.add_control(mut button)
	assert form.length() == 2
	form.submit(button, false)!
	submission := form.last_submission() or { panic('submission') }
	assert submission.method == .get
	assert submission.url.serialize().contains('q=hello+world')
	assert submission.url.serialize().contains('send=yes')

	mut form_dom_element := form_element
	form_dom_element.set_attribute_value('method', 'post')
	form_dom_element.set_attribute_value('enctype', 'text/plain')
	form.submit(none, true)!
	post := form.last_submission() or { panic('post') }
	assert post.method == .post
	assert post.content_type == 'text/plain'
	assert post.body.bytestr().contains('q=hello world')
	input.value_ = 'changed'
	form.reset()
	assert input.value() == input_element.get_attribute_value('value')
}
