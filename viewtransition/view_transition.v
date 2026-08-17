// Copyright (c) 2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause

// Translation of ViewTransition/ViewTransition.{h,cpp,idl}.
module viewtransition

import webidl

pub enum Phase as u8 {
	pending_capture
	update_callback_called
	animating
	done
}

pub enum PseudoElementType {
	group
	image_pair
	old
	new_
}

@[heap]
pub struct TransitionElement {
pub:
	id string
pub mut:
	view_transition_name ?string
	rendered             bool = true
	skips_contents       bool
	ancestor_skips       bool
	width                f64
	height               f64
	transform            string = 'translate(0px, 0px)'
	writing_mode         string = 'horizontal-tb'
	direction            string = 'ltr'
	mix_blend_mode       string = 'normal'
	backdrop_filter      string = 'none'
	color_scheme         string = 'normal'
	image                ?string
	captured             bool
	is_document_element  bool
}

@[heap]
pub struct CapturedElement {
pub mut:
	old_image                 ?string
	old_width                 f64
	old_height                f64
	old_transform             string
	old_writing_mode          string
	old_direction             string
	old_mix_blend_mode        string
	old_backdrop_filter       string
	old_color_scheme          string
	new_element               ?&TransitionElement
	style_rules               []string
	group_keyframes           ?string
	group_animation_name_rule ?string
	group_styles_rule         ?string
	image_pair_isolation_rule ?string
	image_animation_name_rule ?string
}

pub struct PseudoElement {
pub:
	type_                PseudoElementType
	view_transition_name string
	parent_index         ?int
pub mut:
	content ?string
}

enum DomTaskType {
	setup_transition
	flush_update_callbacks
}

struct DomTask {
	type_      DomTaskType
	transition ?&ViewTransition
}

@[heap]
pub struct TransitionDocument {
pub mut:
	elements                  []&TransitionElement
	snapshot_width            f64
	snapshot_height           f64
	rendering_suppression     bool
	show_view_transition_tree bool
	dynamic_style_rules       []string
	active_transition         ?&ViewTransition
	update_callback_queue     []&ViewTransition
	dom_tasks                 []DomTask
}

pub type UpdateCallback = fn () !&webidl.Promise

@[heap]
pub struct ViewTransition {
pub:
	document                     &TransitionDocument
	ready_promise                &webidl.Promise
	update_callback_done_promise &webidl.Promise
	finished_promise             &webidl.Promise
pub mut:
	phase                     Phase
	named_elements            map[string]&CapturedElement
	pseudo_elements           []PseudoElement
	initial_snapshot_width    ?f64
	initial_snapshot_height   ?f64
	update_callback           ?UpdateCallback
	update_callback_scheduled bool
	pending_callback_promise  ?&webidl.Promise
}

pub fn ViewTransition.create(document &TransitionDocument) &ViewTransition {
	mut finished := webidl.create_promise()
	finished.mark_as_handled()
	transition := &ViewTransition{
		document:                     document
		ready_promise:                webidl.create_promise()
		update_callback_done_promise: webidl.create_promise()
		finished_promise:             finished
		phase:                        .pending_capture
		named_elements:               map[string]&CapturedElement{}
	}
	mut mutable_document := unsafe { &TransitionDocument(document) }
	if active := mutable_document.active_transition {
		mut previous := unsafe { &ViewTransition(active) }
		if previous.phase != .done {
			previous.skip_the_view_transition(webidl.string_value('AbortError: Document.startViewTransition() was called'))
		}
	}
	mutable_document.active_transition = transition
	return transition
}

pub fn (mut transition ViewTransition) set_update_callback(callback ?UpdateCallback) {
	transition.update_callback = callback
}

pub fn (mut transition ViewTransition) skip_transition() {
	if transition.phase != .done {
		transition.skip_the_view_transition(webidl.string_value('AbortError: ViewTransition.skipTransition() was called'))
	}
}

pub fn (mut transition ViewTransition) setup_view_transition() {
	mut document := transition.document
	// Setup flushes callbacks left by an earlier transition before capture.
	document.flush_the_update_callback_queue()
	transition.capture_the_old_state() or {
		transition.skip_the_view_transition(webidl.string_value('InvalidStateError: Failed to capture old state'))
		return
	}
	document.rendering_suppression = true
	document.dom_tasks << DomTask{
		type_:      .setup_transition
		transition: &transition
	}
}

