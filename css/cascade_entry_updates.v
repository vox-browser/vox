module css

import os

const retain_cascade_override_arena_entries = os.getenv('VOX_RETAIN_CASCADE_OVERRIDE_ARENA_ENTRIES') != ''
const cascade_override_arena_diagnostics = os.getenv('VOX_CASCADE_OVERRIDE_ARENA_DIAGNOSTICS') != ''
__global cascade_override_arena_reported bool

fn report_cascade_override_without_allocation() {
	if cascade_override_arena_diagnostics && !cascade_override_arena_reported {
		cascade_override_arena_reported = true
		eprintln('VOX_CASCADE_OVERRIDE_ARENA retained entry updated without allocation')
	}
}

fn (mut properties CascadedProperties) set_recycled_entry_without_allocation(id PropertyID,
	entry CascadedPropertiesEntry, previous int) bool {
	if retain_cascade_override_arena_entries || properties.scratch_arena_ == unsafe { nil }
		|| !properties.entry_heads_.can_set_without_allocation(id) { return false }
	index := if properties.free_entry_index_ >= 0 {
		properties.free_entry_index_
	} else { properties.allocated_entry_count_ }
	if index < 0 || index / cascaded_property_entry_chunk_size >= properties.entry_chunks_.len {
		return false
	}
	allocated := properties.allocate_entry(entry, previous)
	// Both the entry chunk and active-ID vector have room. The dense head
	// update cannot allocate, including a property first seen in this lease.
	properties.entry_heads_.set(id, allocated)
	report_cascade_override_without_allocation()
	return true
}
