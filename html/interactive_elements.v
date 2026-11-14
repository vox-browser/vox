// Copyright (c) 2020-2026, Ladybird contributors
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of HTMLDialogElement.{h,cpp}, HTMLDetailsElement.{h,cpp}, and
// HTMLSummaryElement.{h,cpp}. Rendering/focus-policy effects stay in DOM host
// state; all observable attributes, events, modal top-layer state, commands,
// and details-name exclusivity are implemented here.
module html

import aria
import css
import dom

fn dialog_dom_element(dialog &dom.HTMLDialogElement) &dom.Element {
	return unsafe { &dom.Element(dialog) }
}

fn details_dom_element(details &dom.HTMLDetailsElement) &dom.Element {
	return unsafe { &dom.Element(details) }
}

fn dispatch_toggle(element &dom.Element, event_name string, old_state string, new_state string, cancelable bool, source ?&dom.Element) bool {
	event := dom.ToggleEvent.create(event_name, dom.ToggleEventInit{
		EventInit: dom.EventInit{
			cancelable: cancelable
		}
		old_state: old_state
		new_state: new_state
		source: source
	})
	return unsafe { &dom.EventTarget(element.as_node()) }.dispatch_event(unsafe { &dom.Event(event) })
}

fn dispatch_plain_event(element &dom.Element, name string, cancelable bool) bool {
	event := dom.Event.create(name, dom.EventInit{
		cancelable: cancelable
	})
	return unsafe { &dom.EventTarget(element.as_node()) }.dispatch_event(event)
}

pub fn html_dialog_element_return_value(dialog &dom.HTMLDialogElement) string {
	return dialog.return_value_
}

pub fn set_html_dialog_element_return_value(mut dialog dom.HTMLDialogElement, value string) {
	dialog.return_value_ = value
}

pub fn html_dialog_element_is_modal(dialog &dom.HTMLDialogElement) bool {
	return dialog.is_modal_
}

pub fn html_dialog_element_is_focusable(_ &dom.HTMLDialogElement) bool {
	return true
}

pub fn html_dialog_element_default_role(_ &dom.HTMLDialogElement) aria.Role {
	return .dialog
}

fn dialog_list_contains(dialogs []&dom.HTMLDialogElement, dialog &dom.HTMLDialogElement) bool {
	for candidate in dialogs {
		if voidptr(candidate) == voidptr(dialog) {
			return true
		}
	}
	return false
}

fn dialog_optional_element_pointer_equal(a ?&dom.HTMLDialogElement, b ?&dom.HTMLDialogElement) bool {
	left := a or { unsafe { nil } }
	right := b or { unsafe { nil } }
	return voidptr(left) == voidptr(right)
}

fn dialog_source_optional_value(source &dom.Element) ?string {
	// FormAssociatedElement::optional_value() returns the value attribute for
	// button and submit-button command invokers and null for the other states.
	if source.local_name() == 'button' {
		return source.get_attribute('value')
	}
	if source.local_name() == 'input' && ascii_lowercase_string(source.get_attribute_value('type')) in ['',
		'submit'] {
		return source.get_attribute('value')
	}
	return none
}

pub fn html_dialog_element_set_is_modal(dialog &dom.HTMLDialogElement, is_modal bool) {
	if dialog.is_modal_ == is_modal {
		return
	}
	mut mutable_dialog := unsafe { &dom.HTMLDialogElement(dialog) }
	mutable_dialog.is_modal_ = is_modal
	mut node := unsafe { &dom.Node(dialog_dom_element(dialog).as_node()) }
	node.invalidate_style(.html_dialog_element_set_is_modal)
}

