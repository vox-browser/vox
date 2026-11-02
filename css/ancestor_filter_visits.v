module css

import dom
import os
import platform

const retain_ancestor_rehash = os.getenv('VOX_RETAIN_ANCESTOR_REHASH') != ''
const ancestor_visit_diagnostics = os.getenv('VOX_ANCESTOR_VISIT_DIAGNOSTICS') != ''

__global ancestor_visit_reported_document dom.UniqueNodeID

// Store only scalar hashes for active visits. Pop order is not necessarily
// LIFO: synchronous CSSOM queries seed and remove ancestors in the same order.
struct AncestorFilterVisit {
	identity dom.UniqueNodeID
	start    int
	end      int
mut:
	active bool = true
}

fn (mut computer StyleComputer) push_ancestor_with_saved_hashes(element &dom.Element) {
	if retain_ancestor_rehash || computer.document_ == unsafe { nil } {
		computer.ancestor_filter_.update_element_hashes(element, true)
		return
	}
	// These reused arrays belong to the style computer's document, including
	// when a synchronous query enters from a temporary paint/layout scope.
	persistent := platform.enter_persistent_if(computer.document_.native_storage() == unsafe { nil }
		&& platform.transient_arena_entered())
	defer { platform.leave_persistent(persistent) }
	mut allocations := computer.document_.enter_native_storage()
	defer { allocations.finish() }
	mut retained := platform.enter_retained_allocations()
	defer { retained.finish() }
	start := computer.ancestor_filter_.ancestor_hashes.len
	computer.ancestor_filter_.record_ancestor_hashes = true
	computer.ancestor_filter_.update_element_hashes(element, true)
	computer.ancestor_filter_.record_ancestor_hashes = false
	computer.ancestor_filter_.ancestor_visits << AncestorFilterVisit{
		identity: u64(element.as_node().unique_id())
		start:    start
		end:      computer.ancestor_filter_.ancestor_hashes.len
	}
}

fn (mut computer StyleComputer) pop_ancestor_with_saved_hashes(element &dom.Element) {
	if !retain_ancestor_rehash {
		identity := u64(element.as_node().unique_id())
		for index := computer.ancestor_filter_.ancestor_visits.len - 1; index >= 0; index-- {
			visit := computer.ancestor_filter_.ancestor_visits[index]
			if !visit.active || visit.identity != identity { continue }
			// A slice would publish an alias of this mutable buffer and force
			// copy-on-write when trimming it. Read the checked span in place.
			for hash_index in visit.start .. visit.end {
				computer.ancestor_filter_.decrement(computer.ancestor_filter_.ancestor_hashes[hash_index])
			}
			computer.ancestor_filter_.ancestor_visits[index].active = false
			// Reclaim only a retired suffix: earlier seeded ancestors may be
			// removed before later visits that still need their hash spans.
			for computer.ancestor_filter_.ancestor_visits.len > 0 {
				last := computer.ancestor_filter_.ancestor_visits.last()
				if last.active { break }
				computer.ancestor_filter_.ancestor_hashes.trim(last.start)
				computer.ancestor_filter_.ancestor_visits.delete_last()
			}
			if ancestor_visit_diagnostics && computer.document_ != unsafe { nil } {
				document_id := u64(computer.document_.as_node().unique_id())
				if ancestor_visit_reported_document != document_id {
					ancestor_visit_reported_document = document_id
					eprintln('Vox ancestor visit: removed original hashes without rereading attributes; document=${computer.document_.url.serialize()}')
				}
			}
			return
		}
	}
	computer.ancestor_filter_.update_element_hashes(element, false)
}
