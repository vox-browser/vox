// Copyright (c) 2024-2026, Ladybird contributors
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of the Popover API algorithms in HTMLElement.cpp.
module html

import platform

import dom

pub enum ThrowExceptions {
	yes
	no
}

pub enum FocusPreviousElement {
	yes
	no
}

pub enum FireEvents {
	yes
	no
}

pub enum ExpectedToBeShowing {
	yes
	no
}

pub enum IgnoreDomState {
	yes
	no
}

pub enum IsPopover {
	yes
	no
}

enum PopoverListKind {
	auto_
	hint
}

pub struct ShowPopoverOptions {
pub:
	source ?&dom.HTMLElement
}

pub struct TogglePopoverOptions {
pub:
	force  ?bool
	source ?&dom.HTMLElement
}

pub struct PopoverEndpoint {
pub:
	element  ?&dom.HTMLElement
	document ?&dom.Document
}

__global html_popover_close_watcher_managers map[u64]&CloseWatcherManager

fn popover_element(element &dom.HTMLElement) &dom.Element {
	return unsafe { &dom.Element(element) }
}

fn popover_pointer_key(element &dom.HTMLElement) u64 {
	return u64(voidptr(element))
}

fn document_fullscreen_hide_popovers(_ voidptr, document &dom.Document, element &dom.Element) {
	mut endpoint := PopoverEndpoint{
		document: document
	}
	if hint_ancestor := html_element_topmost_popover_ancestor(element.as_node(),
		document.showing_hint_popover_list(), none, .no) {
		endpoint = PopoverEndpoint{
			element: hint_ancestor
		}
	} else if auto_ancestor := html_element_topmost_popover_ancestor(element.as_node(),
		document.showing_auto_popover_list(), none, .no) {
		endpoint = PopoverEndpoint{
			element: auto_ancestor
		}
	}
	html_element_hide_all_popovers_until(endpoint, .no, .yes)
}

fn document_fullscreen_container_iframe_flag(_ voidptr, container &dom.Node) bool {
	element := container.as_element() or { return false }
	if !element.is_html_element() || element.local_name() != 'iframe' {
		return false
	}
	iframe := unsafe { &dom.HTMLIFrameElement(element) }
	return html_iframe_element_model_for_dom_element(iframe).iframe_fullscreen_flag()
}

pub fn install_document_fullscreen_hook(document &dom.Document) {
	mut mutable_document := unsafe { &dom.Document(document) }
	mutable_document.set_fullscreen_hook(dom.DocumentFullscreenHook{
		target:        voidptr(document)
		hide_popovers: document_fullscreen_hide_popovers
		container_iframe_fullscreen_flag: document_fullscreen_container_iframe_flag
	})
}

fn popover_list_contains(list []&dom.HTMLElement, element &dom.HTMLElement) bool {
	for candidate in list {
		if voidptr(candidate) == voidptr(element) {
			return true
		}
	}
	return false
}

fn popover_list_index(list []&dom.HTMLElement, element &dom.HTMLElement) ?int {
	for index, candidate in list {
		if voidptr(candidate) == voidptr(element) {
			return index
		}
	}
	return none
}

fn popover_optional_string_equal(a ?string, b ?string) bool {
	if left := a {
		if right := b {
			return left == right
		}
		return false
	}
	return b == none
}

fn current_popover_list(document &dom.Document, kind PopoverListKind) []&dom.HTMLElement {
	return match kind {
		.auto_ { document.showing_auto_popover_list() }
		.hint { document.showing_hint_popover_list() }
	}
}

fn flat_tree_parent_html_element(node &dom.Node) ?&dom.HTMLElement {
	mut parent := node.flat_tree_parent()
	for parent != none {
		current := parent or { break }
		if element := current.as_element() {
			if element.is_html_element() {
				return unsafe { &dom.HTMLElement(element) }
			}
		}
		parent = current.flat_tree_parent()
	}
	return none
}

fn dispatch_popover_toggle_event(element &dom.HTMLElement, event_name string, old_state string, new_state string, cancelable bool, source ?&dom.HTMLElement) bool {
	dom_source := if source_element := source {
		?&dom.Element(popover_element(source_element))
	} else {
		?&dom.Element(none)
	}
	event := dom.ToggleEvent.create(event_name, dom.ToggleEventInit{
		EventInit: dom.EventInit{
			cancelable: cancelable
		}
		old_state: old_state
		new_state: new_state
		source: dom_source
	})
	return unsafe { &dom.EventTarget(popover_element(element).as_node()) }.dispatch_event(unsafe {
		&dom.Event(event)
	})
}