pub fn html_dialog_element_queue_a_dialog_toggle_event_task(dialog &dom.HTMLDialogElement, requested_old_state string, new_state string, source ?&dom.Element) {
	mut mutable_dialog := unsafe { &dom.HTMLDialogElement(dialog) }
	mut old_state := requested_old_state
	if dialog.dialog_toggle_task_id_ != 0 {
		old_state = dialog.dialog_toggle_old_state_
		task_id := dialog.dialog_toggle_task_id_
		mut queue := main_thread_event_loop().task_queue()
		queue.remove_tasks_matching(fn [task_id] (task &Task) bool {
			return task.id == task_id
		})
		mutable_dialog.dialog_toggle_task_id_ = 0
	}
	task_id := queue_a_task(.dom_manipulation, main_thread_event_loop(), dialog_dom_element(dialog).document(), fn [dialog, old_state, new_state, source] () {
		dispatch_toggle(dialog_dom_element(dialog), 'toggle', old_state, new_state, false, source)
		mut task_dialog := unsafe { &dom.HTMLDialogElement(dialog) }
		task_dialog.dialog_toggle_task_id_ = 0
		task_dialog.dialog_toggle_old_state_ = ''
	})
	mutable_dialog.dialog_toggle_task_id_ = task_id
	mutable_dialog.dialog_toggle_old_state_ = old_state
}

fn hide_popovers_for_dialog(dialog &dom.HTMLDialogElement) {
	element := dialog_dom_element(dialog)
	document := element.document()
	mut endpoint := PopoverEndpoint{
		document: document
	}
	if hint_ancestor := html_element_topmost_popover_ancestor(element.as_node(), document.showing_hint_popover_list(), none, .no) {
		endpoint = PopoverEndpoint{
			element: hint_ancestor
		}
	} else if auto_ancestor := html_element_topmost_popover_ancestor(element.as_node(), document.showing_auto_popover_list(), none, .no) {
		endpoint = PopoverEndpoint{
			element: auto_ancestor
		}
	}
	html_element_hide_all_popovers_until(endpoint, .no, .yes)
}

pub fn html_dialog_element_run_dialog_focusing_steps(dialog &dom.HTMLDialogElement) {
	element := dialog_dom_element(dialog)
	if !element.document().allow_focus() {
		return
	}
	// The upstream focus-delegate and autofocus branches remain FIXME there;
	// its current fallback is the dialog itself.
	mut document := unsafe { &dom.Document(element.document()) }
	document.set_focused_area(element.as_node())
}

pub fn html_dialog_element_set_close_watcher(dialog &dom.HTMLDialogElement) {
	assert dialog.close_watcher_ == unsafe { nil }
	element := dialog_dom_element(dialog)
	document := element.document()
	assert element.has_attribute('open') && document.is_fully_active()
	manager := popover_close_watcher_manager(document)
	watcher := CloseWatcher.establish(manager, fn [dialog] () bool {
		return dialog.enable_close_watcher_for_request_close_
	}, fn [dialog] (can_prevent_close bool) bool {
		return dispatch_plain_event(dialog_dom_element(dialog), 'cancel', can_prevent_close)
	}, fn [dialog] () {
		html_dialog_element_close_the_dialog(dialog, dialog.request_close_return_value_, dialog.request_close_source_element_)
	}, fn [document] () bool {
		return document.is_fully_active()
	}, fn () bool {
		return false
	}, fn () {})
	mut mutable_dialog := unsafe { &dom.HTMLDialogElement(dialog) }
	mutable_dialog.close_watcher_ = voidptr(watcher)
}

pub fn html_dialog_element_run_dialog_setup_steps(dialog &dom.HTMLDialogElement) {
	element := dialog_dom_element(dialog)
	assert element.has_attribute('open')
	assert element.as_node().is_connected()
	mut document := unsafe { &dom.Document(element.document()) }
	assert !dialog_list_contains(document.open_dialogs_list, dialog)
	document.open_dialogs_list << dialog
	html_dialog_element_set_close_watcher(dialog)
}

