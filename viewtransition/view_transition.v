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

// DecodedImageFrame crosses the DOM/module boundary as a retained host frame.
// DOM owns the bitmap allocation; transition captures and pseudo content keep
// this handle alive instead of substituting a serialized image name.
@[heap]
pub struct ImageFrame {
pub:
	handle voidptr = unsafe { nil }
}

@[heap]
pub struct TransitionElement {
pub:
	id string
pub mut:
	view_transition_name   ?string
	rendered               bool = true
	skips_contents         bool
	ancestor_skips         bool
	width                  f64
	height                 f64
	transform              string = 'translate(0px, 0px)'
	writing_mode           string = 'horizontal-tb'
	direction              string = 'ltr'
	mix_blend_mode         string = 'normal'
	backdrop_filter        string = 'none'
	color_scheme           string = 'normal'
	image                  ?&ImageFrame
	captured               bool
	is_document_element    bool
	target                 voidptr                   = unsafe { nil }
	capture_image_callback fn (voidptr) ?&ImageFrame = unsafe { nil }
	set_captured_callback  fn (voidptr, bool)        = unsafe { nil }
}

@[heap]
pub struct TransitionGroupStyleRule {
pub mut:
	selector_text string
	handle        voidptr = unsafe { nil }
pub:
	declarations string
}

pub fn (rule &TransitionGroupStyleRule) css_text() string {
	return '${rule.selector_text} { ${rule.declarations} }'
}

@[heap]
pub struct CapturedElement {
pub mut:
	old_image                        ?&ImageFrame
	old_width                        f64
	old_height                       f64
	old_transform                    string
	old_writing_mode                 string
	old_direction                    string
	old_mix_blend_mode               string
	old_backdrop_filter              string
	old_color_scheme                 string
	new_element                      ?&TransitionElement
	style_rules                      []string
	group_keyframes                  ?string
	group_animation_name_rule        ?string
	group_styles_rule                ?&TransitionGroupStyleRule
	image_pair_isolation_rule        ?string
	image_animation_name_rule        ?string
	group_keyframes_handle           voidptr = unsafe { nil }
	group_animation_name_rule_handle voidptr = unsafe { nil }
	image_pair_isolation_rule_handle voidptr = unsafe { nil }
	image_animation_name_rule_handle voidptr = unsafe { nil }
}

pub struct PseudoElement {
pub:
	type_                PseudoElementType
	view_transition_name string
	parent_index         ?int
pub mut:
	content ?&ImageFrame
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
	target                    voidptr = unsafe { nil }
	refresh_elements_callback fn (voidptr, mut TransitionDocument, bool) = unsafe { nil }
	snapshot_size_callback    fn (voidptr) (f64, f64)                    = unsafe { nil }
	style_sheet_target        voidptr                      = unsafe { nil }
	insert_rule_callback      fn (voidptr, string) voidptr = unsafe { nil }
	remove_rule_callback      fn (voidptr, voidptr)        = unsafe { nil }
	set_selector_callback     fn (voidptr, string)         = unsafe { nil }
	promise_context           webidl.PromiseContext
	state_changed_callback    fn (voidptr) = unsafe { nil }
}

fn (document &TransitionDocument) notify_state_changed() {
	if document.state_changed_callback != unsafe { nil } {
		document.state_changed_callback(document.target)
	}
}

fn (mut capture CapturedElement) append_owned_rule(mut document TransitionDocument, text string) voidptr {
	capture.style_rules << text
	document.dynamic_style_rules << text
	if document.insert_rule_callback != unsafe { nil } {
		return document.insert_rule_callback(document.style_sheet_target, text)
	}
	return unsafe { nil }
}

fn (mut document TransitionDocument) refresh_snapshot_size() {
	if document.snapshot_size_callback != unsafe { nil } {
		document.snapshot_width, document.snapshot_height =
			document.snapshot_size_callback(document.target)
	}
}

pub fn (mut document TransitionDocument) refresh_live_elements(capturing_old bool) {
	document.refresh_snapshot_size()
	if document.refresh_elements_callback != unsafe { nil } {
		document.refresh_elements_callback(document.target, mut document, capturing_old)
	}
}

fn (mut element TransitionElement) set_captured(value bool) {
	element.captured = value
	if element.set_captured_callback != unsafe { nil } {
		element.set_captured_callback(element.target, value)
	}
}

fn (element &TransitionElement) capture_image() ?&ImageFrame {
	if element.capture_image_callback != unsafe { nil } {
		return element.capture_image_callback(element.target)
	}
	return element.image
}

pub type UpdateCallback = fn () !&webidl.Promise

@[heap]
pub struct ViewTransition {
pub:
	document_                    &TransitionDocument
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
	return create_view_transition(document, true)
}

