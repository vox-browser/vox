module layout

import math
import os
import platform

const disable_viewport_entry_blocks = os.getenv('VOX_DISABLE_VIEWPORT_ENTRY_BLOCKS') != ''
const viewport_entry_block_size = 32

// A run of consecutive paint entries. Entries the per-entry pass never culls
// (unbounded ink, or lines painted in a different descendant context) are
// left selected either way; the others are `testable`. When every testable
// entry shares one visual context and has a cached ink union, one test of the
// run's union can cull them together. The run uses the wider prepaint area if
// any of its testable entries does, which only keeps more entries.
struct ViewportEntryBlock {
	first     int
	count     int
	testable  int
	cullable  bool
	context   int
	prepaint  bool
	bounds    LayoutRect
}

fn viewport_entry_is_testable(box &BlockBox, entry ViewportCachedEntryInk) bool {
	return entry.bounded && !(box.paintable_with_lines
		&& box.accumulated_visual_context_index != box.accumulated_visual_context_for_descendants_idx)
}

// Rebuilt with the ink cache, and whenever visual contexts are reassigned.
fn refresh_viewport_entry_blocks(mut result DocumentLayoutResult) {
	mut cache := &result.record_scratch.viewport_ink_cache
	if !cache.valid { return }
	if cache.blocks_valid && cache.blocks_revision == cache.revision
		&& cache.blocks_contexts_data == result.visual_context_tree.nodes.data
		&& cache.blocks_contexts_len == result.visual_context_tree.nodes.len {
		return
	}
	persistent := platform.enter_persistent()
	defer { platform.leave_persistent(persistent) }
	cache.blocks.clear()
	cache.testable.clear()
	for index, entry in result.paint_order {
		cache.testable << viewport_entry_is_testable(entry.box, cache.entries[index])
	}
	for first := 0; first < result.paint_order.len; first += viewport_entry_block_size {
		count := math.min(viewport_entry_block_size, result.paint_order.len - first)
		cache.blocks << viewport_entry_block(result.paint_order, cache, first, count)
	}
	cache.blocks_revision = cache.revision
	cache.blocks_contexts_data = result.visual_context_tree.nodes.data
	cache.blocks_contexts_len = result.visual_context_tree.nodes.len
	cache.blocks_valid = true
}

fn viewport_entry_block(order []PaintOrderEntry, cache &ViewportEntryInkCache, first int,
	count int) ViewportEntryBlock {
	mut testable := 0
	mut context := -1
	mut prepaint := false
	mut cullable := true
	mut left := f64(0)
	mut top := f64(0)
	mut right := f64(0)
	mut bottom := f64(0)
	for index in first .. first + count {
		if !cache.testable[index] { continue }
		entry := cache.entries[index]
		box_context := order[index].box.accumulated_visual_context_index
		if !entry.has_bounds || (testable > 0 && box_context != context) {
			cullable = false
		}
		if entry.has_bounds {
			bounds := entry.bounds
			if testable == 0 {
				left, top = bounds.x, bounds.y
				right, bottom = bounds.x + bounds.width, bounds.y + bounds.height
			} else {
				left = math.min(left, bounds.x)
				top = math.min(top, bounds.y)
				right = math.max(right, bounds.x + bounds.width)
				bottom = math.max(bottom, bounds.y + bounds.height)
			}
		}
		if testable == 0 { context = box_context }
		prepaint = prepaint || entry.prepaint
		testable++
	}
	return ViewportEntryBlock{
		first:    first
		count:    count
		testable: testable
		cullable: cullable && testable > 0
		context:  context
		prepaint: prepaint
		bounds:   LayoutRect{left, top, right - left, bottom - top}
	}
}
