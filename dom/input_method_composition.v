// Copyright (c) 2026, Ladybird contributors
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of LocalNavigable's platform input-method composition path.
module dom

fn input_method_event_target(document &Document) &EventTarget {
	if focused := document.focused_area() {
		return unsafe { &EventTarget(focused) }
	}
	if body := document.body() {
		return unsafe { &EventTarget(body) }
	}
	return unsafe { &EventTarget(document) }
}

fn input_method_target_is_still(document &Document, expected &InputEventsTarget) bool {
	if !document.is_fully_active() {
		return false
	}
	current := document.active_input_events_target(none) or { return false }
	return voidptr(current) == voidptr(expected)
}

fn input_method_node_belongs_to_target(document &Document, node &Node,
	expected &InputEventsTarget) bool {
	if !node.is_connected() {
		return false
	}
	actual := document.active_input_events_target(node) or { return false }
	return voidptr(actual) == voidptr(expected)
}

pub fn (document &Document) is_input_method_composing() bool {
	return document.is_input_method_composing_
}

pub fn (mut document Document) set_is_input_method_composing(is_composing bool) {
	document.is_input_method_composing_ = is_composing
}

fn (n &Navigable) dispatch_composition_event(event_name string, data string) bool {
	document := n.active_document() or { return true }
	if !document.is_fully_active() {
		return true
	}
	event := CompositionEvent.create(event_name, CompositionEventInit{
		UIEventInit: UIEventInit{
			EventInit: EventInit{
				bubbles:    true
				cancelable: event_name == 'compositionstart'
				composed:   true
			}
		}
		data: data
	})
	return input_method_event_target(document).dispatch_event(unsafe { &Event(event) })
}

fn dispatch_composition_beforeinput(document &Document, text string) {
	mut target_ranges := []&StaticRange{}
	if selection := document.get_selection() {
		if range := selection.range() {
			target_ranges << StaticRange.new(range.start_container(), range.start_offset(),
				range.end_container(), range.end_offset())
		}
	}
	mut beforeinput := InputEvent.create_from_platform_event('beforeinput', InputEventInit{
		UIEventInit: UIEventInit{
			EventInit: EventInit{
				bubbles:  true
				composed: true
			}
		}
		data:         text
		input_type:   input_type_insert_composition_text
		is_composing: document.is_input_method_composing()
	}, target_ranges, current_event_timestamp())
	// Input Events makes the beforeinput paired with a composition update
	// non-cancelable. create_from_platform_event() normally makes beforeinput
	// cancelable, so override that platform-event default here.
	mut beforeinput_event := unsafe { &Event(beforeinput) }
	beforeinput_event.set_cancelable(false)
	input_method_event_target(document).dispatch_event(beforeinput_event)
}

fn (mut n Navigable) forget_input_method_composition_session() {
	n.input_method_composition_node_ = none
	n.input_method_composition_offset_ = 0
	n.input_method_last_marked_text_ = ''
	n.input_method_composition_active_ = false
}

fn (mut n Navigable) end_input_method_composition(final_text ?string) {
	was_active := n.input_method_composition_active_
	last_marked_text := n.input_method_last_marked_text_
	n.input_method_composition_active_ = false
	n.input_method_composition_node_ = none
	n.input_method_composition_offset_ = 0
	n.input_method_last_marked_text_ = ''
	if document := n.active_document() {
		mut mutable_document := unsafe { &Document(document) }
		mutable_document.set_is_input_method_composing(false)
	}
	if !was_active {
		return
	}
	n.dispatch_composition_event('compositionend', final_text or { last_marked_text })
}

pub fn (mut n Navigable) set_marked_text_from_input_method(text string) {
	if text == '' {
		if n.input_method_composition_node_ != none || n.input_method_composition_active_ {
			if n.input_method_composition_node_ != none {
				n.replace_input_method_marked_text(text)
			}
			n.end_input_method_composition(text)
		}
		return
	}
	n.replace_input_method_marked_text(text)
}

pub fn (mut n Navigable) commit_text_from_input_method(text string, replacement_start i32,
	replacement_length i32) {
	if (replacement_start != 0 || replacement_length != 0)
		&& n.apply_input_method_commit_replacement(text, replacement_start, replacement_length) {
		n.end_input_method_composition(text)
		return
	}
	n.replace_input_method_marked_text(text)
	n.end_input_method_composition(text)
}

pub fn (mut n Navigable) unmark_text_from_input_method() {
	n.end_input_method_composition(none)
}