pub fn html_dialog_element_run_dialog_cleanup_steps(dialog &dom.HTMLDialogElement) {
	mut document := unsafe { &dom.Document(dialog_dom_element(dialog).document()) }
	document.open_dialogs_list = document.open_dialogs_list.filter(voidptr(it) != voidptr(dialog))
	if dialog.close_watcher_ != unsafe { nil } {
		mut watcher := unsafe { &CloseWatcher(dialog.close_watcher_) }
		watcher.destroy()
		mut mutable_dialog := unsafe { &dom.HTMLDialogElement(dialog) }
		mutable_dialog.close_watcher_ = unsafe { nil }
	}
}

pub fn html_dialog_element_attribute_changed(dialog &dom.HTMLDialogElement, local_name string, old_value ?string, value ?string, namespace_ ?string) {
	mut element := dialog_dom_element(dialog)
	element.attribute_changed(local_name, old_value, value, namespace_)
	if namespace_ != none || local_name != 'open' {
		return
	}
	mut node := unsafe { &dom.Node(element.as_node()) }
	node.invalidate_style(.html_details_or_dialog_open_attribute_change)
	if value == none && old_value != none {
		html_dialog_element_run_dialog_cleanup_steps(dialog)
	}
	if !element.document().is_fully_active() || !element.as_node().is_connected() {
		return
	}
	if value != none && old_value == none {
		html_dialog_element_run_dialog_setup_steps(dialog)
	}
}

pub fn html_dialog_element_inserted(dialog &dom.HTMLDialogElement) {
	mut element := dialog_dom_element(dialog)
	element.inserted()
	if !element.document().is_fully_active() {
		return
	}
	if element.has_attribute('open') && element.as_node().is_connected() {
		html_dialog_element_run_dialog_setup_steps(dialog)
	}
}

pub fn html_dialog_element_removed_from(dialog &dom.HTMLDialogElement, old_parent ?&dom.Node, old_root &dom.Node) {
	mut element := dialog_dom_element(dialog)
	element.removed_from(old_parent, old_root)
	if element.has_attribute('open') {
		html_dialog_element_run_dialog_cleanup_steps(dialog)
	}
	mut document := unsafe { &dom.Document(element.document()) }
	if element.in_top_layer() {
		document.remove_an_element_from_the_top_layer_immediately(element)
	}
	html_dialog_element_set_is_modal(dialog, false)
}

pub fn html_dialog_element_show(dialog &dom.HTMLDialogElement) ! {
	mut element := dialog_dom_element(dialog)
	if element.has_attribute('open') {
		if dialog.is_modal_ {
			return error('InvalidStateError: dialog is already open as a modal dialog')
		}
		return
	}
	if !dispatch_toggle(element, 'beforetoggle', 'closed', 'open', true, none) {
		return
	}
	if element.has_attribute('open') {
		return
	}
	html_dialog_element_queue_a_dialog_toggle_event_task(dialog, 'closed', 'open', none)
	element.set_attribute_value('open', '')
	html_dialog_element_attribute_changed(dialog, 'open', none, '', none)
	mut mutable_dialog := unsafe { &dom.HTMLDialogElement(dialog) }
	mutable_dialog.previously_focused_element_ = element.document().focused_area()
	hide_popovers_for_dialog(dialog)
	html_dialog_element_run_dialog_focusing_steps(dialog)
}

pub fn show_html_dialog_element(mut dialog dom.HTMLDialogElement) ! {
	html_dialog_element_show(&dialog)!
}

pub fn html_dialog_element_show_modal(dialog &dom.HTMLDialogElement) ! {
	html_dialog_element_show_a_modal_dialog(dialog, none)!
}

