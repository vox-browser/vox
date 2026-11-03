// Copyright (c) 2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause
// LocalNavigable.cpp's main-thread scroll operation and completion algorithms.
module html

import compositor
import css
import dom
import painting
import math
import time
import webidl

fn (model &NavigableModel) create_scroll_promise() &dom.Promise {
	context := if document := model.active_document() {
		document.relevant_realm_promise_context()
	} else {
		// Preexisting standalone models have no relevant realm.
		webidl.PromiseContext{}
	}
	return dom.Promise.from_webidl(webidl.create_promise_for(context))
}

fn (model &NavigableModel) resolved_scroll_promise() &dom.Promise {
	mut promise := model.create_scroll_promise()
	promise.resolve(dom.js_undefined())
	return promise
}

struct MainThreadSmoothScroll {
	stable_node_id            compositor.AsyncScrollNodeStableId
	animation                 compositor.SmoothScrollAnimation
	initial_scroll_offset     dom.CSSPixelPoint_
	destination_scroll_offset dom.CSSPixelPoint_
mut:
	last_tick f64
	elapsed   f64
	promises  []&dom.Promise
}

fn scroll_monotonic_seconds() f64 {
	return f64(time.sys_mono_now()) / 1e9
}

fn (model &NavigableModel) scroll_offset_for(stable_node_id compositor.AsyncScrollNodeStableId) ?dom.CSSPixelPoint_ {
	document := model.active_document() or { return none }
	if stable_node_id.kind == .viewport {
		if stable_node_id.node_id != u64(document.as_node().unique_id()) {
			return none
		}
		viewport := document.viewport_rect()
		return dom.CSSPixelPoint_{
			x_: viewport.x
			y_: viewport.y
		}
	}
	node := dom.Node.from_unique_id(dom.UniqueNodeID(stable_node_id.node_id)) or { return none }
	if voidptr(node.document()) != voidptr(document) {
		return none
	}
	element := node.as_element() or { return none }
	return element.el_scroll_offset()
}

fn (mut model NavigableModel) set_scroll_offset_for(stable_node_id compositor.AsyncScrollNodeStableId, offset dom.CSSPixelPoint_) bool {
	old := model.scroll_offset_for(stable_node_id) or { return false }
	if stable_node_id.kind == .viewport {
		model.perform_scroll_of_viewport_scrolling_box(css.CSSPixelPoint.from_values(offset.x(),
			offset.y()))
		return old != (model.scroll_offset_for(stable_node_id) or { return false })
	}
	node := dom.Node.from_unique_id(dom.UniqueNodeID(stable_node_id.node_id)) or { return false }
	mut document := model.active_document() or { return false }
	document.update_layout(.element_scroll)
	mut paintable := node.paintable_box() or { return false }
	// Destination snapping belongs to operation creation, not each animation
	// sample. This applies the retained source offset without reselecting snaps.
	return paintable.set_scroll_offset_without_snapping(offset)
}

fn (model &NavigableModel) queue_scrollend_for(stable_node_id compositor.AsyncScrollNodeStableId) {
	mut document := model.active_document() or { return }
	if stable_node_id.kind == .viewport {
		if stable_node_id.node_id == u64(document.as_node().unique_id()) {
			document.append_pending_scroll_event(dom.PendingScrollEvent{
				target: document.as_node()
				type_:  'scrollend'
			})
		}
		return
	}
	node := dom.Node.from_unique_id(dom.UniqueNodeID(stable_node_id.node_id)) or { return }
	if voidptr(node.document()) == voidptr(document) {
		document.append_pending_scroll_event(dom.PendingScrollEvent{
			target: node
			type_:  'scrollend'
		})
	}
}

fn queue_scroll_promise_resolution(promise &dom.Promise, interrupted bool) {
	queue_a_microtask(none, fn [promise, interrupted] () {
		steps := fn [promise, interrupted] () {
			mut mutable_promise := unsafe { &dom.Promise(promise) }
			mutable_promise.scroll_interrupted_ = interrupted
			mutable_promise.resolve(dom.js_undefined())
		}
		if native := promise.webidl_promise() {
			context := webidl.promise_context(native)
			if run := context.realm_steps_runner { run(steps) } else { steps() }
		} else {
			steps()
		}
	})
}

fn (model &NavigableModel) finish_main_thread_scroll(scroll MainThreadSmoothScroll, report_scrollend bool, interrupted bool) {
	if report_scrollend {
		if final_offset := model.scroll_offset_for(scroll.stable_node_id) {
			if final_offset != scroll.initial_scroll_offset {
				model.queue_scrollend_for(scroll.stable_node_id)
			}
		}
	}
	for promise in scroll.promises {
		queue_scroll_promise_resolution(promise, interrupted)
	}
}

// ReplacedByNewScroll hands scrollend reporting to the replacement. The old
// operation still resolves every promise through an owning-loop microtask.
fn (mut model NavigableModel) replace_main_thread_scrolls(stable_node_id compositor.AsyncScrollNodeStableId) {
	mut finished := []MainThreadSmoothScroll{}
	for i := 0; i < model.main_thread_smooth_scrolls_.len; {
		if model.main_thread_smooth_scrolls_[i].stable_node_id == stable_node_id {
			finished << model.main_thread_smooth_scrolls_[i]
			model.main_thread_smooth_scrolls_.delete(i)
		} else {
			i++
		}
	}
	for scroll in finished {
		model.finish_main_thread_scroll(scroll, false, true)
	}
}

