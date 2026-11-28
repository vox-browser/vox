module layout

import dom
import platform

// The native publisher retires each pass's slot store and relayout maps
// together. Geometry referenced by copied records stays document-owned.
fn (mut state LayoutState) enable_native_layout_pass_storage(document &dom.Document) {
	$if prealloc {
		if document.recycle_native_paint_trees && document.native_storage() != unsafe { nil } {
			mut arena := platform.new_arena('native layout pass')
			state.used_values_store.layout_pass_arena = arena
			entry := arena.enter()
			state.relayout_records_ = map[u32]RelayoutRecord{}
			state.first_relayout_records_ = map[u32]RelayoutRecord{}
			state.text_control_layouts_ = map[u32]TextControlInnerLayout{}
			arena.leave(entry)
		}
	}
}

struct LayoutPassAllocationScope {
	entry platform.ArenaEntry
mut:
	arena    &platform.Arena = unsafe { nil }
	retained platform.RetainedAllocationScope
}

fn enter_layout_pass_allocations(owner &platform.Arena) LayoutPassAllocationScope {
	mut arena := owner
	if arena != unsafe { nil } {
		entry := arena.enter()
		return LayoutPassAllocationScope{arena: arena, entry: entry}
	}
	return LayoutPassAllocationScope{retained: retain_geometry_allocations()}
}

fn (state &LayoutState) enter_relayout_record_allocations() LayoutPassAllocationScope {
	return enter_layout_pass_allocations(state.used_values_store.layout_pass_arena)
}

fn (mut scope LayoutPassAllocationScope) finish() {
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

fn (mut state LayoutState) retire_native_layout_pass_storage(document &dom.Document) {
	if state.used_values_store.layout_pass_arena == unsafe { nil } { return }
	mut storage := document.native_storage()
	mut allocations := storage.enter_nested()
	defer { allocations.finish() }
	// Copies of the DOM's lazy visual-line provider may still need these
	// immutable, document-owned buffers after the native slots are gone.
	for page_index, page in state.used_values_store.pages {
		if page == unsafe { nil } { continue }
		for slot_index, slot in page.entries {
			if slot == unsafe { nil } { continue }
			values := unsafe { &UsedValues(slot) }
			if values.node_ != unsafe { nil } && values.line_boxes.len > 0 {
				index := (u32(page_index) << layout_state_page_bits) | u32(slot_index)
				state.retired_visual_line_geometry_[index] = VisualLineGeometry{
					node: values.node_
					lines: values.line_boxes
				}
			}
		}
	}
	state.release_native_layout_pass_storage()
}

fn (mut state LayoutState) release_native_layout_pass_storage() {
	mut arena := state.used_values_store.layout_pass_arena
	if arena == unsafe { nil } { return }
	if incremental_layout_diagnostics {
		usage := arena.usage()
		slot_chunk_bytes := if state.used_values_store.retained_arena == unsafe { nil } {
			u64(0)
		} else {
			u64(state.used_values_store.retained_arena.storage.chunks.len) * sizeof(MeasurementUsedValuesChunk)
		}
		eprintln('VOX_RELAYOUT_RECORD_STORAGE retired pass=${state.pass_serial_} used=${usage.used} capacity=${usage.capacity} slot_chunk_bytes=${slot_chunk_bytes}')
	}
	state.relayout_records_ = map[u32]RelayoutRecord{}
	state.first_relayout_records_ = map[u32]RelayoutRecord{}
	state.text_control_layouts_ = map[u32]TextControlInnerLayout{}
	state.used_values_store.pages = []&UsedValuesPage{}
	state.used_values_store.retained_arena = unsafe { nil }
	state.used_values_store.layout_pass_arena = unsafe { nil }
	arena.release()
}