pub fn html_dialog_element_show_a_modal_dialog(dialog &dom.HTMLDialogElement, source ?&dom.Element) ! {
	mut element := dialog_dom_element(dialog)
	if element.has_attribute('open') {
		if dialog.is_modal_ {
			return
		}
		return error('InvalidStateError: dialog is already open')
	}
	if !element.document().is_fully_active() {
		return error('InvalidStateError: document is not fully active')
	}
	if !element.as_node().is_connected() {
		return error('InvalidStateError: modal dialog must be connected to a fully active document')
	}
	if unsafe { &dom.HTMLElement(element) }.popover_visibility_state() == .showing {
		return error('InvalidStateError: dialog is already open as a popover')
	}
	if !dispatch_toggle(element, 'beforetoggle', 'closed', 'open', true, source) {
		return
	}
	if element.has_attribute('open') || !element.as_node().is_connected() {
		return
	}
	if unsafe { &dom.HTMLElement(element) }.popover_visibility_state() == .showing {
		return
	}
	html_dialog_element_queue_a_dialog_toggle_event_task(dialog, 'closed', 'open', source)
	element.set_attribute_value('open', '')
	html_dialog_element_attribute_changed(dialog, 'open', none, '', none)
	assert dialog.close_watcher_ != unsafe { nil }
	html_dialog_element_set_is_modal(dialog, true)
	mut document := element.document()
	if !element.in_top_layer() {
		document.add_an_element_to_the_top_layer(element)
	}
	hide_popovers_for_dialog(dialog)
	html_dialog_element_run_dialog_focusing_steps(dialog)
}

pub fn show_modal_html_dialog_element(mut dialog dom.HTMLDialogElement) ! {
	html_dialog_element_show_modal(&dialog)!
}

pub fn html_dialog_element_close(dialog &dom.HTMLDialogElement, return_value ?string) {
	html_dialog_element_close_the_dialog(dialog, return_value, none)
}

pub fn html_dialog_element_close_the_dialog(dialog &dom.HTMLDialogElement, result ?string, source ?&dom.Element) {
	mut element := dialog_dom_element(dialog)
	if !element.has_attribute('open') {
		return
	}
	dispatch_toggle(element, 'beforetoggle', 'open', 'closed', false, source)
	if !element.has_attribute('open') {
		return
	}
	html_dialog_element_queue_a_dialog_toggle_event_task(dialog, 'open', 'closed', source)
	element.remove_attribute('open')
	html_dialog_element_attribute_changed(dialog, 'open', '', none, none)
	if dialog.is_modal_ {
		mut document := element.document()
		document.request_an_element_to_be_remove_from_the_top_layer(element)
	}
	was_modal := dialog.is_modal_
	html_dialog_element_set_is_modal(dialog, false)
	if value := result {
		mut mutable_dialog := unsafe { &dom.HTMLDialogElement(dialog) }
		mutable_dialog.return_value_ = value
	}
	mut mutable_dialog := unsafe { &dom.HTMLDialogElement(dialog) }
	mutable_dialog.request_close_return_value_ = none
	mutable_dialog.request_close_source_element_ = none
	if previously_focused := dialog.previously_focused_element_ {
		mutable_dialog.previously_focused_element_ = none
		focused_within_dialog := if focused := element.document().focused_area() {
			focused.is_shadow_including_inclusive_descendant_of(element.as_node())
		} else {
			false
		}
		if focused_within_dialog || was_modal {
			mut document := unsafe { &dom.Document(element.document()) }
			document.set_focused_area(previously_focused)
		}
	}
	queue_a_task(.user_interaction, main_thread_event_loop(), element.document(), fn [dialog] () {
		dispatch_plain_event(dialog_dom_element(dialog), 'close', false)
	})
}

pub fn close_html_dialog_element(mut dialog dom.HTMLDialogElement, result ?string, source ?&dom.Element) {
	html_dialog_element_close_the_dialog(&dialog, result, source)
}

pub fn html_dialog_element_request_close(dialog &dom.HTMLDialogElement, return_value ?string) {
	html_dialog_element_request_close_the_dialog(dialog, return_value, none)
}