pub fn ViewTransition.create_for_live_document(document &TransitionDocument) &ViewTransition {
	return create_view_transition(document, false)
}

fn create_view_transition(document &TransitionDocument, make_active bool) &ViewTransition {
	mut finished := webidl.create_promise_for(document.promise_context)
	finished.mark_as_handled()
	transition := &ViewTransition{
		document_:                    document
		ready_promise:                webidl.create_promise_for(document.promise_context)
		update_callback_done_promise: webidl.create_promise_for(document.promise_context)
		finished_promise:             finished
		phase:                        .pending_capture
		named_elements:               map[string]&CapturedElement{}
	}
	mut mutable_document := unsafe { &TransitionDocument(document) }
	if make_active {
		if active := mutable_document.active_transition {
			mut previous := unsafe { &ViewTransition(active) }
			if previous.phase != .done {
				previous.skip_the_view_transition(webidl.string_value('AbortError: Document.startViewTransition() was called'))
			}
		}
		mutable_document.active_transition = transition
	}
	return transition
}

fn serialize_css_pixel(value f64) string {
	if value == f64(int(value)) {
		return '${int(value)}'
	}
	return '${value}'
}

pub fn make_translation_transform(x f64, y f64) string {
	return 'translate(${serialize_css_pixel(x)}px, ${serialize_css_pixel(y)}px)'
}

pub fn (transition &ViewTransition) document() &TransitionDocument {
	return transition.document_
}

// https://drafts.csswg.org/css-view-transitions-1/#dom-viewtransition-updatecallbackdone
pub fn (transition &ViewTransition) update_callback_done() &webidl.Promise {
	return transition.update_callback_done_promise
}

// https://drafts.csswg.org/css-view-transitions-1/#dom-viewtransition-ready
pub fn (transition &ViewTransition) ready() &webidl.Promise {
	return transition.ready_promise
}

// https://drafts.csswg.org/css-view-transitions-1/#dom-viewtransition-finished
pub fn (transition &ViewTransition) finished() &webidl.Promise {
	return transition.finished_promise
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
	mut document := transition.document_
	// Setup flushes callbacks left by an earlier transition before capture.
	document.flush_the_update_callback_queue()
	transition.capture_the_old_state() or {
		transition.skip_the_view_transition(webidl.string_value('InvalidStateError: Failed to capture old state'))
		return
	}
	document.rendering_suppression = true
	document.notify_state_changed()
	document.dom_tasks << DomTask{
		type_:      .setup_transition
		transition: &transition
	}
}

pub fn (mut transition ViewTransition) capture_the_old_state() ! {
	mut document := transition.document_
	document.refresh_snapshot_size()
	if transition.document_.snapshot_width > f64(0x7fffffff)
		|| transition.document_.snapshot_height > f64(0x7fffffff) {
		return error('snapshot containing block is too large')
	}
	document.refresh_live_elements(true)
	mut used := map[string]bool{}
	mut captured := []&TransitionElement{}
	transition.initial_snapshot_width = transition.document_.snapshot_width
	transition.initial_snapshot_height = transition.document_.snapshot_height
	for item in transition.document_.elements {
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
				mutable_element.set_captured(false)
			}
			return error('duplicate view-transition-name ${name}')
		}
		used[name] = true
		mut mutable_item := unsafe { &TransitionElement(item) }
		mutable_item.set_captured(true)
		captured << item
	}
	for item in captured {
		name := item.view_transition_name or { continue }
		transition.named_elements[name] = &CapturedElement{
			old_image:  item.capture_image()
			old_width:  if item.is_document_element {
				transition.document_.snapshot_width
			} else {
				item.width
			}
			old_height: if item.is_document_element {
				transition.document_.snapshot_height
			} else {
				item.height
			}
			// Current upstream still captures an identity translate here.
			old_transform:       make_translation_transform(0, 0)
			old_writing_mode:    item.writing_mode
			old_direction:       item.direction
			old_mix_blend_mode:  item.mix_blend_mode
			old_backdrop_filter: item.backdrop_filter
			old_color_scheme:    item.color_scheme
		}
	}
	for item in captured {
		mut mutable_item := unsafe { &TransitionElement(item) }
		mutable_item.set_captured(false)
	}
}

pub fn (mut transition ViewTransition) capture_the_new_state() ! {
	mut document := transition.document_
	document.refresh_live_elements(false)
	mut used := map[string]bool{}
	for item in transition.document_.elements {
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
	mut document := transition.document_
	document.rendering_suppression = false
	document.notify_state_changed()
	document.refresh_snapshot_size()
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
			mutable_element.set_captured(true)
		}
	}
	transition.setup_transition_pseudo_elements()
	transition.update_pseudo_element_styles() or {
		transition.skip_the_view_transition(webidl.string_value('InvalidStateError: Failed to update pseudo-element styles'))
		return
	}
	transition.phase = .animating
	document.notify_state_changed()
	mut ready := transition.ready_promise
	ready.resolve(webidl.undefined_value())
}

