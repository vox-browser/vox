@[has_globals]
module html

import css
import dom

__global (
	cancel_dialog_toggle = false
	details_toggle_pairs []string
)

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

fn record_details_toggle(event &dom.Event, _ ?&dom.EventTarget) dom.JSValue {
	if event.interface_ == .toggle_event {
		toggle := unsafe { &dom.ToggleEvent(event) }
		unsafe {
			details_toggle_pairs << '${toggle.old_state()}->${toggle.new_state()}'
		}
	}
	return dom.js_undefined()
}

fn drain_interactive_element_tasks() {
	mut event_loop := main_thread_event_loop()
	for event_loop.task_queue().has_runnable_tasks() {
		event_loop.process()
	}
}

fn make_interactive_test_document_fully_active(document &dom.Document) &dom.Navigable {
	mut navigable := &dom.Navigable{
		active_document_: document
		is_top_level_traversable_: true
	}
	navigable.traversable_navigable_ = navigable
	mut mutable_document := unsafe { &dom.Document(document) }
	mutable_document.set_cached_navigable(navigable)
	return navigable
}

fn test_dialog_show_modal_close_request_and_commands() {
	document := parse_document('<dialog></dialog>')
	navigable := make_interactive_test_document_fully_active(document)
	_ = navigable
	element := interactive_test_element(unsafe { &dom.Node(document) }, 'dialog') or {
		panic('missing dialog')
	}
	mut dialog := unsafe { &dom.HTMLDialogElement(element) }
	callback := &dom.CallbackType{
		handle_event: dialog_toggle_canceller
	}
	unsafe { &dom.EventTarget(element.as_node()) }
	.set_event_handler_attribute('beforetoggle', callback)

	cancel_dialog_toggle = true
	show_html_dialog_element(mut dialog)!
	assert !element.has_attribute('open')
	cancel_dialog_toggle = false
	show_modal_html_dialog_element(mut dialog)!
	assert element.has_attribute('open')
	assert html_dialog_element_is_modal(dialog)
	assert element.in_top_layer()
	assert document.open_dialogs_list.len == 1
	assert dialog.close_watcher_ != unsafe { nil }
	set_html_dialog_element_return_value(mut dialog, 'initial')
	request_close_html_dialog_element(mut dialog, 'accepted', none)
	assert !element.has_attribute('open')
	assert html_dialog_element_return_value(dialog) == 'accepted'
	assert !html_dialog_element_is_modal(dialog)
	assert document.open_dialogs_list.len == 0
	assert dialog.close_watcher_ == unsafe { nil }
	assert html_dialog_element_is_valid_command('show-modal')
	run_html_dialog_element_command(mut dialog, 'show-modal', none)!
	run_html_dialog_element_command(mut dialog, 'close', none)!
	drain_interactive_element_tasks()
}

fn test_removing_modal_dialog_clears_top_layer_and_modal_state() {
	document := parse_document('<main><dialog></dialog></main>')
	navigable := make_interactive_test_document_fully_active(document)
	_ = navigable
	element := interactive_test_element(unsafe { &dom.Node(document) }, 'dialog') or {
		panic('missing dialog')
	}
	mut dialog := unsafe { &dom.HTMLDialogElement(element) }
	show_modal_html_dialog_element(mut dialog)!
	assert element.in_top_layer()
	assert html_dialog_element_is_modal(dialog)

	mut parent := unsafe { &dom.Node(element.as_node().parent() or { panic('missing parent') }) }
	parent.remove_child(element.as_node())!
	assert !element.in_top_layer()
	assert !html_dialog_element_is_modal(dialog)
}