// The source fallback selected when no compositor scroll context is installed.
// Compositor transport and user gesture latching remain separate source slices.
fn (mut model NavigableModel) perform_main_thread_scroll(stable_node_id compositor.AsyncScrollNodeStableId, position dom.CSSPixelPoint_, behavior dom.ScrollBehavior, associated_element ?&dom.Element) &dom.Promise {
	initial := model.scroll_offset_for(stable_node_id) or {
		return model.resolved_scroll_promise()
	}
	mut smooth := behavior == .smooth
	if behavior == .auto_ {
		if element := associated_element {
			if computed := element.el_computed_properties() {
				smooth = computed.scroll_behavior_ == .smooth
			}
		}
	}
	if smooth {
		for mut scroll in model.main_thread_smooth_scrolls_ {
			if scroll.stable_node_id == stable_node_id
				&& scroll.destination_scroll_offset == position {
				// The geometry can reuse its animation, but a new invocation
				// interrupts the earlier invocation's completion Promise.
				for previous in scroll.promises { queue_scroll_promise_resolution(previous, true) }
				promise := model.create_scroll_promise()
				scroll.promises = [promise]
				return promise
			}
		}
	}
	model.replace_main_thread_scrolls(stable_node_id)
	mut promise := model.create_scroll_promise()
	if !smooth {
		if model.set_scroll_offset_for(stable_node_id, position) {
			model.queue_scrollend_for(stable_node_id)
		}
		promise.resolve(dom.js_undefined())
		return promise
	}
	if position == initial {
		promise.resolve(dom.js_undefined())
		return promise
	}
	animation := compositor.new_smooth_scroll_animation(painting.Point{f64(f32(initial.x())), f64(f32(initial.y()))}, painting.Point{f64(f32(position.x())), f64(f32(position.y()))},
		1, .smooth_scroll) or { panic(err) }
	model.main_thread_smooth_scrolls_ << MainThreadSmoothScroll{
		stable_node_id:            stable_node_id
		animation:                 animation
		last_tick:                 scroll_monotonic_seconds()
		initial_scroll_offset:     initial
		destination_scroll_offset: position
		promises:                  [promise]
	}
	if document := model.active_document() {
		document.request_frame()
	}
	return promise
}

pub fn (mut model NavigableModel) process_main_thread_smooth_scrolls() {
	model.process_main_thread_smooth_scrolls_at(scroll_monotonic_seconds())
}

fn (mut model NavigableModel) process_main_thread_smooth_scrolls_at(now f64) {
	mut finished := []MainThreadSmoothScroll{}
	for i := 0; i < model.main_thread_smooth_scrolls_.len; {
		mut scroll := &model.main_thread_smooth_scrolls_[i]
		if model.scroll_offset_for(scroll.stable_node_id) == none {
			for promise in scroll.promises {
				queue_scroll_promise_resolution(promise, true)
			}
			model.main_thread_smooth_scrolls_.delete(i)
			continue
		}
		scroll.elapsed += math.max(now - scroll.last_tick, 0.001)
		scroll.last_tick = now
		sample := scroll.animation.sample(scroll.elapsed)
		model.set_scroll_offset_for(scroll.stable_node_id, dom.CSSPixelPoint_{
			x_: f64(f32(sample.offset.x))
			y_: f64(f32(sample.offset.y))
		})
		if sample.complete {
			finished << *scroll
			model.main_thread_smooth_scrolls_.delete(i)
		} else {
			i++
		}
	}
	for scroll in finished {
		model.finish_main_thread_scroll(scroll, true, false)
	}
	if model.main_thread_smooth_scrolls_.len > 0 {
		if document := model.active_document() {
			document.request_frame()
		}
	}
}

fn navigable_model_perform_viewport_scroll_options(target voidptr, position dom.CSSPixelPoint_, behavior dom.ScrollBehavior, strategy dom.ScrollSnapSelectionStrategy_) &dom.Promise {
	mut model := unsafe { &NavigableModel(target) }
	return model.perform_a_scroll_of_the_viewport_with_options(css.CSSPixelPoint.from_values(position.x(),
		position.y()), behavior, strategy)
}

fn navigable_model_perform_element_scroll(target voidptr, element &dom.Element, position dom.CSSPixelPoint_, behavior dom.ScrollBehavior, strategy dom.ScrollSnapSelectionStrategy_) &dom.Promise {
	mut model := unsafe { &NavigableModel(target) }
	return model.perform_a_scroll_of_an_element(element, position, behavior, strategy)
}

// LocalNavigable.cpp: programmatic destination snapping precedes operation
// creation; animation samples must not repeatedly snap to intermediate areas.
pub fn (mut model NavigableModel) perform_a_scroll_of_an_element(element &dom.Element, position dom.CSSPixelPoint_, behavior dom.ScrollBehavior, strategy dom.ScrollSnapSelectionStrategy_) &dom.Promise {
	mut document := model.active_document() or { return model.resolved_scroll_promise() }
	if voidptr(element.document()) != voidptr(document) {
		return model.resolved_scroll_promise()
	}
	document.update_layout(.element_scroll)
	mut paintable := element.paintable_box() or { return model.resolved_scroll_promise() }
	destination := paintable.select_scroll_snap_destination(position, strategy)
	paintable.record_scroll_snap_destination(destination)
	return model.perform_main_thread_scroll(compositor.AsyncScrollNodeStableId{
		node_id: u64(element.as_node().unique_id())
		kind:    .element
	}, destination.position, behavior, element)
}

// LocalNavigable destruction/removal resolves every remaining operation and
// reports progress already committed before the owner disappears.
fn (mut model NavigableModel) resolve_all_pending_main_thread_scrolls() {
	for model.main_thread_smooth_scrolls_.len > 0 {
		scroll := model.main_thread_smooth_scrolls_.pop()
		model.finish_main_thread_scroll(scroll, true, true)
	}
}