fn (mut n Navigable) replace_input_method_marked_text(text string) {
	document := n.active_document() or {
		n.forget_input_method_composition_session()
		return
	}
	if !document.is_fully_active() {
		n.forget_input_method_composition_session()
		return
	}
	target := document.active_input_events_target(none) or {
		n.end_input_method_composition('')
		return
	}

	if composition_node := n.input_method_composition_node_ {
		if !input_method_node_belongs_to_target(document, composition_node, target)
			|| n.input_method_composition_offset_ > composition_node.length() {
			n.input_method_composition_node_ = none
		}
	}

	original_string := if selection := document.get_selection() {
		selection.to_string()
	} else {
		''
	}
	if !n.input_method_composition_active_ {
		mut mutable_document := unsafe { &Document(document) }
		mutable_document.set_is_input_method_composing(true)
		n.input_method_composition_active_ = true
		if !n.dispatch_composition_event('compositionstart', original_string) {
			n.end_input_method_composition('')
			return
		}
		if !input_method_target_is_still(document, target) {
			n.end_input_method_composition('')
			return
		}
	}

	if caret := document.cursor_position() {
		if caret_node := caret.node() {
			if composition_node := n.input_method_composition_node_ {
				target.set_selection_anchor(composition_node, n.input_method_composition_offset_,
					.downstream)
				target.set_selection_focus(caret_node, caret.offset(), .downstream)
			} else {
				n.input_method_composition_node_ = caret_node
				n.input_method_composition_offset_ = caret.offset()
			}
		}
	}

	n.input_method_last_marked_text_ = text
	n.dispatch_composition_event('compositionupdate', text)
	dispatch_composition_beforeinput(document, text)
	if !input_method_target_is_still(document, target) {
		n.end_input_method_composition('')
		return
	}
	target.handle_insert(input_type_insert_composition_text, text)

	// The V editing bridge may rebuild a contenteditable host while applying the
	// command. Retain the marked range against the post-edit text node, rather
	// than leaving the next update with a detached pre-edit node.
	if input_method_target_is_still(document, target) {
		if end_caret := document.cursor_position() {
			if end_node := end_caret.node() {
				text_length := utf16_code_unit_length(text)
				if end_caret.offset() >= text_length {
					n.input_method_composition_node_ = end_node
					n.input_method_composition_offset_ = end_caret.offset() - text_length
				}
			}
		}
	}
}

fn (mut n Navigable) dispatch_input_method_replacement_events(document &Document,
	target &InputEventsTarget, text string) bool {
	if n.input_method_composition_active_ {
		n.input_method_last_marked_text_ = text
		n.dispatch_composition_event('compositionupdate', text)
		if !input_method_target_is_still(document, target) {
			return false
		}
	}
	dispatch_composition_beforeinput(document, text)
	return input_method_target_is_still(document, target)
}

fn (mut n Navigable) apply_input_method_commit_replacement(text string, replacement_start i32,
	replacement_length i32) bool {
	if replacement_length < 0 {
		return false
	}
	document := n.active_document() or {
		n.forget_input_method_composition_session()
		return true
	}
	if !document.is_fully_active() {
		n.forget_input_method_composition_session()
		return true
	}
	target := document.active_input_events_target(none) or {
		n.end_input_method_composition('')
		return true
	}

	if composition_node := n.input_method_composition_node_ {
		if !input_method_node_belongs_to_target(document, composition_node, target) {
			n.input_method_composition_node_ = none
		}
	}

	caret := document.cursor_position() or {
		if n.input_method_composition_node_ == none {
			if n.dispatch_input_method_replacement_events(document, target, text) {
				target.handle_insert(input_type_insert_composition_text, text)
			}
			return true
		}
		return false
	}
	caret_node := caret.node() or { return false }
	mut preedit_start_node := unsafe { caret_node }
	mut preedit_start_offset := caret.offset()
	if composition_node := n.input_method_composition_node_ {
		preedit_start_node = composition_node
		preedit_start_offset = n.input_method_composition_offset_
	}
	if voidptr(preedit_start_node) != voidptr(caret_node) {
		return false
	}
	replacement_start_offset := i64(preedit_start_offset) + i64(replacement_start)
	if replacement_start_offset < 0 || replacement_start_offset > i64(preedit_start_node.length()) {
		return false
	}
	replacement_end_offset := replacement_start_offset + i64(replacement_length)
	if replacement_end_offset < replacement_start_offset
		|| replacement_end_offset > i64(preedit_start_node.length()) {
		return false
	}
	target.set_selection_anchor(preedit_start_node, int(replacement_start_offset), .downstream)
	target.set_selection_focus(preedit_start_node, int(replacement_end_offset), .downstream)
	if !n.dispatch_input_method_replacement_events(document, target, text) {
		return true
	}
	target.handle_insert(input_type_insert_composition_text, text)
	return true
}
