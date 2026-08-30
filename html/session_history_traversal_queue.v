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
}

pub type SessionHistoryTraversalSteps = fn () &TraversalPromiseState

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

pub fn (entry &SessionHistoryTraversalQueueEntry) execute_steps() &TraversalPromiseState {
	return entry.steps()
}

pub fn (entry &SessionHistoryTraversalQueueEntry) target_navigable() ?&dom.Navigable {
	return entry.target_navigable
}

@[heap]
pub struct SessionHistoryTraversalQueue {
pub mut:
	queue           []&SessionHistoryTraversalQueueEntry
	is_task_running bool
	current_promise ?&TraversalPromiseState
	scheduled       bool
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
	if queue.is_task_running && queue.queue.len > 0 {
		queue.scheduled = true
		return
	}

	for queue.queue.len > 0 {
		if promise := queue.current_promise {
			if !promise.resolved && !promise.rejected {
				queue.scheduled = true
				return
			}
		}

		queue.is_task_running = true
		entry := queue.queue[0]
		queue.queue.delete(0)
		queue.current_promise = entry.execute_steps()
		queue.is_task_running = false
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
			queue.queue.delete(index)
			return entry
		}
	}
	return none
}
