module layout

import dom
import platform

fn measurement_height_compare(mut source LayoutState, container &BlockContainer,
	space AvailableSpace, mode LayoutMode, height CSSPixels, definite bool) bool {
	styled := unsafe { &NodeWithStyle(container) }
	mut probe := source.new_measurement_for_subtree(styled)
	mut used := probe.get_mutable(styled)
	used.set_content_width(space.width.to_px_or_zero())
	used.set_content_height(height)
	used.set_has_definite_height(definite)
	width_only := !space.width.is_definite()
	actual := run_inline_formatting_context_for_width(mut probe, container, mut used,
		mode, space, none, width_only)
	mut snapshots := platform.enter_retained_allocations()
	lines := measurement_inline_lines(used.line_boxes)
	snapshots.finish()
	end := used.inline_end_static_position_rect()
	remaining_height := used.content_height()
	reused := used.line_boxes_are_shared_
	probe.release_measurement()
	gc_collect()
	mut oracle := source.new_measurement_for_subtree(styled)
	defer { oracle.release_measurement() }
	mut expected := oracle.get_mutable(styled)
	expected.set_content_width(space.width.to_px_or_zero())
	expected.set_content_height(height)
	expected.set_has_definite_height(definite)
	result := run_uncached_inline_formatting_context_for_width(mut oracle, container,
		mut expected, mode, space, none, width_only)
	assert actual == result
	assert lines == measurement_inline_lines(expected.line_boxes)
	assert end == expected.inline_end_static_position_rect()
	assert remaining_height == expected.content_height()
	assert definite == expected.has_definite_height()
	return reused
}

fn test_inline_measurement_ignores_unused_indefinite_height_across_retired_probes() {
	mut document := dom.Document.create(dom.url_about_blank())
	defer { document.finalize() }
	document.set_font_rendering_policy(.chromium)
	container := measurement_inline_fixture(document, '')
	mut source := LayoutState.new()
	source.enable_measurement_chunk_pool()
	defer { source.release_measurement_chunk_pool() }
	for mode in [LayoutMode.normal, .intrinsic_sizing] {
		for width in [AvailableSize.make_definite(CSSPixels.new(180)),
			AvailableSize.make_min_content(), AvailableSize.make_max_content()] {
			space := AvailableSpace.new(width, AvailableSize.make_indefinite())
			assert !measurement_height_compare(mut source, container, space, mode, CSSPixels.new(17), false)
			assert measurement_height_compare(mut source, container, space, mode, CSSPixels.new(999), false) == (!disable_inline_measurement_reuse && !retain_inline_measurement_indefinite_height)
		}
	}
}

fn test_inline_measurement_keeps_definite_height_and_basis_transitions_in_the_key() {
	mut document := dom.Document.create(dom.url_about_blank())
	defer { document.finalize() }
	container := measurement_inline_fixture(document, '')
	mut source := LayoutState.new()
	source.enable_measurement_chunk_pool()
	defer { source.release_measurement_chunk_pool() }
	space := AvailableSpace.new(AvailableSize.make_definite(CSSPixels.new(180)), AvailableSize.make_indefinite())
	assert !measurement_height_compare(mut source, container, space, .normal, CSSPixels.new(17), true)
	assert !measurement_height_compare(mut source, container, space, .normal, CSSPixels.new(999), true)
	assert measurement_height_compare(mut source, container, space, .normal, CSSPixels.new(17), true) == !disable_inline_measurement_reuse
	assert !measurement_height_compare(mut source, container, space, .normal, CSSPixels.new(17), false)
}
