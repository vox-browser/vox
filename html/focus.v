// Copyright (c) 2022-2026, Ladybird contributors
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of Focus.{h,cpp}. Platform focus transfer is represented by a
// manager, while DOM focus state and composed focus events use the DOM module.
module html

import dom

pub struct FocusEventRecord {
pub:
	type_             string
	target_id         i64
	related_target_id ?i64
	bubbles           bool
}

@[heap]
pub struct FocusManager {
pub mut:
	currently_focused_area ?&dom.Node
	has_system_focus       bool = true
	events                 []FocusEventRecord
	navigation             ?&Navigation
}

pub fn FocusManager.create() &FocusManager {
	return &FocusManager{}
}

fn dom_run_focusing_steps_callback(target &dom.Node, fallback ?&dom.Node, trigger dom.FocusTrigger) {
	mut manager := FocusManager.create()
	manager.currently_focused_area = target.document().focused_area()
	run_focusing_steps(mut manager, target, fallback, trigger)
}

fn focus_related_id(target ?&dom.Node) ?i64 {
	node := target or { return none }
	return node.unique_id().value()
}

fn fire_a_focus_event(mut manager FocusManager, target &dom.Node, related_target ?&dom.Node, event_name string, bubbles bool) {
	mut event := dom.Event.create(event_name, dom.EventInit{ bubbles: bubbles })
	event.set_composed(true)
	event.set_is_trusted(true)
	if related := related_target {
		event.set_related_target(unsafe { &dom.EventTarget(related) })
	} else {
		event.set_related_target(none)
	}
	unsafe { &dom.EventTarget(target) }.dispatch_event(event)
	manager.events << FocusEventRecord{
		type_:             event_name
		target_id:         target.unique_id().value()
		related_target_id: focus_related_id(related_target)
		bubbles:           bubbles
	}
}

fn focus_chain(subject ?&dom.Node) []&dom.Node {
	current := subject or { return []&dom.Node{} }
	mut output := [current]
	document := current.document()
	if document != unsafe { nil } && voidptr(current) != voidptr(document) {
		output << unsafe { &dom.Node(document) }
	}
	return output
}

fn run_focus_update_steps(mut manager FocusManager, old_chain_input []&dom.Node, new_chain_input []&dom.Node, new_focus_target ?&dom.Node, trigger dom.FocusTrigger) {
	mut old_chain := old_chain_input.clone()
	mut new_chain := new_chain_input.clone()
	for old_chain.len > 0 && new_chain.len > 0 && old_chain.last() == new_chain.last() {
		old_chain.delete_last()
		new_chain.delete_last()
	}
	related_new := if new_chain.len > 0 { new_chain[0] } else { none }
	related_old := if old_chain.len > 0 { old_chain[0] } else { none }
	for entry in old_chain {
		if entry.is_element() {
			fire_a_focus_event(mut manager, entry, related_new, 'blur', false)
			fire_a_focus_event(mut manager, entry, related_new, 'focusout', true)
		}
	}
	if target := new_focus_target {
		mut document := target.document()
		if document != unsafe { nil } {
			document.set_last_focus_trigger(trigger)
			document.set_focused_area(target)
		}
		if mut navigation := manager.navigation {
			navigation.set_focus_changed_during_ongoing_navigation(true)
		}
	}
	for index := new_chain.len - 1; index >= 0; index-- {
		entry := new_chain[index]
		if entry.is_element() {
			fire_a_focus_event(mut manager, entry, related_old, 'focus', false)
			fire_a_focus_event(mut manager, entry, related_old, 'focusin', true)
		}
	}
}

// https://html.spec.whatwg.org/multipage/interaction.html#focusing-steps
pub fn run_focusing_steps(mut manager FocusManager, new_focus_target ?&dom.Node, fallback_target ?&dom.Node, trigger dom.FocusTrigger) {
	mut target := new_focus_target or { fallback_target or { return } }
	if target.is_inert() {
		return
	}
	if current := manager.currently_focused_area {
		if voidptr(current) == voidptr(target) {
			return
		}
	}
	old_chain := focus_chain(manager.currently_focused_area)
	new_chain := focus_chain(target)
	run_focus_update_steps(mut manager, old_chain, new_chain, target, trigger)
	manager.currently_focused_area = target
}

// https://html.spec.whatwg.org/multipage/interaction.html#unfocusing-steps
pub fn run_unfocusing_steps(mut manager FocusManager, old_focus_target &dom.Node) {
	current := manager.currently_focused_area or { return }
	if old_focus_target.is_inert() || voidptr(current) != voidptr(old_focus_target) {
		return
	}
	old_chain := focus_chain(current)
	if manager.has_system_focus {
		document := current.document()
		if document == unsafe { nil } {
			return
		}
		run_focus_update_steps(mut manager, old_chain, [unsafe { &dom.Node(document) }],
			unsafe { &dom.Node(document) }, .other)
		mut mutable_document := unsafe { document }
		mutable_document.set_focused_area(none)
		manager.currently_focused_area = unsafe { &dom.Node(document) }
	} else {
		run_focus_update_steps(mut manager, old_chain, [], none, .other)
		mut document := current.document()
		if document != unsafe { nil } {
			document.set_focused_area(none)
		}
		manager.currently_focused_area = none
	}
}
