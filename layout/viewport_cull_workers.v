module layout

import cpuraster
import math
import os
import platform

const serial_viewport_culling = os.getenv('VOX_SERIAL_VIEWPORT_CULLING') == '1'
const viewport_cull_worker_diagnostics = os.getenv('VOX_VIEWPORT_CULL_WORKER_DIAGNOSTICS') == '1'
const viewport_cull_blocks_per_lane = 4

struct ViewportCullWork {
	cache    &ViewportEntryInkCache
	order    []PaintOrderEntry
	contexts []CompatibilityFlattenedVisualContext
	slots    []int
	selected &bool
	threads  &u64
	width    f64
	height   f64
}

fn (work &ViewportCullWork) context(index int) &CompatibilityFlattenedVisualContext {
	slot := if index > 0 && index < work.slots.len { work.slots[index] } else { 0 }
	return unsafe { &work.contexts[slot] }
}

// Each range owns its visibility bits. Bounding rectangles, paint entries,
// and resolved contexts are immutable until the caller has joined all ranges.
fn cull_viewport_block_range(context voidptr, first i32, end i32) {
	work := unsafe { &ViewportCullWork(context) }
	thread_id := if work.threads != unsafe { nil } { platform.native_thread_identity() } else { u64(0) }
	for index in int(first) .. int(end) {
		if thread_id != 0 { unsafe { work.threads[index] = thread_id } }
		block := work.cache.blocks[index]
		if block.testable == 0 { continue }
		mut outside := false
		if block.cullable && !disable_viewport_ink_bounds {
			state := work.context(block.context)
			if state.layer_list != unsafe { nil } { continue }
			outside = viewport_cached_block_is_outside(block, state.transform, work.width, work.height)
		}
		for entry_index in block.first .. block.first + block.count {
			if !work.cache.testable[entry_index] { continue }
			if outside || work.entry_is_outside(entry_index) {
				unsafe { work.selected[entry_index] = false }
			}
		}
	}
}

fn (work &ViewportCullWork) entry_is_outside(index int) bool {
	state := work.context(work.order[index].box.accumulated_visual_context_index)
	if state.layer_list != unsafe { nil } { return false }
	if work.cache.entries[index].prepaint {
		return viewport_cached_entry_ink_is_outside_direct(work.cache, index,
			viewport_prepaint_transform(state.transform, work.height), work.width, work.height * 3)
	}
	return viewport_cached_entry_ink_is_outside_direct(work.cache, index, state.transform,
		work.width, work.height)
}

fn mark_viewport_invisible_blocks_parallel(order []PaintOrderEntry, cache &ViewportEntryInkCache,
	mut memo CompatibilityVisualContextMemo, mut selected []bool, width f64, height f64) bool {
	$if macos {
		block_count := cache.blocks.len
		if serial_viewport_culling || disable_direct_viewport_rect_culling
			|| viewport_rect_culling_diagnostics || block_count < 2 * viewport_cull_blocks_per_lane {
			return false
		}
		// Resolve the contexts used for ink tests on the owner. Unbounded
		// entries can leave their contexts unresolved.
		for index, testable in cache.testable {
			if testable {
				memo.resolve(order[index].box.accumulated_visual_context_index)
			}
		}
		mut threads := []u64{}
		if viewport_cull_worker_diagnostics { threads = []u64{len: block_count} }
		// These references remain in scope through the synchronous join.
		work := ViewportCullWork{
			cache: unsafe { cache }
			order: order
			contexts: memo.contexts
			slots: memo.slots
			selected: unsafe { &bool(selected.data) }
			threads: unsafe { if threads.len > 0 { &u64(threads.data) } else { &u64(nil) } }
			width: width
			height: height
		}
		lanes := cpuraster.run_raster_ranges_with_caller(&work, block_count,
			math.min(4, block_count / viewport_cull_blocks_per_lane), cull_viewport_block_range)
		if lanes == 0 { return false }
		if viewport_cull_worker_diagnostics {
			caller := platform.native_thread_identity()
			off_thread := threads.count(it != caller && it != 0)
			eprintln('VOX_VIEWPORT_CULL_BATCH entries=${order.len} blocks=${block_count} contexts=${memo.tree.nodes.len} lanes=${lanes} off_thread=${off_thread}')
		}
		return true
	}
	return false
}