pub fn html_element_popover_value_to_state(value ?string) ?string {
	actual := value or { return none }
	if actual == '' || ascii_lowercase_string(actual) == 'auto' {
		return 'auto'
	}
	if ascii_lowercase_string(actual) == 'hint' {
		return 'hint'
	}
	return 'manual'
}

pub fn html_element_popover(element &dom.HTMLElement) ?string {
	return html_element_popover_value_to_state(popover_element(element).get_attribute('popover'))
}

pub fn html_element_set_popover(element &dom.HTMLElement, value ?string) {
	old_state := html_element_popover(element)
	mut dom_element := unsafe { &dom.Element(element) }
	if actual := value {
		dom_element.set_attribute_value('popover', actual)
	} else {
		dom_element.remove_attribute('popover')
	}
	if element.popover_visibility_state() == .showing && old_state != html_element_popover(element) {
		html_element_hide_popover(element, .yes, .yes, .no, .yes, none) or {}
	}
}

fn popover_validity_error(throw_exceptions ThrowExceptions, message string) !bool {
	if throw_exceptions == .yes {
		return error(message)
	}
	return false
}

// https://html.spec.whatwg.org/multipage/popover.html#check-popover-validity
pub fn html_element_check_popover_validity(element &dom.HTMLElement, expected_to_be_showing ExpectedToBeShowing, throw_exceptions ThrowExceptions, expected_document ?&dom.Document, ignore_dom_state IgnoreDomState) !bool {
	if ignore_dom_state == .no && html_element_popover(element) == none {
		return popover_validity_error(throw_exceptions, 'NotSupportedError: Element is not a popover')
	}
	if (expected_to_be_showing == .yes && element.popover_visibility_state() != .showing) || (expected_to_be_showing == .no && element.popover_visibility_state() != .hidden) {
		return false
	}
	dom_element := popover_element(element)
	document := dom_element.document()
	wrong_document := if expected := expected_document {
		voidptr(document) != voidptr(expected)
	} else {
		false
	}
	is_modal_dialog := dom_element.local_name() == 'dialog' && unsafe { &dom.HTMLDialogElement(dom_element) }.is_modal_
	if (ignore_dom_state == .no && !dom_element.is_connected()) || !document.is_fully_active() || (ignore_dom_state == .no && wrong_document) || is_modal_dialog {
		return popover_validity_error(throw_exceptions, 'InvalidStateError: Element is not in a valid state to show a popover')
	}
	return true
}

pub fn html_element_show_popover_for_bindings(element &dom.HTMLElement, options ShowPopoverOptions) ! {
	html_element_show_popover(element, .yes, options.source)!
}

fn popover_close_watcher_manager(document &dom.Document) &CloseWatcherManager {
	key := u64(voidptr(document))
	if manager := html_popover_close_watcher_managers[key] {
		return manager
	}
	manager := CloseWatcherManager.create()
	persistent := platform.enter_persistent()
	html_popover_close_watcher_managers[key] = manager
	platform.leave_persistent(persistent)
	return manager
}

fn establish_popover_close_watcher(element &dom.HTMLElement) {
	document := popover_element(element).document()
	manager := popover_close_watcher_manager(document)
	watcher := CloseWatcher.establish(manager, fn [element] () bool {
		return element.popover_visibility_state() == .showing
	}, fn (_ bool) bool {
		return true
	}, fn [element] () {
		html_element_hide_popover(element, .yes, .yes, .no, .no, none) or {}
	}, fn [document] () bool {
		return document.is_fully_active()
	}, fn () bool {
		return false
	}, fn () {})
	mut mutable_element := unsafe { &dom.HTMLElement(element) }
	mutable_element.set_popover_close_watcher_handle(voidptr(watcher))
}

