module layout

import os
import platform

const disable_viewport_entry_candidates = os.getenv('VOX_DISABLE_VIEWPORT_ENTRY_CANDIDATES') != ''

// Per-frame passes that only act on a few rare boxes (fixed backgrounds,
// compositor surfaces, scrollers, sticky and fixed boxes) scanned every paint
// entry on every scrolled frame. These box properties only change with layout
// or visual-context assignment, so collect each pass's candidates once per
// paint revision and context tree. Each pass still applies its exact test.
struct ViewportEntryCandidates {
mut:
	valid         bool
	revision      u64
	order         voidptr
	order_len     int
	contexts      voidptr
	contexts_len  int
	fixed_backgrounds []int
	raster_layers     []int
}

fn viewport_entry_candidates(mut result DocumentLayoutResult) &ViewportEntryCandidates {
	revision := result.document.paint_content_revision()
	mut cache := &result.entry_candidates
	if cache.valid && cache.revision == revision && cache.order == result.paint_order.data
		&& cache.order_len == result.paint_order.len
		&& cache.contexts == result.visual_context_tree.nodes.data
		&& cache.contexts_len == result.visual_context_tree.nodes.len {
		return cache
	}
	persistent := platform.enter_persistent()
	defer { platform.leave_persistent(persistent) }
	cache.fixed_backgrounds.clear()
	cache.raster_layers.clear()
	for index, entry in result.paint_order {
		box := entry.box
		if box.decorations().background_images.any(it.attachment == 'fixed') {
			cache.fixed_backgrounds << index
		}
		// A superset of every box update_chromium_raster_layer_plan_with_cull
		// records: compositor surfaces, user scrollers, sticky and fixed boxes.
		if box.chromium_compositor_surface || box.own_scroll_frame_index > 0
			|| box.sticky_scroll_frame_index > 0 || box.fixed_to_viewport {
			cache.raster_layers << index
		}
	}
	cache.revision = revision
	cache.order = result.paint_order.data
	cache.order_len = result.paint_order.len
	cache.contexts = result.visual_context_tree.nodes.data
	cache.contexts_len = result.visual_context_tree.nodes.len
	cache.valid = true
	return cache
}