pub fn html_dialog_element_request_close_the_dialog(dialog &dom.HTMLDialogElement, return_value ?string, source ?&dom.Element) {
	element := dialog_dom_element(dialog)
	if !element.has_attribute('open') {
		return
	}
	if !element.as_node().is_connected() || !element.document().is_fully_active() {
		return
	}
	assert dialog.close_watcher_ != unsafe { nil }
	mut mutable_dialog := unsafe { &dom.HTMLDialogElement(dialog) }
	mutable_dialog.enable_close_watcher_for_request_close_ = true
	mutable_dialog.request_close_return_value_ = return_value
	mutable_dialog.request_close_source_element_ = source
	mut watcher := unsafe { &CloseWatcher(dialog.close_watcher_) }
	watcher.request_close(false)
	mutable_dialog.enable_close_watcher_for_request_close_ = false
}

pub fn request_close_html_dialog_element(mut dialog dom.HTMLDialogElement, return_value ?string, source ?&dom.Element) {
	html_dialog_element_request_close_the_dialog(&dialog, return_value, source)
}

pub fn html_dialog_element_is_valid_command(command string) bool {
	return command in ['show-modal', 'close', 'request-close']
}

pub fn html_dialog_element_command_steps(dialog &dom.HTMLDialogElement, source &dom.Element, command string) ! {
	if unsafe { &dom.HTMLElement(dialog_dom_element(dialog)) }.popover_visibility_state() == .showing {
		return
	}
	if command == 'close' && dialog_dom_element(dialog).has_attribute('open') {
		html_dialog_element_close_the_dialog(dialog, dialog_source_optional_value(source), source)
	}
	if command == 'request-close' && dialog_dom_element(dialog).has_attribute('open') {
		html_dialog_element_request_close_the_dialog(dialog, dialog_source_optional_value(source), source)
	}
	if command == 'show-modal' && !dialog_dom_element(dialog).has_attribute('open') {
		html_dialog_element_show_a_modal_dialog(dialog, source)!
	}
}

pub fn run_html_dialog_element_command(mut dialog dom.HTMLDialogElement, command string, source ?&dom.Element) ! {
	normalized_command := ascii_lowercase_string(command)
	if source_element := source {
		html_dialog_element_command_steps(&dialog, source_element, normalized_command)!
		return
	}
	match normalized_command {
		'show-modal' { html_dialog_element_show_a_modal_dialog(&dialog, none)! }
		'close' { html_dialog_element_close_the_dialog(&dialog, none, none) }
		'request-close' { html_dialog_element_request_close_the_dialog(&dialog, none, none) }
		else {
			return error('NotSupportedError: invalid dialog command')
		}
	}
}

pub fn html_dialog_element_nearest_clicked_dialog(event &dom.PointerEvent, target &dom.Node) ?&dom.HTMLDialogElement {
	if target_element := target.as_element() {
		if target_element.local_name() == 'dialog' {
			target_dialog := unsafe { &dom.HTMLDialogElement(target_element) }
			rect := target_element.get_bounding_client_rect()
			outside := event.client_x() < rect.x || event.client_x() > rect.x + rect.width || event.client_y() < rect.y || event.client_y() > rect.y + rect.height
			if target_element.has_attribute('open') && target_dialog.is_modal_ && outside {
				return none
			}
		}
	}
	mut current := ?&dom.Node(target)
	for current != none {
		node := current or { break }
		if element := node.as_element() {
			if element.local_name() == 'dialog' && element.has_attribute('open') {
				return unsafe { &dom.HTMLDialogElement(element) }
			}
		}
		current = node.flat_tree_parent()
	}
	return none
}