// https://html.spec.whatwg.org/multipage/popover.html#show-popover
pub fn html_element_show_popover(element &dom.HTMLElement, throw_exceptions ThrowExceptions, source ?&dom.HTMLElement) ! {
	if !html_element_check_popover_validity(element, .no, throw_exceptions, none, .no)! {
		return
	}
	dom_element := popover_element(element)
	mut document := unsafe { &dom.Document(dom_element.document()) }
	nested_show := element.popover_showing_or_hiding()
	fire_events := if nested_show { FireEvents.no } else { FireEvents.yes }
	mut mutable_element := unsafe { &dom.HTMLElement(element) }
	mutable_element.set_popover_showing_or_hiding(true)
	if !dispatch_popover_toggle_event(element, 'beforetoggle', 'closed', 'open', true, source) {
		if !nested_show {
			mutable_element.set_popover_showing_or_hiding(false)
		}
		return
	}
	if !html_element_check_popover_validity(element, .no, throw_exceptions, document, .no)! {
		if !nested_show {
			mutable_element.set_popover_showing_or_hiding(false)
		}
		return
	}

	should_restore_focus := FocusPreviousElement.no
	original_type := html_element_popover(element)
	mut stack_to_append_to := ?PopoverListKind(none)
	if original_type or { '' } == 'auto' {
		html_element_close_entire_popover_list(document, .hint, should_restore_focus, fire_events)
		ancestor := html_element_topmost_popover_ancestor(dom_element.as_node(), document.showing_auto_popover_list(), source, .yes)
		if ancestor_element := ancestor {
			html_element_hide_all_popovers_until(PopoverEndpoint{ element: ancestor_element }, should_restore_focus, fire_events)
		} else {
			html_element_hide_all_popovers_until(PopoverEndpoint{ document: document }, should_restore_focus, fire_events)
		}
		stack_to_append_to = .auto_
	}
	if original_type or { '' } == 'hint' {
		auto_ancestor := html_element_topmost_popover_ancestor(dom_element.as_node(), document.showing_auto_popover_list(), source, .yes)
		hint_ancestor := html_element_topmost_popover_ancestor(dom_element.as_node(), document.showing_hint_popover_list(), source, .yes)
		if ancestor := hint_ancestor {
			html_element_hide_all_popovers_until(PopoverEndpoint{ element: ancestor }, should_restore_focus, fire_events)
			stack_to_append_to = .hint
		} else {
			html_element_close_entire_popover_list(document, .hint, should_restore_focus, fire_events)
			if ancestor := auto_ancestor {
				html_element_hide_all_popovers_until(PopoverEndpoint{ element: ancestor }, should_restore_focus, fire_events)
				stack_to_append_to = .auto_
			} else {
				stack_to_append_to = .hint
			}
		}
	}
	if original_type or { '' } in ['auto', 'hint'] {
		kind := stack_to_append_to or { return error('InvalidStateError: popover stack is missing') }
		if !popover_optional_string_equal(original_type, html_element_popover(element)) {
			if !nested_show {
				mutable_element.set_popover_showing_or_hiding(false)
			}
			if throw_exceptions == .yes {
				return error('InvalidStateError: Element is not in a valid state to show a popover')
			}
			return
		}
		if !html_element_check_popover_validity(element, .no, throw_exceptions, document, .no)! {
			if !nested_show {
				mutable_element.set_popover_showing_or_hiding(false)
			}
			return
		}
		match kind {
			.auto_ {
				document.append_showing_auto_popover(element)
				mutable_element.set_opened_in_popover_mode('auto')
			}
			.hint {
				document.append_showing_hint_popover(element)
				mutable_element.set_opened_in_popover_mode('hint')
			}
		}
		establish_popover_close_watcher(element)
	}
	document.add_an_element_to_the_top_layer(dom_element)
	mutable_element.set_popover_visibility_state(.showing)
	mutable_element.set_popover_trigger(source)
	html_element_queue_a_popover_toggle_event_task(element, 'closed', 'open', source)
	if !nested_show {
		mutable_element.set_popover_showing_or_hiding(false)
	}
}

pub fn html_element_hide_popover_for_bindings(element &dom.HTMLElement) ! {
	html_element_hide_popover(element, .yes, .yes, .yes, .no, none)!
}

fn cleanup_hidden_popover(element &dom.HTMLElement, nested_hide bool) {
	mut mutable_element := unsafe { &dom.HTMLElement(element) }
	// This condition intentionally mirrors HTMLElement.cpp.
	if nested_hide {
		mutable_element.set_popover_showing_or_hiding(false)
	}
	handle := element.popover_close_watcher_handle()
	if handle != unsafe { nil } {
		mut watcher := unsafe { &CloseWatcher(handle) }
		watcher.destroy()
		mutable_element.set_popover_close_watcher_handle(unsafe { nil })
	}
}

