@[has_globals]
module html

import css
import dom

__global (
	textarea_event_types        []string
	textarea_event_input_types  []string
	textarea_event_data         []string
	textarea_event_composed     []bool
	textarea_event_is_composing []bool
)

fn record_textarea_event(event &dom.Event, _ ?&dom.EventTarget) dom.JSValue {
	unsafe {
		textarea_event_types << event.type_name()
		if event.interface_ == .input_event {
			input_event := &dom.InputEvent(event)
			textarea_event_input_types << input_event.input_type()
			textarea_event_data << input_event.data() or { '' }
			textarea_event_composed << input_event.composed()
			textarea_event_is_composing << input_event.is_composing()
		}
	}
	return dom.js_undefined()
}

fn drain_form_element_tasks() {
	mut event_loop := main_thread_event_loop()
	for event_loop.task_queue().has_runnable_tasks() {
		event_loop.process()
	}
}

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

fn form_elements_make_document_fully_active(mut document dom.Document) {
	mut navigable := &dom.Navigable{
		active_document_: &document
		is_top_level_traversable_: true
	}
	navigable.traversable_navigable_ = navigable
	document.set_cached_navigable(navigable)
}

fn test_textarea_value_constraints_dimensions_selection_and_reset() {
	mut document := parse_document('<textarea required minlength="3" maxlength="5" placeholder="hint\nignored">ab</textarea>')
	form_elements_make_document_fully_active(mut document)
	element := form_elements_find(unsafe { &dom.Node(document) }, 'textarea') or {
		panic('textarea')
	}
	mut textarea := HTMLTextAreaElementModel.create(unsafe { &dom.HTMLTextAreaElement(element) })
	assert textarea.default_value() == 'ab'
	assert textarea.value() == 'ab'
	assert textarea.cols() == 20
	assert textarea.rows() == 2
	textarea.create_shadow_tree_if_needed()
	assert textarea.placeholder_value() == none
	textarea.set_value('abcdef')
	// Only a value last changed by a user edit can be too long.
	assert !textarea.control.suffering_from_being_too_long()
	assert textarea.text.selection_start() == 6
	mut edited_text := textarea.text_node_ or { panic('textarea text node') }
	edited_text.set_data('abcdefg')
	textarea.did_edit_text_node('insertText', 'g')
	assert textarea.control.suffering_from_being_too_long()
	textarea.set_value('abcdef')
	assert !textarea.control.suffering_from_being_too_long()
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
	assert textarea.placeholder_value()? == 'hint\nignored'
	drain_form_element_tasks()
}

fn test_input_length_constraints_apply_only_to_user_edits() {
	mut document := parse_document('<input maxlength="3" minlength="2">')
	form_elements_make_document_fully_active(mut document)
	element := form_elements_find(unsafe { &dom.Node(document) }, 'input') or { panic('input') }
	mut input := HTMLInputElementModel.create(unsafe { &dom.HTMLInputElement(element) })
	input.set_value('abcd')!
	assert !input.control.suffering_from_being_too_long()
	input.set_value('a')!
	assert !input.control.suffering_from_being_too_short()
	mut text_node := input.text_node_ or { panic('input text node') }
	text_node.set_data('abcde')
	input.did_edit_text_node('insertText', 'e')
	assert input.control.suffering_from_being_too_long()
	text_node.set_data('x')
	input.did_edit_text_node('deleteContentBackward', none)
	assert input.control.suffering_from_being_too_short()
	input.set_value('x')!
	assert !input.control.suffering_from_being_too_short()
}

fn test_cloned_input_copies_value_dirtiness_checkedness_and_indeterminateness() {
	mut document := parse_document('<input id="text"><input id="box" type="checkbox">')
	form_elements_make_document_fully_active(mut document)
	text_element := document.get_element_by_id('text') or { panic('text input') }
	mut text := HTMLInputElementModel.create(unsafe { &dom.HTMLInputElement(text_element) })
	text.set_value('foo bar')!
	text_copy := text_element.as_node().clone_node(none, false, none)!
	mut copy := HTMLInputElementModel.create(unsafe { &dom.HTMLInputElement(text_copy.as_element() or { panic('copy') }) })
	assert copy.value() == 'foo bar'
	mut copy_element := text_copy.as_element() or { panic('copy') }
	copy_element.set_attribute_value('value', 'something else')
	assert copy.value() == 'foo bar'

	box_element := document.get_element_by_id('box') or { panic('checkbox') }
	mut box := unsafe { &dom.HTMLInputElement(box_element) }
	box.set_checkedness(true, true)
	box.set_indeterminate(true)
	box_copy := box_element.as_node().clone_node(none, false, none)!
	copied_box := unsafe { &dom.HTMLInputElement(box_copy.as_element() or { panic('copy') }) }
	assert copied_box.checked()
	assert copied_box.indeterminate()
}