pub fn (mut transition ViewTransition) capture_the_old_state() ! {
	if transition.document.snapshot_width > f64(0x7fffffff)
		|| transition.document.snapshot_height > f64(0x7fffffff) {
		return error('snapshot containing block is too large')
	}
	mut used := map[string]bool{}
	mut captured := []&TransitionElement{}
	transition.initial_snapshot_width = transition.document.snapshot_width
	transition.initial_snapshot_height = transition.document.snapshot_height
	for item in transition.document.elements {
		if item.ancestor_skips {
			continue
		}
		name := item.view_transition_name or { continue }
		if !item.rendered {
			continue
		}
		if used[name] {
			for element in captured {
				mut mutable_element := unsafe { &TransitionElement(element) }
				mutable_element.captured = false
			}
			return error('duplicate view-transition-name ${name}')
		}
		used[name] = true
		captured << item
	}
	for item in captured {
		name := item.view_transition_name or { continue }
		mut mutable_item := unsafe { &TransitionElement(item) }
		mutable_item.captured = true
		transition.named_elements[name] = &CapturedElement{
			old_image:  item.image
			old_width:  if item.is_document_element {
				transition.document.snapshot_width
			} else {
				item.width
			}
			old_height: if item.is_document_element {
				transition.document.snapshot_height
			} else {
				item.height
			}
			// Current upstream still captures an identity translate here.
			old_transform:       'translate(0px, 0px)'
			old_writing_mode:    item.writing_mode
			old_direction:       item.direction
			old_mix_blend_mode:  item.mix_blend_mode
			old_backdrop_filter: item.backdrop_filter
			old_color_scheme:    item.color_scheme
		}
	}
	for item in captured {
		mut mutable_item := unsafe { &TransitionElement(item) }
		mutable_item.captured = false
	}
}

pub fn (mut transition ViewTransition) capture_the_new_state() ! {
	mut used := map[string]bool{}
	for item in transition.document.elements {
		if item.ancestor_skips {
			continue
		}
		name := item.view_transition_name or { continue }
		if !item.rendered {
			continue
		}
		if used[name] {
			return error('duplicate view-transition-name ${name}')
		}
		used[name] = true
		if name !in transition.named_elements {
			transition.named_elements[name] = &CapturedElement{}
		}
		mut capture := transition.named_elements[name] or { return error('missing capture') }
		capture.new_element = item
	}
}

pub fn (mut transition ViewTransition) activate_view_transition() {
	if transition.phase == .done {
		return
	}
	mut document := transition.document
	document.rendering_suppression = false
	if transition.initial_snapshot_width or { -1 } != document.snapshot_width || transition.initial_snapshot_height or {
		-1
	} != document.snapshot_height {
		transition.skip_the_view_transition(webidl.string_value('InvalidStateError: snapshot containing block changed'))
		return
	}
	transition.capture_the_new_state() or {
		transition.skip_the_view_transition(webidl.string_value('InvalidStateError: Failed to capture new state'))
		return
	}
	for _, capture in transition.named_elements {
		if element := capture.new_element {
			mut mutable_element := unsafe { &TransitionElement(element) }
			mutable_element.captured = true
		}
	}
	transition.setup_transition_pseudo_elements()
	transition.update_pseudo_element_styles() or {
		transition.skip_the_view_transition(webidl.string_value('InvalidStateError: Failed to update pseudo-element styles'))
		return
	}
	transition.phase = .animating
	mut ready := transition.ready_promise
	ready.resolve(webidl.undefined_value())
}

