@[has_globals]
module html

import dom

__global cancel_dialog_toggle = false

fn interactive_test_element(node &dom.Node, local_name string) ?&dom.Element {
	if element := node.as_element() {
		if element.local_name() == local_name {
			return element
		}
	}
	for child in node.children_as_vector() {
		if element := interactive_test_element(child, local_name) {
			return element
		}
	}
	return none
}

fn dialog_toggle_canceller(event &dom.Event, _ ?&dom.EventTarget) dom.JSValue {
	if cancel_dialog_toggle && event.type_ == 'beforetoggle' {
		mut mutable_event := unsafe { &dom.Event(event) }
		mutable_event.prevent_default()
	}
	return dom.js_undefined()
}

fn test_dialog_show_modal_close_request_and_commands() {
	document := parse_document('<dialog></dialog>')
	element := interactive_test_element(unsafe { &dom.Node(document) }, 'dialog') or {
		panic('missing dialog')
	}
	mut dialog := unsafe { &dom.HTMLDialogElement(element) }
	callback := &dom.CallbackType{
		handle_event: dialog_toggle_canceller
	}
	unsafe { &dom.EventTarget(element.as_node()) }.set_event_handler_attribute('beforetoggle',
		callback)

	cancel_dialog_toggle = true
	show_html_dialog_element(mut dialog)!
	assert !element.has_attribute('open')
	cancel_dialog_toggle = false
	show_modal_html_dialog_element(mut dialog)!
	assert element.has_attribute('open')
	assert html_dialog_element_is_modal(dialog)
	assert element.in_top_layer()
	set_html_dialog_element_return_value(mut dialog, 'initial')
	request_close_html_dialog_element(mut dialog, 'accepted', none)
	assert !element.has_attribute('open')
	assert html_dialog_element_return_value(dialog) == 'accepted'
	assert !html_dialog_element_is_modal(dialog)
	assert html_dialog_element_is_valid_command('SHOW-MODAL')
	run_html_dialog_element_command(mut dialog, 'show-modal', none)!
	run_html_dialog_element_command(mut dialog, 'close', none)!
}

fn test_details_group_exclusivity_and_summary_activation() {
	document :=
		parse_document('<details name="group"><summary>one</summary></details><details name="group"><summary>two</summary><summary>extra</summary></details>')
	mut details_elements := []&dom.Element{}
	collect_details_elements(unsafe { &dom.Node(document) }, mut details_elements)
	assert details_elements.len == 2
	mut first := unsafe { &dom.HTMLDetailsElement(details_elements[0]) }
	mut second := unsafe { &dom.HTMLDetailsElement(details_elements[1]) }
	set_html_details_element_open(first, true)
	assert html_details_element_open(first)
	set_html_details_element_open(second, true)
	assert !html_details_element_open(first)
	assert html_details_element_open(second)
	first_summary_element := interactive_test_element(details_elements[0].as_node(), 'summary') or {
		panic('missing summary')
	}
	first_summary := unsafe { &dom.HTMLSummaryElement(first_summary_element) }
	assert html_summary_element_is_summary_for_parent(first_summary)
	activate_html_summary_element(first_summary)
	assert html_details_element_open(first)
	assert !html_details_element_open(second)
}
