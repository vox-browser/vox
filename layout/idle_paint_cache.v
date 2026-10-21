module layout

import dom
import css
import platform

// The published vector owns every command needed to replay the current frame.
// Between recordings, phase buckets and the returned vector are only reusable
// storage. Release their backing arrays at the embedder's static idle boundary.
pub fn release_unused_display_list_caches(display_list &dom.DisplayList) {
	mut visited := map[u64]bool{}
	release_idle_display_list_caches(display_list, mut visited)
	trim_empty_inline_item_pages()
}

fn trim_empty_inline_item_pages() {
	$if prealloc {
		if platform.arena_thread_is_current() && inline_item_buffer_pool_ != unsafe { nil } && inline_item_buffer_pool_.depth == 0 {
			for arena in inline_item_buffer_pool_.arenas { arena.trim_empty_pages() }
		}
	}
}

// Arena maintenance must keep published caches: dropping their pointers would
// orphan the allocations. Only already-reset scratch and unreferenced spares
// have physical pages that can be discarded here.
pub fn trim_unused_layout_pages(display_list &dom.DisplayList) {
	$if prealloc {
		if !platform.arena_thread_is_current() { return }
		storage := platform.begin_thread_scratch('idle arena page scan')
		mut visited := map[u64]bool{}
		trim_layout_pages_in_list(display_list, mut visited)
		storage.finish()
		trim_empty_inline_item_pages()
	}
}

fn trim_spare_paint_pages(result &DocumentLayoutResult) {
	if result.scene_pool != unsafe { nil } {
		for scene in result.scene_pool.free {
			assert scene.references == 0
			scene.arena.trim_empty_pages()
		}
	}
	if result.paint_tree_pool != unsafe { nil } {
		for tree in result.paint_tree_pool.free {
			assert tree.references == 0
			tree.arena.trim_empty_pages()
		}
	}
}

fn trim_layout_pages_in_list(display_list &dom.DisplayList, mut visited map[u64]bool) {
	if display_list == unsafe { nil } || display_list.concrete_handle == unsafe { nil } { return }
	identity := u64(display_list.concrete_handle)
	if visited[identity] { return }
	result := viewport_layout_result(display_list.concrete_handle)
	if voidptr(result.display_list) != voidptr(display_list) { return }
	visited[identity] = true
	trim_spare_paint_pages(result)
	css.trim_unused_computation_pages(result.root.document())
	if viewport := result.root.as_viewport() {
		for _, image in viewport.svg_image_documents_ {
			if list := image.document.cached_display_list() { trim_layout_pages_in_list(list, mut visited) }
		}
	}
}

fn release_idle_display_list_caches(display_list &dom.DisplayList, mut visited map[u64]bool) {
	if voidptr(display_list) == unsafe { nil } || display_list.concrete_handle == unsafe { nil } {
		return
	}
	identity := u64(display_list.concrete_handle)
	if visited[identity] { return }
	mut result := viewport_layout_result(display_list.concrete_handle)
	if voidptr(result.display_list) != voidptr(display_list) || result.needs_repaint {
		return
	}
	visited[identity] = true
	// The replay plan holds pointers into phase buckets. Drop the complete
	// scratch generation together; clear() would retain scanned backing storage.
	result.record_scratch = CompatibilityRecordScratch{}
	result.paint_phase_commands = [][]PaintCommand{}
	result.paint_phase_entry_valid = []bool{}
	result.paint_phase_command_count = 0
	result.paint_phase_cache_valid = false
	// UsedValues and the published paint tree own their committed geometry.
	// These snapshots only accelerate a later layout or tree projection.
	mut state := unsafe { &LayoutState(result.state) }
	state.block_layouts_ = map[u64]&RetainedBlockLayout{}
	state.block_paint_owners_ = map[u64]&RetainedBlockLayout{}
	state.inline_layouts_ = map[u64]&RetainedInlineLayout{}
	result.root.for_each_in_inclusive_subtree(release_idle_node_projection)
	mut styles := []&css.ComputedProperties{}
	collect_idle_layout_styles(result.root, mut styles)
	_ = css.share_idle_layout_snapshots(styles)
	css.trim_unused_computation_pages(result.root.document())
	// Image documents record their own phase buckets. Releasing only the
	// embedding page leaves the complete scratch generation of each SVG alive.
	if viewport := result.root.as_viewport() {
		for _, image in viewport.svg_image_documents_ {
			if list := image.document.cached_display_list() {
				release_idle_display_list_caches(list, mut visited)
			}
		}
	}
}

fn collect_idle_layout_styles(node &Node, mut styles []&css.ComputedProperties) {
	if styled := node.as_node_with_style() { styles << styled.computed_values() }
	for child in node.children() { collect_idle_layout_styles(child, mut styles) }
}

fn release_idle_node_projection(node &Node) dom.TraversalDecision {
	mut mutable_node := unsafe { &Node(node) }
	mutable_node.ordinary_paint_box_ = unsafe { nil }
	mutable_node.flow_validation_cache_ = unsafe { nil }
	return .@continue
}
