// Copyright (c) 2024, Aliaksandr Kalenik <kalenik.aliaksandr@gmail.com>
//
// SPDX-License-Identifier: BSD-2-Clause
//
// Translation of Libraries/LibWeb/DOM/SelectionchangeEventDispatching.h.
module dom

// https://w3c.github.io/selection-api/#scheduling-selectionchange-event
pub fn schedule_a_selectionchange_event(mut target Document, document &Document) {
	// 1. If target's has scheduled selectionchange event is true, abort.
	if target.has_scheduled_selectionchange_event() {
		return
	}

	// AD-HOC upstream behavior from selection-api issue #338.
	target.set_scheduled_selectionchange_event(true)

	// 2. Queue a user-interaction task which fires the event. HTML owns the
	// event loop and installs this cycle-breaking callback per Document.
	hook := document.lifecycle_hook_ or { return }
	if hook.queue_selectionchange_event_task != unsafe { nil } {
		hook.queue_selectionchange_event_task(hook.target, &target, document)
	}
}

// https://w3c.github.io/selection-api/#firing-selectionchange-event
pub fn fire_a_selectionchange_event(mut target Document, _ &Document) {
	// 1. Clear the scheduled flag.
	target.set_scheduled_selectionchange_event(false)

	// 2-3. A Document target receives a non-bubbling, non-cancelable event.
	event := Event.create('selectionchange', EventInit{
		bubbles: false
		cancelable: false
	})
	target.global_event_handlers_to_event_target('selectionchange').dispatch_event(event)
}
