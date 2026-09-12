// Copyright (c) 2023-2024, Aliaksandr Kalenik <kalenik.aliaksandr@gmail.com>
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of Libraries/LibWeb/HTML/SessionHistoryTraversalQueue.cpp.
module html

import dom

@[heap]
pub struct TraversalPromiseState {
pub mut:
	resolved bool
	rejected bool
mut:
	settlement_callbacks []fn ()
}

pub fn (promise &TraversalPromiseState) resolve() {
	mut mutable_promise := unsafe { &TraversalPromiseState(promise) }
	if mutable_promise.resolved || mutable_promise.rejected {
		return
	}
	mutable_promise.resolved = true
	callbacks := mutable_promise.settlement_callbacks.clone()
	mutable_promise.settlement_callbacks.clear()
	for callback in callbacks {
		callback()
	}
}

pub fn (promise &TraversalPromiseState) reject() {
	mut mutable_promise := unsafe { &TraversalPromiseState(promise) }
	if mutable_promise.resolved || mutable_promise.rejected {
		return
	}
	mutable_promise.rejected = true
	callbacks := mutable_promise.settlement_callbacks.clone()
	mutable_promise.settlement_callbacks.clear()
	for callback in callbacks {
		callback()
	}
}

fn (mut promise TraversalPromiseState) when_settled(callback fn ()) {
	if promise.resolved || promise.rejected {
		callback()
		return
	}
	promise.settlement_callbacks << callback
}

pub type SessionHistoryTraversalSteps = fn (&TraversalPromiseState)

@[heap]
pub struct SessionHistoryTraversalQueueEntry {
pub:
	steps            SessionHistoryTraversalSteps @[required]
	target_navigable ?&dom.Navigable
}

pub fn SessionHistoryTraversalQueueEntry.create(steps SessionHistoryTraversalSteps, target_navigable ?&dom.Navigable) &SessionHistoryTraversalQueueEntry {
	return &SessionHistoryTraversalQueueEntry{
		steps:            steps
		target_navigable: target_navigable
	}
}

pub fn (entry &SessionHistoryTraversalQueueEntry) execute_steps(signal &TraversalPromiseState) {
	entry.steps(signal)
}

pub fn (entry &SessionHistoryTraversalQueueEntry) target_navigable() ?&dom.Navigable {
	return entry.target_navigable
}

@[heap]
pub struct SessionHistoryTraversalQueue {
pub mut:
	queue           []&SessionHistoryTraversalQueueEntry
	current_promise ?&TraversalPromiseState
	scheduled       bool
mut:
	waiting_on_current_promise bool
}

pub fn (mut queue SessionHistoryTraversalQueue) append(steps SessionHistoryTraversalSteps) {
	queue.queue << SessionHistoryTraversalQueueEntry.create(steps, none)
	queue.scheduled = true
}

pub fn (mut queue SessionHistoryTraversalQueue) append_sync(steps SessionHistoryTraversalSteps, target_navigable &dom.Navigable) {
	queue.queue << SessionHistoryTraversalQueueEntry.create(steps, target_navigable)
	queue.scheduled = true
}

// This is the body of Ladybird's zero-delay timer callback. The embedding event
// loop calls it whenever scheduled is true.
pub fn (mut queue SessionHistoryTraversalQueue) process() {
	for queue.queue.len > 0 {
		if promise := queue.current_promise {
			if !promise.resolved && !promise.rejected {
				if !queue.waiting_on_current_promise {
					queue.waiting_on_current_promise = true
					queue_pointer := voidptr(&queue)
					mut mutable_promise := unsafe { &TraversalPromiseState(promise) }
					mutable_promise.when_settled(fn [queue_pointer] () {
						mut mutable_queue := unsafe { &SessionHistoryTraversalQueue(queue_pointer) }
						mutable_queue.waiting_on_current_promise = false
						mutable_queue.process()
					})
				}
				queue.scheduled = true
				return
			}
		}

		queue.current_promise = none
		entry := queue.queue[0]
		queue.queue.delete(0)
		signal := &TraversalPromiseState{}
		queue.current_promise = signal
		entry.execute_steps(signal)
	}

	if promise := queue.current_promise {
		if !promise.resolved && !promise.rejected {
			if !queue.waiting_on_current_promise {
				queue.waiting_on_current_promise = true
				queue_pointer := voidptr(&queue)
				mut mutable_promise := unsafe { &TraversalPromiseState(promise) }
				mutable_promise.when_settled(fn [queue_pointer] () {
					mut mutable_queue := unsafe { &SessionHistoryTraversalQueue(queue_pointer) }
					mutable_queue.waiting_on_current_promise = false
					mutable_queue.process()
				})
			}
			queue.scheduled = true
			return
		}
	}
	queue.current_promise = none
	queue.scheduled = false
}

// https://html.spec.whatwg.org/multipage/browsing-the-web.html#sync-navigations-jump-queue
pub fn (mut queue SessionHistoryTraversalQueue) first_synchronous_navigation_steps_with_target_navigable_not_contained_in(set []&dom.Navigable) ?&SessionHistoryTraversalQueueEntry {
	for index, entry in queue.queue {
		target := entry.target_navigable or { continue }
		mut is_contained := false
		for navigable in set {
			if voidptr(navigable) == voidptr(target) {
				is_contained = true
				break
			}
		}
		if !is_contained {
			if target.html_model_handle_ != unsafe { nil } {
				model := unsafe { &NavigableModel(target.html_model_handle_) }
				if !model.has_session_history_entry_and_ready_for_navigation() {
					continue
				}
			}
			queue.queue.delete(index)
			return entry
		}
	}
	return none
}