fn test_dialog_literal_lifecycle_toggle_coalescing_focus_and_light_dismiss() {
	mut document := parse_document('<button id="before"></button><dialog closedby="any"><button></button></dialog>')
	navigable := make_interactive_test_document_fully_active(document)
	_ = navigable
	before := interactive_test_element(unsafe { &dom.Node(document) }, 'button') or {
		panic('missing focus source')
	}
	document.set_focused_area(before.as_node())
	dialog_element := interactive_test_element(unsafe { &dom.Node(document) }, 'dialog') or {
		panic('missing dialog')
	}
	dialog := unsafe { &dom.HTMLDialogElement(dialog_element) }
	assert html_dialog_element_is_focusable(dialog)
	assert html_dialog_element_default_role(dialog) == .dialog

	html_dialog_element_show(dialog)!
	assert dialog.previously_focused_element_? == before.as_node()
	assert dialog.dialog_toggle_task_id_ != 0
	html_dialog_element_close(dialog, none)
	// The pending open toggle is removed, retaining its old state for the
	// replacement close toggle task.
	assert dialog.dialog_toggle_old_state_ == 'closed'
	drain_interactive_element_tasks()
	assert dialog.dialog_toggle_task_id_ == 0

	html_dialog_element_show_a_modal_dialog(dialog, before)!
	assert document.open_dialogs_list.len == 1
	down := dom.PointerEvent.create('pointerdown', dom.PointerEventInit{
		MouseEventInit: dom.MouseEventInit{
			client_x: 100
			client_y: 100
		}
	})
	up := dom.PointerEvent.create('pointerup', dom.PointerEventInit{
		MouseEventInit: dom.MouseEventInit{
			client_x: 100
			client_y: 100
		}
	})
	unsafe {
		mut down_event := &dom.Event(down)
		down_event.set_is_trusted(true)
		mut up_event := &dom.Event(up)
		up_event.set_is_trusted(true)
	}
	html_dialog_element_light_dismiss_open_dialogs(down, before.as_node())
	html_dialog_element_light_dismiss_open_dialogs(up, before.as_node())
	assert !dialog_element.has_attribute('open')
	drain_interactive_element_tasks()
}

fn test_details_group_exclusivity_and_summary_activation() {
	document := parse_document('<details name="group"><summary>one</summary></details><details name="group"><summary>two</summary><summary>extra</summary></details>')
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
	assert html_summary_element_is_summary_for_its_parent_details(first_summary)
	assert html_summary_element_has_activation_behavior(first_summary)
	assert html_summary_element_is_focusable(first_summary, false)
	html_summary_element_activation_behavior(first_summary)
	assert html_details_element_open(first)
	assert !html_details_element_open(second)
}

fn test_details_literal_shadow_tree_slots_style_and_toggle_task_coalescing() {
	unsafe {
		details_toggle_pairs.clear()
	}
	mut document := parse_document('<details><summary>title</summary><p>content</p></details>')
	mut navigable := &dom.Navigable{
		active_document_: document
		is_top_level_traversable_: true
	}
	navigable.traversable_navigable_ = navigable
	document.set_cached_navigable(navigable)
	element := interactive_test_element(unsafe { &dom.Node(document) }, 'details') or {
		panic('missing details')
	}
	details := unsafe { &dom.HTMLDetailsElement(element) }
	html_details_element_inserted(details)
	shadow_root := element.shadow_root() or { panic('missing details shadow root') }
	assert shadow_root.is_user_agent_internal()
	assert unsafe { &dom.Node(shadow_root) }.children_as_vector().len == 3
	summary_slot := details.summary_slot_ or { panic('missing summary slot') }
	descendants_slot := details.descendants_slot_ or { panic('missing descendants slot') }
	assert summary_slot.assigned_nodes_internal().len == 1
	assert summary_slot.assigned_nodes_internal()[0].as_element()?.local_name() == 'summary'
	assert unsafe { &dom.Element(descendants_slot) }.get_attribute_value('style').contains('content-visibility: hidden')
	assert unsafe { &dom.Element(descendants_slot) }.associated_shadow_host_pseudo_element()? == int(css.PseudoElement.details_content)
	assert element.element_reference_pseudo_element(int(css.PseudoElement.details_content))? == unsafe { &dom.Element(descendants_slot) }

	callback := &dom.CallbackType{
		handle_event: record_details_toggle
	}
	unsafe { &dom.EventTarget(element.as_node()) }
	.set_event_handler_attribute('toggle', callback)
	set_html_details_element_open(details, true)
	set_html_details_element_open(details, false)
	drain_interactive_element_tasks()
	unsafe {
		assert details_toggle_pairs == ['closed->closed']
	}
	assert unsafe { &dom.Element(descendants_slot) }.get_attribute_value('style').contains('content-visibility: hidden')

	set_html_details_element_open(details, true)
	drain_interactive_element_tasks()
	unsafe {
		assert details_toggle_pairs.last() == 'closed->open'
	}
	assert unsafe { &dom.Element(descendants_slot) }.get_attribute_value('style') == 'display: block;'
}