// https://html.spec.whatwg.org/multipage/popover.html#hide-popover-algorithm
pub fn html_element_hide_popover(element &dom.HTMLElement, focus_previous_element FocusPreviousElement, requested_fire_events FireEvents, throw_exceptions ThrowExceptions, ignore_dom_state IgnoreDomState, source ?&dom.HTMLElement) ! {
	if !html_element_check_popover_validity(element, .yes, throw_exceptions, none, ignore_dom_state)! {
		return
	}
	dom_element := popover_element(element)
	mut document := unsafe { &dom.Document(dom_element.document()) }
	nested_hide := element.popover_showing_or_hiding()
	mut mutable_element := unsafe { &dom.HTMLElement(element) }
	mutable_element.set_popover_showing_or_hiding(true)
	fire_events := if nested_hide { FireEvents.no } else { requested_fire_events }
	if element.opened_in_popover_mode() or { '' } in ['auto', 'hint'] {
		html_element_hide_all_popovers_until(PopoverEndpoint{ element: element }, focus_previous_element, fire_events)
		if !html_element_check_popover_validity(element, .yes, throw_exceptions, none, ignore_dom_state)! {
			cleanup_hidden_popover(element, nested_hide)
			return
		}
	}
	auto_popovers := document.showing_auto_popover_list()
	auto_list_contains_element := auto_popovers.len > 0 && voidptr(auto_popovers.last()) == voidptr(element)
	if fire_events == .yes {
		dispatch_popover_toggle_event(element, 'beforetoggle', 'open', 'closed', false, source)
		current_auto := document.showing_auto_popover_list()
		if auto_list_contains_element && (current_auto.len == 0 || voidptr(current_auto.last()) != voidptr(element)) {
			html_element_hide_all_popovers_until(PopoverEndpoint{ element: element }, focus_previous_element, .no)
		}
		if !html_element_check_popover_validity(element, .yes, throw_exceptions, none, ignore_dom_state)! {
			cleanup_hidden_popover(element, nested_hide)
			return
		}
		document.request_an_element_to_be_remove_from_the_top_layer(dom_element)
	} else {
		document.remove_an_element_from_the_top_layer_immediately(dom_element)
	}
	if element.opened_in_popover_mode() or { '' } in ['auto', 'hint'] {
		hints := document.showing_hint_popover_list()
		if hints.len > 0 && voidptr(hints.last()) == voidptr(element) {
			document.remove_showing_hint_popover(element)
		} else {
			document.remove_showing_auto_popover(element)
		}
	}
	mutable_element.set_popover_trigger(none)
	mutable_element.set_opened_in_popover_mode(none)
	mutable_element.set_popover_visibility_state(.hidden)
	if fire_events == .yes {
		html_element_queue_a_popover_toggle_event_task(element, 'open', 'closed', source)
	}
	cleanup_hidden_popover(element, nested_hide)
}

pub fn html_element_toggle_popover(element &dom.HTMLElement, options TogglePopoverOptions) !bool {
	if element.popover_visibility_state() == .showing && (options.force == none || !(options.force or { false })) {
		html_element_hide_popover(element, .yes, .yes, .yes, .no, none)!
	} else if options.force == none || options.force or { false } {
		html_element_show_popover(element, .yes, options.source)!
	} else {
		expected := if element.popover_visibility_state() == .showing {
			ExpectedToBeShowing.yes
		} else {
			ExpectedToBeShowing.no
		}
		html_element_check_popover_validity(element, expected, .yes, none, .no)!
	}
	return element.popover_visibility_state() == .showing
}

// https://html.spec.whatwg.org/multipage/popover.html#hide-all-popovers-until
pub fn html_element_hide_all_popovers_until(endpoint PopoverEndpoint, focus_previous_element FocusPreviousElement, fire_events FireEvents) {
	if endpoint_element := endpoint.element {
		if endpoint_element.popover_visibility_state() != .showing {
			return
		}
		document := popover_element(endpoint_element).document()
		if popover_list_contains(document.showing_hint_popover_list(), endpoint_element) {
			html_element_hide_popover_stack_until(endpoint_element, .hint, focus_previous_element, fire_events)
			return
		}
		html_element_close_entire_popover_list(document, .hint, focus_previous_element, fire_events)
		if !popover_list_contains(document.showing_auto_popover_list(), endpoint_element) {
			return
		}
		html_element_hide_popover_stack_until(endpoint_element, .auto_, focus_previous_element, fire_events)
		return
	}
	document := endpoint.document or { return }
	html_element_close_entire_popover_list(document, .hint, focus_previous_element, fire_events)
	html_element_close_entire_popover_list(document, .auto_, focus_previous_element, fire_events)
}