pub fn html_dialog_element_light_dismiss_open_dialogs(event &dom.PointerEvent, target &dom.Node) {
	assert unsafe { &dom.Event(event) }.is_trusted()
	mut document := unsafe { &dom.Document(target.document()) }
	if document.open_dialogs_list.len == 0 {
		return
	}
	ancestor := html_dialog_element_nearest_clicked_dialog(event, target)
	if event.type_ == 'pointerdown' {
		document.dialog_pointerdown_target = ancestor or { unsafe { nil } }
	}
	if event.type_ != 'pointerup' {
		return
	}
	pointerdown_target := if document.dialog_pointerdown_target == unsafe { nil } {
		?&dom.HTMLDialogElement(none)
	} else {
		?&dom.HTMLDialogElement(document.dialog_pointerdown_target)
	}
	same_target := dialog_optional_element_pointer_equal(ancestor, pointerdown_target)
	document.dialog_pointerdown_target = unsafe { nil }
	if !same_target {
		return
	}
	topmost_dialog := document.open_dialogs_list.last()
	if dialog_optional_element_pointer_equal(ancestor, topmost_dialog) {
		return
	}
	closedby := dialog_dom_element(topmost_dialog).get_attribute('closedby') or { return }
	if ascii_lowercase_string(closedby) != 'any' {
		return
	}
	assert topmost_dialog.close_watcher_ != unsafe { nil }
	html_dialog_element_request_close(topmost_dialog, none)
}

fn collect_details_elements(node &dom.Node, mut output []&dom.Element) {
	if element := node.as_element() {
		if element.local_name() == 'details' {
			output << element
		}
	}
	for child in node.children_as_vector() {
		collect_details_elements(child, mut output)
	}
}

fn first_summary_child(element &dom.Element) ?&dom.Node {
	for child in element.as_node().children_as_vector() {
		if child_element := child.as_element() {
			if child_element.is_html_element() && child_element.local_name() == 'summary' {
				return child
			}
		}
	}
	return none
}

fn collect_details_descendants_assignment(node &dom.Node, summary ?&dom.Node, mut output []&dom.Node) {
	for child in node.children_as_vector() {
		is_summary := if summary_node := summary {
			voidptr(child) == voidptr(summary_node)
		} else {
			false
		}
		if !is_summary && child.is_slottable() {
			output << child
		}
		// Only direct children can be assigned to a details element's slots.
	}
}

pub fn html_details_element_queue_a_details_toggle_event_task(details &dom.HTMLDetailsElement, requested_old_state string, new_state string) {
	mut mutable_details := unsafe { &dom.HTMLDetailsElement(details) }
	mut old_state := requested_old_state
	if details.details_toggle_task_id_ != 0 {
		old_state = details.details_toggle_old_state_
		task_id := details.details_toggle_task_id_
		mut queue := main_thread_event_loop().task_queue()
		queue.remove_tasks_matching(fn [task_id] (task &Task) bool {
			return task.id == task_id
		})
		mutable_details.details_toggle_task_id_ = 0
	}
	task_id := queue_a_task(.dom_manipulation, main_thread_event_loop(), details_dom_element(details).document(), fn [details, old_state, new_state] () {
		dispatch_toggle(details_dom_element(details), 'toggle', old_state, new_state, false, none)
		mut task_details := unsafe { &dom.HTMLDetailsElement(details) }
		task_details.details_toggle_task_id_ = 0
		task_details.details_toggle_old_state_ = ''
	})
	mutable_details.details_toggle_task_id_ = task_id
	mutable_details.details_toggle_old_state_ = old_state
}

pub fn html_details_element_ensure_details_exclusivity_by_closing_other_elements_if_needed(details &dom.HTMLDetailsElement) {
	element := details_dom_element(details)
	if !element.has_attribute('open') {
		return
	}
	name := element.get_attribute('name') or { return }
	if name == '' {
		return
	}
	mut group := []&dom.Element{}
	collect_details_elements(element.as_node().root(), mut group)
	for candidate in group {
		if voidptr(candidate) != voidptr(element) && candidate.get_attribute_value('name') == name && candidate.has_attribute('open') {
			set_html_details_element_open(unsafe { &dom.HTMLDetailsElement(candidate) }, false)
			break
		}
	}
}

