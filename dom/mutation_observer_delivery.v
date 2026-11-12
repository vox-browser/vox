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

// sort_pending_mutation_observers orders observers by creation index.
// Written as an explicit insertion sort: FastC (`v -b fastc`) mangles the
// comparator name for closure sorts over pointer element types, emitting
// `v_fastc_sort_dom__MutationObserver*...` which is not a valid C
// identifier, so `observers.sort(a.creation_index_ < b.creation_index_)`
// cannot compile under the production backend (see the
// `src.unit0.c: expected ';' after top level declarator` build failure).
// Pending sets are tiny and creation indices are unique, so this is exact.
fn sort_pending_mutation_observers(mut observers []&MutationObserver) {
	if observers.len < 2 {
		return
	}
	for i in 1 .. observers.len {
		mut j := i
		for j > 0 && observers[j].creation_index_ < observers[j - 1].creation_index_ {
			tmp := observers[j]
			observers[j] = observers[j - 1]
			observers[j - 1] = tmp
			j--
		}
	}
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
	sort_pending_mutation_observers(mut pending)
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