fn test_window_selection_stringifier_uses_focused_text_control_selection() {
	mut document := parse_document('<textarea>Ladybird</textarea>')
	form_elements_make_document_fully_active(mut document)
	element := form_elements_find(unsafe { &dom.Node(document) }, 'textarea') or {
		panic('textarea')
	}
	mut textarea := HTMLTextAreaElementModel.create(unsafe { &dom.HTMLTextAreaElement(element) })
	textarea.text.set_selection_range(1, 5, 'forward')!
	document.set_focused_area(element.as_node())
	selection := dom.Selection.create(document)
	assert selection.is_empty()
	assert selection.to_string() == 'adyb'
	assert html_text_area_element_model_for_dom_element(unsafe {
		&dom.HTMLTextAreaElement(element)}) == textarea
}

fn test_document_active_input_events_target_uses_focused_form_text_control() {
	mut document := dom.Document.create_for_fragment_parsing()
	input_element := document.create_element_ns('http://www.w3.org/1999/xhtml', 'input')!
	mut input := HTMLInputElementModel.create(unsafe { &dom.HTMLInputElement(input_element) })
	document.set_focused_area(input_element.as_node())

	mut target := document.active_input_events_target(none) or {
		assert false, 'focused text input did not expose its InputEventsTarget'
		return
	}
	assert voidptr(target) == voidptr(input.text_control)

	input.set_type('button')
	assert document.active_input_events_target(none) == none

	textarea_element := document.create_element_ns('http://www.w3.org/1999/xhtml', 'textarea')!
	mut textarea := HTMLTextAreaElementModel.create(unsafe { &dom.HTMLTextAreaElement(textarea_element) })
	textarea.create_shadow_tree_if_needed()
	textarea.set_value('Ladybird')
	textarea.text.set_selection_range(2, 4, 'forward')!
	document.set_focused_area(textarea_element.as_node())
	target = document.active_input_events_target(none) or {
		assert false, 'focused textarea did not expose its InputEventsTarget'
		return
	}
	assert voidptr(target) == voidptr(textarea.text)
	target.select_all()
	assert textarea.text.selection_start() == 0
	assert textarea.text.selection_end() == 8
	target.handle_insert_from_clipboard(dom.input_type_insert_from_paste, 'V', '<b>ignored</b>')
	assert textarea.value() == 'V'
	target.move_cursor_to_start(.yes)
	assert textarea.text.selection_start() == 0
	assert textarea.text.selection_end() == 0
	assert target.handle_return_key(dom.input_type_insert_line_break) == .handled
	assert textarea.value() == '\nV'
	text_node := textarea.text.text_node_ or { panic('missing textarea text node') }
	assert target.mouse_selection_scope()? == text_node.as_node()
	target.set_selection_anchor(text_node.as_node(), 0, .upstream)
	target.set_selection_focus(text_node.as_node(), 1, .downstream)
	assert textarea.text.selection_start() == 0
	assert textarea.text.selection_end() == 1
}

fn test_document_cursor_position_and_blink_timer_use_form_text_control() {
	mut document := dom.Document.create_for_fragment_parsing()
	input_element := document.create_element_ns('http://www.w3.org/1999/xhtml', 'input')!
	input := HTMLInputElementModel.create(unsafe { &dom.HTMLInputElement(input_element) })
	document.set_focused_area(input_element.as_node())

	position := document.cursor_position() or {
		assert false, 'focused text input did not provide a cursor position'
		return
	}
	text_node := input.text_control.text_node_ or {
		assert false, 'text input did not create its editing text node'
		return
	}
	assert voidptr(position.node()?) == voidptr(text_node.as_node())
	assert position.offset() == 0

	document.reset_cursor_blink_cycle()
	assert document.cursor_blink_timer.is_active()
}