pub fn html_details_element_ensure_details_exclusivity_by_closing_the_given_element_if_needed(details &dom.HTMLDetailsElement) {
	element := details_dom_element(details)
	if !element.has_attribute('open') {
		return
	}
	name := element.get_attribute('name') or { return }
	if name == '' {
		return
	}
	mut group := []&dom.Element{}
	collect_details_elements(element.as_node().root(), mut group)
	for candidate in group {
		if voidptr(candidate) != voidptr(element) && candidate.get_attribute_value('name') == name && candidate.has_attribute('open') {
			set_html_details_element_open(details, false)
			break
		}
	}
}

pub fn html_details_element_create_shadow_tree_if_needed(details &dom.HTMLDetailsElement) ! {
	mut element := details_dom_element(details)
	if element.shadow_root() != none {
		return
	}
	mut shadow_root := element.attach_a_user_agent_shadow_root(.manual)
	document := element.document()
	mut summary_slot_element := document.create_element_ns('http://www.w3.org/1999/xhtml', 'slot')!
	mut default_summary := document.create_element_ns('http://www.w3.org/1999/xhtml', 'summary')!
	mut default_summary_node := default_summary.as_node()
	default_summary_node.append_child(document.create_text_node('Details').as_node())!
	mut summary_slot_node := summary_slot_element.as_node()
	summary_slot_node.append_child(default_summary_node)!
	mut descendants_slot_element := document.create_element_ns('http://www.w3.org/1999/xhtml', 'slot')!
	mut style_element := document.create_element_ns('http://www.w3.org/1999/xhtml', 'style')!
	style_text := document.create_text_node('\n        :host summary {\n            display: list-item;\n            counter-increment: list-item 0;\n            list-style: disclosure-closed inside;\n        }\n        :host([open]) summary {\n            list-style-type: disclosure-open;\n        }\n    ')
	mut style_node := unsafe { &dom.Node(style_element) }
	style_node.append_child(style_text.as_node())!
	mut shadow_node := unsafe { &dom.Node(shadow_root) }
	shadow_node.append_child(summary_slot_element.as_node())!
	shadow_node.append_child(descendants_slot_element.as_node())!
	descendants_slot_element.set_associated_shadow_host_pseudo_element(int(css.PseudoElement.details_content))
	shadow_node.append_child(style_element.as_node())!
	mut mutable_details := unsafe { &dom.HTMLDetailsElement(details) }
	mutable_details.default_summary_ = unsafe { &dom.HTMLSummaryElement(default_summary) }
	mutable_details.summary_slot_ = unsafe { &dom.HTMLSlotElement(summary_slot_element) }
	mutable_details.descendants_slot_ = unsafe { &dom.HTMLSlotElement(descendants_slot_element) }
}

pub fn html_details_element_update_shadow_tree_slots(details &dom.HTMLDetailsElement) {
	element := details_dom_element(details)
	if element.shadow_root() == none {
		return
	}
	summary := first_summary_child(element)
	mut summary_assignment := []&dom.Node{}
	if summary_node := summary {
		summary_assignment << summary_node
	}
	mut descendants_assignment := []&dom.Node{}
	collect_details_descendants_assignment(element.as_node(), summary, mut descendants_assignment)
	if summary_slot := details.summary_slot_ {
		mut mutable_summary_slot := unsafe { &dom.HTMLSlotElement(summary_slot) }
		mutable_summary_slot.assign(summary_assignment)
	}
	if descendants_slot := details.descendants_slot_ {
		mut mutable_descendants_slot := unsafe { &dom.HTMLSlotElement(descendants_slot) }
		mutable_descendants_slot.assign(descendants_assignment)
	}
	html_details_element_update_shadow_tree_style(details)
}

