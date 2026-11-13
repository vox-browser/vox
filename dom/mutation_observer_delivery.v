module dom

import platform

// The DOM-only fallback remains synchronous. A JavaScript host attaches one
// queue per VM agent so records across documents share its actual microtask
// FIFO, with a single notification job and a snapshot of pending observers.
@[heap]
pub struct MutationObserverDeliveryQueue {
	enqueue fn ()
mut:
	pending          []&MutationObserver
	microtask_queued bool
	retired          bool
}

pub fn MutationObserverDeliveryQueue.create(enqueue fn ()) &MutationObserverDeliveryQueue {
	entry := platform.enter_persistent()
	defer { platform.leave_persistent(entry) }
	return &MutationObserverDeliveryQueue{ enqueue: enqueue }
}

fn (mut queue MutationObserverDeliveryQueue) add_pending(observer &MutationObserver) {
	if queue.retired { return }
	for pending in queue.pending { if voidptr(pending) == voidptr(observer) { return } }
	entry := platform.enter_persistent()
	defer { platform.leave_persistent(entry) }
	queue.pending << observer
}

fn (mut queue MutationObserverDeliveryQueue) ensure_microtask() {
	if queue.retired || queue.microtask_queued { return }
	queue.microtask_queued = true
	queue.enqueue()
}

pub fn (mut queue MutationObserverDeliveryQueue) notify() {
	if queue.retired { return }
	queue.microtask_queued = false
	mut pending := queue.pending.clone()
	pending.sort_with_compare(compare_mutation_observer_creation)
	queue.pending.clear()
	for observer in pending { notify_one_mutation_observer(observer) }
}

pub fn (mut queue MutationObserverDeliveryQueue) retire() {
	if queue.retired { return }
	queue.retired = true
	queue.microtask_queued = false
	queue.pending.clear()
	platform.release_closure(voidptr(queue.enqueue))
}

fn compare_mutation_observer_creation(a &&MutationObserver,b &&MutationObserver) int {
    if a.creation_index_ < b.creation_index_ { return -1 }
    if a.creation_index_ > b.creation_index_ { return 1 }
    return 0
}