pub fn html_element_hide_popover_stack_until(endpoint &dom.HTMLElement, kind PopoverListKind, focus_previous_element FocusPreviousElement, requested_fire_events FireEvents) {
	document := popover_element(endpoint).document()
	mut fire_events := requested_fire_events
	mut repeating_hide := false
	for {
		popover_list := current_popover_list(document, kind)
		mut last_to_hide := ?&dom.HTMLElement(none)
		for index := popover_list.len - 1; index >= 0; index-- {
			popover := popover_list[index]
			if voidptr(popover) == voidptr(endpoint) {
				break
			}
			last_to_hide = popover
		}
		to_hide := last_to_hide or { return }
		for to_hide.popover_visibility_state() == .showing {
			current := current_popover_list(document, kind)
			if current.len == 0 {
				break
			}
			html_element_hide_popover(current.last(), focus_previous_element, fire_events, .no, .no, none) or { return }
		}
		current := current_popover_list(document, kind)
		repeating_hide = popover_list_contains(current, endpoint) && current.len > 0 && voidptr(current.last()) != voidptr(endpoint)
		if !repeating_hide {
			return
		}
		fire_events = .no
	}
}

pub fn html_element_close_entire_popover_list(document &dom.Document, kind PopoverListKind, focus_previous_element FocusPreviousElement, fire_events FireEvents) {
	for {
		popover_list := current_popover_list(document, kind)
		if popover_list.len == 0 {
			return
		}
		html_element_hide_popover(popover_list.last(), focus_previous_element, fire_events, .no, .no, none) or { return }
	}
}

fn checked_topmost_popover_ancestor(candidate ?&dom.HTMLElement, positions map[u64]int, new_popover ?&dom.HTMLElement, is_popover IsPopover) ?&dom.HTMLElement {
	mut current := candidate
	for current != none {
		candidate_element := current or { return none }
		candidate_ancestor := html_element_nearest_inclusive_open_popover(candidate_element) or {
			return none
		}
		if popover_pointer_key(candidate_ancestor) !in positions {
			return none
		}
		ok_nesting := is_popover == .no || html_element_popover(new_popover or {
			return none
		}) or { '' } == 'hint' || html_element_popover(candidate_ancestor) or { '' } == 'auto'
		if ok_nesting {
			return candidate_ancestor
		}
		current = flat_tree_parent_html_element(popover_element(candidate_ancestor).as_node())
	}
	return none
}

// https://html.spec.whatwg.org/multipage/popover.html#topmost-popover-ancestor
pub fn html_element_topmost_popover_ancestor(new_popover_or_top_layer_element &dom.Node, popover_list []&dom.HTMLElement, source ?&dom.HTMLElement, is_popover IsPopover) ?&dom.HTMLElement {
	mut new_popover := ?&dom.HTMLElement(none)
	if element := new_popover_or_top_layer_element.as_element() {
		if element.is_html_element() {
			new_popover = unsafe { &dom.HTMLElement(element) }
		}
	}
	mut positions := map[u64]int{}
	for index, popover in popover_list {
		positions[popover_pointer_key(popover)] = index
	}
	mut index := popover_list.len
	if is_popover == .yes {
		actual := new_popover or { return none }
		positions[popover_pointer_key(actual)] = index
	}
	index++
	_ = index
	parent_candidate := flat_tree_parent_html_element(new_popover_or_top_layer_element)
	from_parent := checked_topmost_popover_ancestor(parent_candidate, positions, new_popover, is_popover)
	from_source := checked_topmost_popover_ancestor(source, positions, new_popover, is_popover)
	parent_ancestor := from_parent or { return from_source }
	source_ancestor := from_source or { return parent_ancestor }
	return if positions[popover_pointer_key(parent_ancestor)] < positions[popover_pointer_key(source_ancestor)] {
		source_ancestor
	} else {
		parent_ancestor
	}
}

pub fn html_element_nearest_inclusive_open_popover(element &dom.HTMLElement) ?&dom.HTMLElement {
	mut current := ?&dom.HTMLElement(element)
	for current != none {
		candidate := current or { break }
		if html_element_popover(candidate) or { '' } in ['auto', 'hint'] && candidate.popover_visibility_state() == .showing {
			return candidate
		}
		current = flat_tree_parent_html_element(popover_element(candidate).as_node())
	}
	return none
}