fn test_textarea_shadow_selection_lifecycle_editing_and_clone_algorithms() {
	mut document := parse_document('<textarea required maxlength="3" placeholder="hint"></textarea>')
	form_elements_make_document_fully_active(mut document)
	element := form_elements_find(unsafe { &dom.Node(document) }, 'textarea') or {
		panic('textarea')
	}
	mut textarea := HTMLTextAreaElementModel.create(unsafe { &dom.HTMLTextAreaElement(element) })
	textarea.form_associated_element_was_inserted()
	assert element.shadow_root() != none
	assert textarea.default_tab_index_value() == 0
	assert textarea.is_focusable()
	assert textarea.is_mutable()
	assert textarea.suffering_from_being_missing()
	text_node := textarea.text_node_ or { panic('textarea text node') }
	assert text_node.max_length()? == 3
	placeholder := textarea.placeholder_element_ or { panic('placeholder element') }
	assert placeholder.associated_shadow_host_pseudo_element()? == int(css.PseudoElement.placeholder)
	assert element.element_reference_pseudo_element(int(css.PseudoElement.placeholder))? == placeholder
	assert placeholder.get_attribute_value('style').contains('margin-inline-start:-100%')
	inner := textarea.inner_text_element_ or { panic('inner text element') }
	assert inner.get_attribute_value('style').contains('width:100%')
	assert inner.as_node().parent_element()? == placeholder.as_node().parent_element()?

	textarea.set_relevant_value('abcd')!
	assert textarea.api_value() == 'abcd'
	textarea.set_selection_start_binding(1)!
	textarea.set_selection_end_binding(3)!
	textarea.set_selection_direction_binding('backward')
	assert textarea.selection_start_binding() == 1
	assert textarea.selection_end_binding() == 3
	assert textarea.selection_direction_binding() == 'backward'

	mut mutable_element := element
	mutable_element.set_attribute_value('readonly', '')
	assert !textarea.is_mutable()
	assert !textarea.suffering_from_being_missing()
	mutable_element.remove_attribute('readonly')

	unsafe {
		textarea_event_types = []
		textarea_event_input_types = []
		textarea_event_data = []
		textarea_event_composed = []
		textarea_event_is_composing = []
	}
	listener := dom.IDLEventListener.create(&dom.CallbackType{
		handle_event: record_textarea_event
	})
	target := unsafe { &dom.EventTarget(element.as_node()) }
	target.add_event_listener_without_options('input', listener)
	target.add_event_listener_without_options('change', listener)
	mut mutable_text_node := text_node
	mutable_text_node.set_data('xy')
	textarea.did_edit_text_node('insertText', 'y')
	document.set_is_input_method_composing(true)
	textarea.did_edit_text_node('insertText', 'z')
	document.set_is_input_method_composing(false)
	assert textarea.dirty_value
	assert textarea_event_types == ['input', 'input']
	assert textarea_event_input_types == ['insertText', 'insertText']
	assert textarea_event_data == ['y', 'z']
	assert textarea_event_composed == [true, true]
	assert textarea_event_is_composing == [false, true]

	textarea.handle_return_key('insertLineBreak')!
	assert textarea.value().ends_with('\n')
	drain_form_element_tasks()
	assert textarea_event_types == ['input', 'input', 'input']
	textarea.did_receive_focus()
	textarea.did_lose_focus()
	drain_form_element_tasks()
	assert textarea_event_types == ['input', 'input', 'input', 'change']

	textarea.form_associated_element_attribute_changed('placeholder', 'hint', 'other', none)
	placeholder_text := textarea.placeholder_text_node_ or { panic('placeholder text') }
	assert placeholder_text.data() == 'other'
	mutable_element.remove_attribute('maxlength')
	textarea.form_associated_element_attribute_changed('maxlength', '3', none, none)
	assert text_node.max_length() == none

	copy_document := parse_document('<textarea></textarea>')
	copy_element := form_elements_find(unsafe { &dom.Node(copy_document) }, 'textarea') or {
		panic('copy textarea')
	}
	mut copy := HTMLTextAreaElementModel.create(unsafe { &dom.HTMLTextAreaElement(copy_element) })
	textarea.cloned(mut copy, true)
	assert copy.text.relevant_value() == textarea.text.relevant_value()
	assert copy.dirty_value == textarea.dirty_value
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

fn test_button_model_activation_form_dialog_attributes_and_focusability() {
	mut document := parse_document('<form action="https://example.test/submit"><button type="submit" value="go">Submit</button></form><button id="commander" commandfor="dialog" command="show-modal">Open</button><dialog id="dialog"></dialog>')
	form_elements_make_document_fully_active(mut document)
	form_element := form_elements_find(unsafe { &dom.Node(document) }, 'form') or { panic('form') }
	mut form := HTMLFormElementModel.create(unsafe { &dom.HTMLFormElement(form_element) })
	form_button_element := form_elements_find(form_element.as_node(), 'button') or {
		panic('form button')
	}
	mut form_button := HTMLButtonElementModel.create(unsafe {
		&dom.HTMLButtonElement(form_button_element)
	})
	assert form_button.type_for_bindings() == 'submit'
	assert form_button.default_tab_index_value() == 0
	assert form_button.has_activation_behavior()
	assert form_button.is_focusable()
	click := dom.Event.create('click', dom.EventInit{})
	form_button.activation_behavior(click)
	assert form.last_submission() != none

	commander_element := document.get_element_by_id('commander') or { panic('commander') }
	mut commander := HTMLButtonElementModel.create(unsafe { &dom.HTMLButtonElement(commander_element) })
	dialog_element := document.get_element_by_id('dialog') or { panic('dialog') }
	commander.activation_behavior(click)
	assert dialog_element.has_attribute('open')
	mut commander_dom := commander_element
	commander_dom.set_popover_target_element(dialog_element)
	commander.form_associated_element_attribute_changed('popovertarget', none, none, none)
	assert commander_dom.popover_target_element() == none
	commander_dom.set_attribute_value('disabled', '')
	assert !commander.is_focusable()
}

fn test_form_validation_entries_get_post_and_reset() {
	mut document := parse_document('<form action="/submit" method="get"><input name="q" value="hello world"><button name="send" value="yes"></button></form>')
	document.set_url(dom.URL{ value: 'https://example.test/form' })
	form_elements_make_document_fully_active(mut document)
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
	form.request_submit(button)!
	submission := form.last_submission() or { panic('submission') }
	assert submission.method == .get
	assert submission.url.serialize().contains('q=hello+world')
	assert submission.url.serialize().contains('send=yes')

	mut form_dom_element := form_element
	form_dom_element.set_attribute_value('method', 'post')
	form_dom_element.set_attribute_value('enctype', 'text/plain')
	form.submit()!
	post := form.last_submission() or { panic('post') }
	assert post.method == .post
	assert post.content_type == 'text/plain'
	assert post.body.bytestr().contains('q=hello world')
	input.value_ = 'changed'
	form.reset()
	assert input.value() == input_element.get_attribute_value('value')
}

fn test_form_action_method_encoding_rel_and_collection_named_properties() {
	mut document := parse_document('<form action="../submit" accept-charset="bogus windows-1251" rel="next noreferrer"><input id="shared" name="first"><input id="shared" name="second"><input type="image" name="ignored"></form>')
	document.set_url(dom.URL{ value: 'https://example.test/path/page.html' })
	form_elements_make_document_fully_active(mut document)
	form_element := form_elements_find(unsafe { &dom.Node(document) }, 'form') or { panic('form') }
	mut form := HTMLFormElementModel.create(unsafe { &dom.HTMLFormElement(form_element) })
	mut controls := []&FormAssociatedElement{}
	for node in form_element.as_node().children_as_vector() {
		if element := node.as_element() {
			mut control := FormAssociatedElement.create(element)
			form.add_associated_element(mut control)
			controls << control
		}
	}
	assert form.action() == 'https://example.test/submit'
	form.set_action('')
	assert form.action() == 'https://example.test/path/page.html'
	form.set_method('POST')
	assert form.method_state_from_form_element(none) == .post
	assert form.pick_an_encoding() == 'windows-1251'
	assert form.rel_list().contains('noreferrer')
	mut form_dom := form_element
	form_dom.set_attribute_value('rel', 'noopener')
	form.attribute_changed('rel', 'noopener')
	assert form.rel_list().contains('noopener')
	assert !form.rel_list().contains('noreferrer')
	assert form.elements().length() == 2
	assert form.item_value(0)? == controls[0].element
	shared_result := form.named_item_value('shared')
	assert shared_result is HTMLFormControlsCollectionRadioNodeList
	first := form.named_item_value('first')
	assert first is HTMLFormControlsCollectionElement
	assert 'first' in form.supported_property_names()
	form.remove_associated_element(controls[0])
	assert form.named_item_value('first') is HTMLFormControlsCollectionEmpty
}

fn test_form_request_submit_validation_implicit_submission_and_dialog_method() {
	mut document := parse_document('<form><input required><button value="go">Go</button></form>')
	document.set_url(dom.URL{ value: 'https://example.test/form' })
	form_elements_make_document_fully_active(mut document)
	form_element := form_elements_find(unsafe { &dom.Node(document) }, 'form') or { panic('form') }
	input_element := form_elements_find(unsafe { &dom.Node(document) }, 'input') or { panic('input') }
	button_element_ := form_elements_find(unsafe { &dom.Node(document) }, 'button') or { panic('button') }
	mut form := HTMLFormElementModel.create(unsafe { &dom.HTMLFormElement(form_element) })
	mut input := FormAssociatedElement.create(input_element)
	input.missing_ = true
	mut button := FormAssociatedElement.create(button_element_)
	button.value_ = 'go'
	form.add_associated_element(mut input)
	form.add_associated_element(mut button)
	assert !form.statically_validate_constraints().result
	form.request_submit(button)!
	assert form.last_submission() == none
	input.missing_ = false
	assert form.report_validity()
	assert form.default_button()? == button
	assert form.number_of_fields_blocking_implicit_submission() == 1
	form.implicitly_submit_form()!
	assert form.last_submission() != none

	mut outsider := FormAssociatedElement.create(input_element)
	mut rejected := false
	form.request_submit(outsider) or {
		rejected = true
		assert err.msg().starts_with('TypeError:')
	}
	assert rejected

	mut dialog_document := parse_document('<dialog open><form method="dialog"><button value="PASS">Submit</button></form></dialog>')
	dialog_document.set_url(dom.URL{ value: 'https://example.test/dialog' })
	form_elements_make_document_fully_active(mut dialog_document)
	dialog_element := form_elements_find(unsafe { &dom.Node(dialog_document) }, 'dialog') or { panic('dialog') }
	dialog_form_element := form_elements_find(unsafe { &dom.Node(dialog_document) }, 'form') or { panic('dialog form') }
	dialog_button_element := form_elements_find(unsafe { &dom.Node(dialog_document) }, 'button') or { panic('dialog button') }
	mut dialog_form := HTMLFormElementModel.create(unsafe { &dom.HTMLFormElement(dialog_form_element) })
	mut dialog_button := FormAssociatedElement.create(dialog_button_element)
	dialog_button.value_ = 'PASS'
	dialog_form.add_associated_element(mut dialog_button)
	dialog_form.request_submit(dialog_button)!
	dialog := unsafe { &dom.HTMLDialogElement(dialog_element) }
	assert !dialog_element.has_attribute('open')
	assert dialog.return_value_ == 'PASS'
}

fn test_form_submission_scheme_routing_and_mailto_body() {
	mut document := parse_document('<form action="mailto:test@example.test?subject=hello" method="post" enctype="text/plain"><input name="message" value="hello world"></form>')
	document.set_url(dom.URL{ value: 'https://example.test/form' })
	form_elements_make_document_fully_active(mut document)
	form_element := form_elements_find(unsafe { &dom.Node(document) }, 'form') or { panic('form') }
	input_element := form_elements_find(unsafe { &dom.Node(document) }, 'input') or { panic('input') }
	mut form := HTMLFormElementModel.create(unsafe { &dom.HTMLFormElement(form_element) })
	mut input := FormAssociatedElement.create(input_element)
	input.value_ = 'hello world'
	form.add_associated_element(mut input)
	form.submit()!
	submission := form.last_submission() or { panic('mailto submission') }
	assert submission.url.scheme() == 'mailto'
	assert (submission.url.query() or { '' }) == 'subject=hello&body=message=hello%20world%0D%0A'
}
