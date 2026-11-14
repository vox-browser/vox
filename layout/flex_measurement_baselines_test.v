module layout

import html
import dom

fn baseline_reuse_root(document &dom.Document) &Node {
	element := document.get_element_by_id('flex') or { panic('flex') }
	return unsafe { &Node(element.as_node().unsafe_layout_node() or { panic('layout') }.real_layout_handle()) }
}

fn baseline_reuse_values(mut state LayoutState, root &Node) &UsedValues {
	parent := root.containing_block() or { panic('parent') }
	mut ancestors := LayoutState.new()
	mut parent_values := ancestors.get_mutable(unsafe { &NodeWithStyle(parent) })
	parent_values.set_content_width(CSSPixels.new(500))
	parent_values.set_content_height(CSSPixels.new(300))
	parent_values.set_has_definite_height(true)
	populate_intrinsic_containing_block_chain(mut state, mut ancestors, root)
	mut used := state.get_mutable(root.as_node_with_style() or { panic('style') })
	used.set_containing_block_used_values(state.get_mutable(unsafe { &NodeWithStyle(parent) }))
	used.set_content_width(CSSPixels.new(180))
	used.set_content_height(CSSPixels.new(80))
	used.set_has_definite_height(true)
	return used
}

fn test_committed_flex_measurement_restores_published_root_baselines() {
	for direction in ['row', 'column'] {
		mut document := html.parse_document('<!doctype html><main><section id="flex" style="display:flex;flex-direction:${direction}"><div>First<br>Last</div></section></main>')
		document.enable_native_storage()
		mut owner := document.enter_native_storage()
		defer {
			owner.finish()
			document.finalize()
			document.release_native_storage()
		}
		document.set_font_rendering_policy(.chromium)
		_ = layout_document_typed_in_viewport(document, 500, 400)
		root := baseline_reuse_root(document)
		styled := root.as_node_with_style() or { panic('style') }
		mut source := LayoutState.new()
		source.enable_measurement_chunk_pool()
		source.measurement_chunk_pool_.scratch_enabled_ = true
		space := AvailableSpace.new(AvailableSize.make_definite(CSSPixels.new(180)), AvailableSize.make_definite(CSSPixels.new(80)))
		mut producer := source.new_measurement_for_subtree(styled)
		mut measured := baseline_reuse_values(mut producer, root)
		_ = run_flex_formatting_context_with_mode(mut producer, root, mut measured, .normal, space)
		first := (measured.derived_first_baseline() or { panic('measured first') }).raw_value()
		last := (measured.derived_last_baseline() or { panic('measured last') }).raw_value()
		entries := source.measurement_chunk_pool_.flex_measurements_[u64(voidptr(root))] or { panic('missing cache') }
		count := entries.len
		assert count == 1
		producer.release_measurement()
		mut used := baseline_reuse_values(mut source, root)
		used.set_derived_baselines(CSSPixels.new(71), CSSPixels.new(93))
		_ = run_flex_formatting_context_with_mode(mut source, root, mut used, .normal, space)
		actual_first := (used.derived_first_baseline() or { panic('lost first baseline') }).raw_value()
		actual_last := (used.derived_last_baseline() or { panic('lost last baseline') }).raw_value()
		assert actual_first == first
		assert actual_last == last
		mut reused_lines := false
		for entry in entries[0].values {
			if entry.values.line_boxes.len == 0 { continue }
			if current := source.try_get(entry.node) {
				if current.line_boxes.data == entry.values.line_boxes.data { reused_lines = true }
			}
		}
		assert reused_lines
		source.release_measurement_chunk_pool()
	}
}
