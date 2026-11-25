module layout

import dom
import platform

// Relayout maps carry records by value. Their referenced geometry still
// belongs to the document, so a newer state can copy records and release the
// old map buffers as soon as it replaces that state.
fn (mut state LayoutState) enable_relayout_record_storage(document &dom.Document) {
	$if prealloc {
		if document.recycle_native_paint_trees && document.native_storage() != unsafe { nil } {
			mut arena := platform.new_arena('relayout records')
			state.relayout_record_arena_ = arena
			entry := arena.enter()
			state.relayout_records_ = map[u32]RelayoutRecord{}
			state.first_relayout_records_ = map[u32]RelayoutRecord{}
			state.text_control_layouts_ = map[u32]TextControlInnerLayout{}
			arena.leave(entry)
		}
	}
}

struct RelayoutRecordAllocationScope {
	entry platform.ArenaEntry
mut:
	arena    &platform.Arena = unsafe { nil }
	retained platform.RetainedAllocationScope
}

fn (state &LayoutState) enter_relayout_record_allocations() RelayoutRecordAllocationScope {
	mut arena := state.relayout_record_arena_
	if arena != unsafe { nil } {
		entry := arena.enter()
		return RelayoutRecordAllocationScope{arena: arena, entry: entry}
	}
	return RelayoutRecordAllocationScope{retained: retain_geometry_allocations()}
}

fn (mut scope RelayoutRecordAllocationScope) finish() {
	if scope.arena != unsafe { nil } {
		scope.arena.leave(scope.entry)
	} else {
		scope.retained.finish()
	}
}

fn (mut state LayoutState) copy_relayout_records(previous &LayoutState, include_first bool) {
	mut allocations := state.enter_relayout_record_allocations()
	defer { allocations.finish() }
	state.relayout_records_ = previous.relayout_records_.clone()
	state.text_control_layouts_ = previous.text_control_layouts_.clone()
	if include_first {
		state.first_relayout_records_ = previous.first_relayout_records_.clone()
	}
}

fn (mut state LayoutState) release_relayout_record_storage() {
	mut arena := state.relayout_record_arena_
	if arena == unsafe { nil } { return }
	state.relayout_record_arena_ = unsafe { nil }
	state.relayout_records_ = map[u32]RelayoutRecord{}
	state.first_relayout_records_ = map[u32]RelayoutRecord{}
	state.text_control_layouts_ = map[u32]TextControlInnerLayout{}
	if incremental_layout_diagnostics {
		usage := arena.usage()
		eprintln('VOX_RELAYOUT_RECORD_STORAGE retired pass=${state.pass_serial_} used=${usage.used} capacity=${usage.capacity}')
	}
	arena.release()
}