pub fn (mut transition ViewTransition) setup_transition_pseudo_elements() {
	mut document := transition.document
	document.show_view_transition_tree = true
	transition.pseudo_elements.clear()
	for name, capture in transition.named_elements {
		group_index := transition.pseudo_elements.len
		transition.pseudo_elements << PseudoElement{
			type_:                .group
			view_transition_name: name
		}
		image_pair_index := transition.pseudo_elements.len
		transition.pseudo_elements << PseudoElement{
			type_:                .image_pair
			view_transition_name: name
			parent_index:         group_index
		}
		if old_image := capture.old_image {
			transition.pseudo_elements << PseudoElement{
				type_:                .old
				view_transition_name: name
				parent_index:         image_pair_index
				content:              old_image
			}
		}
		if capture.new_element != none {
			transition.pseudo_elements << PseudoElement{
				type_:                .new_
				view_transition_name: name
				parent_index:         image_pair_index
			}
		}
		mut mutable_capture := unsafe { &CapturedElement(capture) }
		if capture.old_image == none {
			rule := ':root::view-transition-new(${name}) { animation-name: -ua-view-transition-fade-in; }'
			mutable_capture.image_animation_name_rule = rule
			mutable_capture.style_rules << rule
			document.dynamic_style_rules << rule
		} else if capture.new_element == none {
			rule := ':root::view-transition-old(${name}) { animation-name: -ua-view-transition-fade-out; }'
			mutable_capture.image_animation_name_rule = rule
			mutable_capture.style_rules << rule
			document.dynamic_style_rules << rule
		} else {
			keyframes := '@keyframes -ua-view-transition-group-anim-${name} { from { transform: transform; width: ${capture.old_width}px; height: ${capture.old_height}px; backdrop-filter: backdrop_filter; } }'
			group_animation := ':root::view-transition-group(${name}) { animation-name: -ua-view-transition-group-anim-${name}; }'
			isolation := ':root::view-transition-image-pair(${name}) { isolation: isolate; }'
			image_animation := ':root { &::view-transition-old(${name}) { animation-name: -ua-view-transition-fade-out, -ua-mix-blend-mode-plus-lighter; } &::view-transition-new(${name}) { animation-name: -ua-view-transition-fade-in, -ua-mix-blend-mode-plus-lighter; } }'
			mutable_capture.group_keyframes = keyframes
			mutable_capture.group_animation_name_rule = group_animation
			mutable_capture.image_pair_isolation_rule = isolation
			mutable_capture.image_animation_name_rule = image_animation
			new_rules := [keyframes, group_animation, isolation, image_animation]
			mutable_capture.style_rules << new_rules
			document.dynamic_style_rules << new_rules
		}
	}
}

pub fn (mut transition ViewTransition) update_pseudo_element_styles() ! {
	mut document := transition.document
	for name, capture in transition.named_elements {
		mut width := capture.old_width
		mut height := capture.old_height
		if item := capture.new_element {
			if item.ancestor_skips || !item.rendered {
				return error('new element ${item.id} cannot be rendered')
			}
			width = if item.is_document_element { document.snapshot_width } else { item.width }
			height = if item.is_document_element { document.snapshot_height } else { item.height }
			for index, pseudo in transition.pseudo_elements {
				if pseudo.type_ == .new_ && pseudo.view_transition_name == name {
					transition.pseudo_elements[index].content = item.image
				}
			}
		}
		// The current C++ keeps these CSSOM serialization operands as literal
		// placeholders while width and height are serialized values.
		rule := ':root::view-transition-group(${name}) { width: ${width}px; height: ${height}px; transform: transform; writing-mode: writing_mode; direction: direction; text-orientation: text_orientation; mix-blend-mode: mix_blend_mode; backdrop-filter: backdrop_filter; color-scheme: color_scheme; }'
		mut mutable_capture := unsafe { &CapturedElement(capture) }
		if old_rule := capture.group_styles_rule {
			// Rules are represented by CSS text at this platform boundary. Search
			// from the end because transition-owned rules are appended after any
			// pre-existing identical rule.
			for offset in 0 .. document.dynamic_style_rules.len {
				index := document.dynamic_style_rules.len - 1 - offset
				existing := document.dynamic_style_rules[index]
				if existing == old_rule {
					document.dynamic_style_rules[index] = rule
					break
				}
			}
			for index, existing in capture.style_rules {
				if existing == old_rule {
					mutable_capture.style_rules[index] = rule
					break
				}
			}
		} else {
			mutable_capture.style_rules << rule
			document.dynamic_style_rules << rule
		}
		mutable_capture.group_styles_rule = rule
	}
}

pub fn (mut transition ViewTransition) schedule_the_update_callback() {
	if transition.update_callback_scheduled {
		return
	}
	transition.update_callback_scheduled = true
	mut document := transition.document
	document.update_callback_queue << transition
	// Upstream queues a DOM-manipulation task to flush the queue. The setup
	// task also flushes synchronously, so that later task is intentionally
	// redundant when setup was the caller.
	document.dom_tasks << DomTask{
		type_: .flush_update_callbacks
	}
}

// run_next_dom_task is the explicit host event-loop boundary for the queued
// DOM-manipulation tasks used by the upstream algorithms.
pub fn (mut document TransitionDocument) run_next_dom_task() bool {
	if document.dom_tasks.len == 0 {
		return false
	}
	task := document.dom_tasks[0]
	document.dom_tasks.delete(0)
	match task.type_ {
		.setup_transition {
			mut transition := task.transition or { return true }
			if transition.phase == .done {
				return true
			}
			transition.schedule_the_update_callback()
			document.flush_the_update_callback_queue()
		}
		.flush_update_callbacks {
			document.flush_the_update_callback_queue()
		}
	}
	return true
}

pub fn (mut document TransitionDocument) drain_dom_tasks() {
	for document.run_next_dom_task() {}
}