pub fn (mut transition ViewTransition) setup_transition_pseudo_elements() {
	mut document := transition.document_
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
			mutable_capture.image_animation_name_rule_handle =
				mutable_capture.append_owned_rule(mut document, rule)
		} else if capture.new_element == none {
			rule := ':root::view-transition-old(${name}) { animation-name: -ua-view-transition-fade-out; }'
			mutable_capture.image_animation_name_rule = rule
			mutable_capture.image_animation_name_rule_handle =
				mutable_capture.append_owned_rule(mut document, rule)
		} else {
			keyframes := '@keyframes -ua-view-transition-group-anim-${name} { from { transform: transform; width: ${capture.old_width}px; height: ${capture.old_height}px; backdrop-filter: backdrop_filter; } }'
			group_animation := ':root::view-transition-group(${name}) { animation-name: -ua-view-transition-group-anim-${name}; }'
			isolation := ':root::view-transition-image-pair(${name}) { isolation: isolate; }'
			image_animation := ':root { &::view-transition-old(${name}) { animation-name: -ua-view-transition-fade-out, -ua-mix-blend-mode-plus-lighter; } &::view-transition-new(${name}) { animation-name: -ua-view-transition-fade-in, -ua-mix-blend-mode-plus-lighter; } }'
			mutable_capture.group_keyframes = keyframes
			mutable_capture.group_animation_name_rule = group_animation
			mutable_capture.image_pair_isolation_rule = isolation
			mutable_capture.image_animation_name_rule = image_animation
			mutable_capture.group_keyframes_handle = mutable_capture.append_owned_rule(mut document,
				keyframes)
			mutable_capture.group_animation_name_rule_handle = mutable_capture.append_owned_rule(mut document,
				group_animation)
			mutable_capture.image_pair_isolation_rule_handle = mutable_capture.append_owned_rule(mut document,
				isolation)
			mutable_capture.image_animation_name_rule_handle = mutable_capture.append_owned_rule(mut document,
				image_animation)
		}
	}
}

pub fn (mut transition ViewTransition) update_pseudo_element_styles() ! {
	mut document := transition.document_
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
					transition.pseudo_elements[index].content = item.capture_image()
				}
			}
		}
		// The current C++ keeps these CSSOM serialization operands as literal
		// placeholders while width and height are serialized values.
		selector_text := ':root::view-transition-group(${name})'
		mut mutable_capture := unsafe { &CapturedElement(capture) }
		if old_rule := capture.group_styles_rule {
			// ViewTransition.cpp: update_pseudo_element_styles, step 4. The current
			// source updates only the existing rule's selector, retaining its
			// identity and declarations even when the element's dimensions change.
			previous_text := old_rule.css_text()
			mut mutable_rule := unsafe { &TransitionGroupStyleRule(old_rule) }
			mutable_rule.selector_text = selector_text
			if old_rule.handle != unsafe { nil } && document.set_selector_callback != unsafe { nil } {
				document.set_selector_callback(old_rule.handle, selector_text)
			}
			rule_text := mutable_rule.css_text()
			// Serialized paint input remains a derived copy of the retained rule.
			// Search from the end to leave identical pre-existing rules alone.
			for offset in 0 .. document.dynamic_style_rules.len {
				index := document.dynamic_style_rules.len - 1 - offset
				existing := document.dynamic_style_rules[index]
				if existing == previous_text {
					document.dynamic_style_rules[index] = rule_text
					break
				}
			}
			for index, existing in capture.style_rules {
				if existing == previous_text {
					mutable_capture.style_rules[index] = rule_text
					break
				}
			}
		} else {
			rule := &TransitionGroupStyleRule{
				selector_text: selector_text
				declarations:  'width: ${width}px; height: ${height}px; transform: transform; writing-mode: writing_mode; direction: direction; text-orientation: text_orientation; mix-blend-mode: mix_blend_mode; backdrop-filter: backdrop_filter; color-scheme: color_scheme;'
			}
			mutable_capture.group_styles_rule = rule
			mut mutable_rule := unsafe { &TransitionGroupStyleRule(rule) }
			mutable_rule.handle = mutable_capture.append_owned_rule(mut document, rule.css_text())
		}
	}
}