pub fn html_details_element_update_shadow_tree_style(details &dom.HTMLDetailsElement) {
	element := details_dom_element(details)
	shadow_root := element.shadow_root() or { return }
	mut descendants_slot := details.descendants_slot_ or { return }
	style := if element.has_attribute('open') {
		'display: block;'
	} else {
		'display: block; content-visibility: hidden;'
	}
	mut slot_element := unsafe { &dom.Element(descendants_slot) }
	slot_element.set_attribute_value('style', style)
	mut shadow_node := unsafe { &dom.Node(shadow_root) }
	shadow_node.set_needs_layout_tree_update(true, .details_element_opened_or_closed)
}

pub fn html_details_element_inserted(details &dom.HTMLDetailsElement) {
	mut element := details_dom_element(details)
	element.inserted()
	html_details_element_ensure_details_exclusivity_by_closing_the_given_element_if_needed(details)
	html_details_element_create_shadow_tree_if_needed(details) or { return }
	html_details_element_update_shadow_tree_slots(details)
}

pub fn html_details_element_attribute_changed(details &dom.HTMLDetailsElement, local_name string, old_value ?string, value ?string, namespace_ ?string) {
	mut element := details_dom_element(details)
	element.attribute_changed(local_name, old_value, value, namespace_)
	if namespace_ != none {
		return
	}
	if local_name == 'name' {
		html_details_element_ensure_details_exclusivity_by_closing_the_given_element_if_needed(details)
		html_details_element_update_shadow_tree_style(details)
	} else if local_name == 'open' {
		mut node := unsafe { &dom.Node(element.as_node()) }
		node.invalidate_style(.html_details_or_dialog_open_attribute_change)
		if (old_value == none) != (value == none) {
			if old_value == none {
				html_details_element_queue_a_details_toggle_event_task(details, 'closed', 'open')
			} else {
				html_details_element_queue_a_details_toggle_event_task(details, 'open', 'closed')
			}
		}
		if old_value == none && value != none {
			html_details_element_ensure_details_exclusivity_by_closing_other_elements_if_needed(details)
		}
		html_details_element_update_shadow_tree_style(details)
	}
}

pub fn html_details_element_children_changed(details &dom.HTMLDetailsElement, metadata dom.ChildrenChangedMetadata) {
	mut element := details_dom_element(details)
	element.children_changed(metadata)
	html_details_element_update_shadow_tree_slots(details)
}

pub fn set_html_details_element_open(details &dom.HTMLDetailsElement, open bool) {
	mut element := details_dom_element(details)
	was_open := element.has_attribute('open')
	if was_open == open {
		return
	}
	if open {
		element.set_attribute_value('open', '')
		html_details_element_attribute_changed(details, 'open', none, '', none)
	} else {
		element.remove_attribute('open')
		html_details_element_attribute_changed(details, 'open', '', none, none)
	}
}

pub fn html_details_element_open(details &dom.HTMLDetailsElement) bool {
	return details_dom_element(details).has_attribute('open')
}

pub fn html_summary_element_is_summary_for_parent(summary &dom.HTMLSummaryElement) bool {
	return summary.associated_details_element() != none
}

pub fn html_summary_element_is_summary_for_its_parent_details(summary &dom.HTMLSummaryElement) bool {
	return html_summary_element_is_summary_for_parent(summary)
}

pub fn html_summary_element_has_activation_behavior(_ &dom.HTMLSummaryElement) bool {
	return true
}

pub fn html_summary_element_is_focusable(summary &dom.HTMLSummaryElement, base_is_focusable bool) bool {
	return base_is_focusable || html_summary_element_is_summary_for_its_parent_details(summary)
}

pub fn activate_html_summary_element(summary &dom.HTMLSummaryElement) {
	details := summary.associated_details_element() or { return }
	set_html_details_element_open(details, !html_details_element_open(details))
}

pub fn html_summary_element_activation_behavior(summary &dom.HTMLSummaryElement) {
	activate_html_summary_element(summary)
}