pub fn html_element_nearest_inclusive_target_popover(element &dom.HTMLElement) ?&dom.HTMLElement {
	mut current := ?&dom.HTMLElement(element)
	for current != none {
		candidate := current or { break }
		if target := PopoverTargetAttributes.get_the_popover_target_element(popover_element(candidate).as_node()) {
			if html_element_popover(target) or { '' } in ['auto', 'hint'] && target.popover_visibility_state() == .showing {
				return target
			}
		}
		current = flat_tree_parent_html_element(popover_element(candidate).as_node())
	}
	return none
}

pub fn html_element_queue_a_popover_toggle_event_task(element &dom.HTMLElement, requested_old_state string, new_state string, source ?&dom.HTMLElement) {
	mut mutable_element := unsafe { &dom.HTMLElement(element) }
	mut old_state := requested_old_state
	if element.popover_toggle_task_id() != 0 {
		old_state = element.popover_toggle_old_state()
		task_id := element.popover_toggle_task_id()
		mut queue := main_thread_event_loop().task_queue()
		queue.remove_tasks_matching(fn [task_id] (task &Task) bool {
			return task.id == task_id
		})
		mutable_element.set_popover_toggle_task_id(0)
	}
	task_id := queue_a_task(.dom_manipulation, main_thread_event_loop(), popover_element(element).document(), fn [element, old_state, new_state, source] () {
		dispatch_popover_toggle_event(element, 'toggle', old_state, new_state, false, source)
		mut task_element := unsafe { &dom.HTMLElement(element) }
		task_element.set_popover_toggle_task_id(0)
		task_element.set_popover_toggle_old_state('')
	})
	mutable_element.set_popover_toggle_task_id(task_id)
	mutable_element.set_popover_toggle_old_state(old_state)
}

pub fn html_element_popover_stack_position(element &dom.HTMLElement) uint {
	document := popover_element(element).document()
	hints := document.showing_hint_popover_list()
	autos := document.showing_auto_popover_list()
	if index := popover_list_index(hints, element) {
		return uint(index + autos.len + 1)
	}
	if index := popover_list_index(autos, element) {
		return uint(index + 1)
	}
	return 0
}

pub fn html_element_topmost_clicked_popover(node &dom.Node) ?&dom.HTMLElement {
	mut nearest := ?&dom.HTMLElement(none)
	if element := node.as_element() {
		if element.is_html_element() {
			nearest = unsafe { &dom.HTMLElement(element) }
		}
	}
	if nearest == none {
		nearest = flat_tree_parent_html_element(node)
	}
	nearest_element := nearest or { return none }
	clicked := html_element_nearest_inclusive_open_popover(nearest_element)
	target := html_element_nearest_inclusive_target_popover(nearest_element)
	clicked_element := clicked or { return target }
	target_element := target or { return clicked_element }
	if html_element_popover_stack_position(clicked_element) > html_element_popover_stack_position(target_element) {
		return clicked_element
	}
	return target_element
}

// https://html.spec.whatwg.org/multipage/popover.html#light-dismiss-open-popovers
pub fn html_element_light_dismiss_open_popovers(event &dom.PointerEvent, target ?&dom.Node) {
	if !event.is_trusted() {
		return
	}
	target_node := target or { return }
	mut document := unsafe { &dom.Document(target_node.document()) }
	if document.topmost_auto_or_hint_popover() == none {
		return
	}
	if event.type_ == 'pointerdown' {
		document.set_popover_pointerdown_target(html_element_topmost_clicked_popover(target_node))
	}
	if event.type_ == 'pointerup' {
		ancestor := html_element_topmost_clicked_popover(target_node)
		pointerdown_target := document.get_popover_pointerdown_target()
		same_target := if current := pointerdown_target {
			if next := ancestor { voidptr(current) == voidptr(next) } else { false }
		} else {
			ancestor == none
		}
		document.set_popover_pointerdown_target(none)
		if same_target {
			if ancestor_element := ancestor {
				html_element_hide_all_popovers_until(PopoverEndpoint{ element: ancestor_element }, .no, .yes)
			} else {
				html_element_hide_all_popovers_until(PopoverEndpoint{ document: document }, .no, .yes)
			}
		}
	}
}