pub fn (mut transition ViewTransition) schedule_the_update_callback() {
	if transition.update_callback_scheduled {
		return
	}
	transition.update_callback_scheduled = true
	mut document := transition.document_
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
	for document.run_next_dom_task() {
	}
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
	mut callback_promise := webidl.create_resolved_promise_for(transition.document_.promise_context,
		webidl.undefined_value())
	if callback := transition.update_callback {
		callback_promise = callback() or {
			webidl.create_rejected_promise_for(transition.document_.promise_context,
				webidl.string_value(err.msg()))
		}
	}
	transition.pending_callback_promise = callback_promise
	transition_pointer := voidptr(&transition)
	// ViewTransition.cpp reacts to the actual callback promise. A PromiseContext
	// supplies the relevant document's microtask queue instead of frame polling.
	webidl.react_to_promise(mut callback_promise, fn [transition_pointer] (_ webidl.Value) !webidl.Value {
		mut mutable := unsafe { &ViewTransition(transition_pointer) }
		if mutable.pending_callback_promise != none {
			mutable.settle_update_callback_fulfilled()
		}
		return webidl.undefined_value()
	}, fn [transition_pointer] (reason webidl.Value) !webidl.Value {
		mut mutable := unsafe { &ViewTransition(transition_pointer) }
		if mutable.pending_callback_promise != none {
			mutable.settle_update_callback_rejected(reason)
		}
		return webidl.undefined_value()
	})
}

fn (mut transition ViewTransition) settle_update_callback_fulfilled() {
	transition.pending_callback_promise = none
	mut done := transition.update_callback_done_promise
	done.resolve(webidl.undefined_value())
	transition.activate_view_transition()
}

fn (mut transition ViewTransition) settle_update_callback_rejected(reason webidl.Value) {
	transition.pending_callback_promise = none
	mut done := transition.update_callback_done_promise
	done.reject(reason)
	if transition.phase != .done {
		// This rejection is propagated to finished by the skip algorithm.
		done.mark_as_handled()
		transition.skip_the_view_transition(reason)
	}
}

// Standalone adapters may explicitly drain a settled callback. Live documents
// resume through the promise reaction above and their owning microtask queue.
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
	mut document := transition.document_
	document.rendering_suppression = false
	if active := document.active_transition {
		if voidptr(active) == voidptr(transition) {
			transition.clear_view_transition()
		}
	}
	transition.phase = .done
	document.notify_state_changed()
	mut ready := transition.ready_promise
	ready.reject(reason)
	// Source step 8 adopts the result of reacting to updateCallbackDone. Preserve
	// settlement and the relevant promise job queue through the typed boundary.
	mut callback_done := transition.update_callback_done_promise
	webidl.react_to_promise(mut callback_done, fn [transition] (_ webidl.Value) !webidl.Value {
		mut finished := transition.finished_promise
		finished.resolve(webidl.undefined_value())
		return webidl.undefined_value()
	}, fn [transition] (reason webidl.Value) !webidl.Value {
		mut finished := transition.finished_promise
		finished.reject(reason)
		return webidl.undefined_value()
	})
}

pub fn (mut transition ViewTransition) handle_transition_frame(has_active_animations bool) {
	if transition.phase != .animating {
		return
	}
	if !has_active_animations {
		transition.phase = .done
		transition.clear_view_transition()
		transition.document_.notify_state_changed()
		mut finished := transition.finished_promise
		finished.resolve(webidl.undefined_value())
		return
	}
	if transition.initial_snapshot_width or { -1 } != transition.document_.snapshot_width || transition.initial_snapshot_height or {
		-1
	} != transition.document_.snapshot_height {
		transition.skip_the_view_transition(webidl.string_value('InvalidStateError: snapshot containing block changed'))
		return
	}
	transition.update_pseudo_element_styles() or {
		transition.skip_the_view_transition(webidl.string_value('InvalidStateError: Failed to update pseudo-element styles'))
	}
}

pub fn (mut transition ViewTransition) clear_view_transition() {
	mut document := transition.document_
	active := document.active_transition or { return }
	if voidptr(active) != voidptr(transition) {
		return
	}
	for _, capture in transition.named_elements {
		if element := capture.new_element {
			mut mutable_element := unsafe { &TransitionElement(element) }
			mutable_element.set_captured(false)
		}
		if document.remove_rule_callback != unsafe { nil } {
			mut group_style_handle := unsafe { nil }
			if rule := capture.group_styles_rule { group_style_handle = rule.handle }
			for handle in [capture.group_keyframes_handle, capture.group_animation_name_rule_handle,
				group_style_handle, capture.image_pair_isolation_rule_handle,
				capture.image_animation_name_rule_handle] {
				if handle != unsafe { nil } {
					document.remove_rule_callback(document.style_sheet_target, handle)
				}
			}
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