pub fn (mut document TransitionDocument) flush_the_update_callback_queue() {
	queue := document.update_callback_queue.clone()
	document.update_callback_queue.clear()
	for item in queue {
		mut transition := unsafe { &ViewTransition(item) }
		transition.update_callback_scheduled = false
		transition.call_the_update_callback()
	}
}

pub fn (mut transition ViewTransition) call_the_update_callback() {
	if transition.phase != .done && transition.phase != .pending_capture {
		return
	}
	if transition.phase != .done {
		transition.phase = .update_callback_called
	}
	mut callback_promise := webidl.create_resolved_promise(webidl.undefined_value())
	if callback := transition.update_callback {
		callback_promise = callback() or {
			webidl.create_rejected_promise(webidl.string_value(err.msg()))
		}
	}
	transition.pending_callback_promise = callback_promise
	transition.process_update_callback_promise()
}

fn (mut transition ViewTransition) settle_update_callback_fulfilled() {
	transition.pending_callback_promise = none
	mut done := transition.update_callback_done_promise
	done.resolve(webidl.undefined_value())
	if transition.phase == .done {
		mut finished := transition.finished_promise
		finished.resolve(webidl.undefined_value())
	} else {
		transition.activate_view_transition()
	}
}

fn (mut transition ViewTransition) settle_update_callback_rejected(reason webidl.Value) {
	transition.pending_callback_promise = none
	mut done := transition.update_callback_done_promise
	done.reject(reason)
	if transition.phase != .done {
		// This rejection is propagated to finished by the skip algorithm.
		done.mark_as_handled()
		transition.skip_the_view_transition(reason)
	} else {
		mut finished := transition.finished_promise
		finished.reject(reason)
	}
}

// This is the explicit platform reaction boundary for callback promises. A
// host invokes it after settling a pending callback promise (or from a frame).
pub fn (mut transition ViewTransition) process_update_callback_promise() {
	callback_promise := transition.pending_callback_promise or { return }
	if callback_promise.state == .pending {
		return
	}
	if callback_promise.state == .fulfilled {
		transition.settle_update_callback_fulfilled()
	} else {
		transition.settle_update_callback_rejected(callback_promise.result)
	}
}

pub fn (mut transition ViewTransition) skip_the_view_transition(reason webidl.Value) {
	if transition.phase == .done {
		return
	}
	if int(transition.phase) < int(Phase.update_callback_called) {
		transition.schedule_the_update_callback()
	}
	mut document := transition.document
	document.rendering_suppression = false
	if active := document.active_transition {
		if active == transition {
			transition.clear_view_transition()
		}
	}
	transition.phase = .done
	mut ready := transition.ready_promise
	ready.reject(reason)
	if transition.update_callback_done_promise.state == .fulfilled {
		mut finished := transition.finished_promise
		finished.resolve(webidl.undefined_value())
	} else if transition.update_callback_done_promise.state == .rejected {
		mut finished := transition.finished_promise
		finished.reject(transition.update_callback_done_promise.result)
	}
}

pub fn (mut transition ViewTransition) handle_transition_frame(has_active_animations bool) {
	transition.process_update_callback_promise()
	if transition.phase != .animating {
		return
	}
	if !has_active_animations {
		transition.phase = .done
		transition.clear_view_transition()
		mut finished := transition.finished_promise
		finished.resolve(webidl.undefined_value())
		return
	}
	if transition.initial_snapshot_width or { -1 } != transition.document.snapshot_width || transition.initial_snapshot_height or {
		-1
	} != transition.document.snapshot_height {
		transition.skip_the_view_transition(webidl.string_value('InvalidStateError: snapshot containing block changed'))
		return
	}
	transition.update_pseudo_element_styles() or {
		transition.skip_the_view_transition(webidl.string_value('InvalidStateError: Failed to update pseudo-element styles'))
	}
}

pub fn (mut transition ViewTransition) clear_view_transition() {
	mut document := transition.document
	active := document.active_transition or { return }
	if active != transition {
		return
	}
	for _, capture in transition.named_elements {
		if element := capture.new_element {
			mut mutable_element := unsafe { &TransitionElement(element) }
			mutable_element.captured = false
		}
		for rule in capture.style_rules {
			// Remove one owned occurrence, preserving an identical rule that
			// existed before this transition appended its style definitions.
			for offset in 0 .. document.dynamic_style_rules.len {
				index := document.dynamic_style_rules.len - 1 - offset
				if document.dynamic_style_rules[index] == rule {
					document.dynamic_style_rules.delete(index)
					break
				}
			}
		}
	}
	document.show_view_transition_tree = false
	document.active_transition = none
}
