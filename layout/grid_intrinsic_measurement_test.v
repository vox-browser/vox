module layout

import css
import dom
import html
import platform

// Compare the entire scalar/glyph result with an unpooled oracle after the
// producer's scratch storage has retired. The root's track metadata belongs
// to normal layout and must survive an intrinsic probe without publication.
fn intrinsic_grid_measurement_test_compare(mut source LayoutState, root &Node,
	width int, constraint SizeConstraint, mode LayoutMode) bool {
	height := match constraint {
		.min_content { AvailableSize.make_min_content() }
		.max_content { AvailableSize.make_max_content() }
		else { AvailableSize.make_indefinite() }
	}
	space := AvailableSpace.new(AvailableSize.make_definite(CSSPixels.new(width)), height)
	styled := root.as_node_with_style() or { panic('style') }
	mut probe := source.new_measurement_for_subtree(styled)
	mut used := grid_measurement_test_prepare(mut probe, root, width, -29, 500)
	used.height_constraint = constraint
	used.set_grid_template_columns([CSSPixels.new(37)])
	used.set_grid_template_rows([CSSPixels.new(41)])
	used.set_grid_line_names([['unpublished-column']], [['unpublished-row']])
	used.offset = css.CSSPixelPoint.new(CSSPixels.new(11), CSSPixels.new(13))
	actual := run_grid_formatting_context_internal(mut probe, root, mut used, mode, space, false)
	if mode == .intrinsic_sizing {
		assert used.grid_template_columns() == [CSSPixels.new(37)]
		assert used.grid_template_rows() == [CSSPixels.new(41)]
		assert used.grid_column_line_names() == [['unpublished-column']]
		assert used.grid_row_line_names() == [['unpublished-row']]
	}
	mut retained := platform.enter_retained_allocations()
	geometry := grid_measurement_test_geometry(probe, root)
	retained.finish()
	mut reused := false
	for entry in source.measurement_chunk_pool_.grid_measurements_[u64(voidptr(root))] or { []&GridMeasurementLayout{} } {
		if entry.mode != mode { continue }
		for saved in entry.values {
			if saved.values.line_boxes.len == 0 { continue }
			if current := probe.try_get(saved.node) {
				if current.line_boxes.data == saved.values.line_boxes.data {
					reused = true
					before := saved.values.line_boxes[0].fragments_[0].inline_length_
					mut writable := probe.get_mutable(saved.node)
					writable.line_boxes[0].fragments_[0].inline_length_ = CSSPixels.new(999)
					assert saved.values.line_boxes[0].fragments_[0].inline_length_ == before
				}
			}
		}
	}
	probe.release_measurement()
	gc_collect()
	mut oracle := LayoutState.new_for_subtree(styled)
	mut expected := grid_measurement_test_prepare(mut oracle, root, width, -29, 500)
	expected.height_constraint = constraint
	expected.set_grid_template_columns([CSSPixels.new(37)])
	expected.set_grid_template_rows([CSSPixels.new(41)])
	expected.set_grid_line_names([['unpublished-column']], [['unpublished-row']])
	expected.offset = css.CSSPixelPoint.new(CSSPixels.new(11), CSSPixels.new(13))
	result := run_uncached_grid_formatting_context_internal(mut oracle, root, mut expected, mode, space, false)
	assert actual == result
	assert geometry == grid_measurement_test_geometry(oracle, root)
	oracle.release_measurement()
	return reused
}

fn test_intrinsic_grid_measurement_replays_closed_geometry_after_scratch_retirement() {
	for policy in [dom.FontRenderingPolicy.libweb, .chromium] {
		mut document := html.parse_document('<!doctype html><section id="grid" style="display:grid;width:180px;grid-template-columns:1fr 2fr;gap:7px"><div style="display:grid;grid-template-columns:1fr 1fr"><p>Nested wrapping words alpha beta gamma 😀.</p><p>Other words.</p></div><p style="grid-row:span 2">Row spanning text with enough words to wrap.</p><p>Last text.</p></section>')
		document.set_font_rendering_policy(policy)
		document.enable_native_storage()
		mut owner := document.enter_native_storage()
		defer { owner.finish(); document.finalize(); document.release_native_storage() }
		_ = layout_document_typed_in_viewport(document, 500, 400)
		root := grid_measurement_test_node(document, 'grid')
		for constraint in [SizeConstraint.none, .min_content, .max_content] {
			mut source := LayoutState.new()
			source.enable_measurement_chunk_pool()
			source.measurement_chunk_pool_.scratch_enabled_ = true
			for width in [180, 240] {
				assert !intrinsic_grid_measurement_test_compare(mut source, root, width, constraint, .intrinsic_sizing)
				assert intrinsic_grid_measurement_test_compare(mut source, root, width, constraint, .intrinsic_sizing) == (!disable_grid_measurement_reuse && !disable_intrinsic_grid_measurement_reuse)
			}
			pool := source.measurement_chunk_pool_
			source.release_measurement_chunk_pool()
			assert pool.closed && pool.grid_measurements_.len == 0
		}
	}
}

fn test_intrinsic_grid_measurement_keeps_normal_and_intrinsic_root_publication_separate() {
	mut document := html.parse_document('<!doctype html><section id="grid" style="display:grid;width:180px;grid-template-columns:[a] 1fr [b] 2fr;gap:5px"><p>First wrapping text alpha beta.</p><p>Other wrapping words.</p></section>')
	defer { document.finalize() }
	_ = layout_document_typed_in_viewport(document, 500, 400)
	root := grid_measurement_test_node(document, 'grid')
	mut source := LayoutState.new()
	source.enable_measurement_chunk_pool()
	defer { source.release_measurement_chunk_pool() }
	for mode in [LayoutMode.intrinsic_sizing, .normal] {
		assert !intrinsic_grid_measurement_test_compare(mut source, root, 180, .none, mode)
		assert intrinsic_grid_measurement_test_compare(mut source, root, 180, .none, mode) == (!disable_grid_measurement_reuse && (mode == .normal || !disable_intrinsic_grid_measurement_reuse))
	}
	assert intrinsic_grid_measurement_test_compare(mut source, root, 180, .none, .intrinsic_sizing) == (!disable_grid_measurement_reuse && !disable_intrinsic_grid_measurement_reuse)
	assert intrinsic_grid_measurement_test_compare(mut source, root, 180, .none, .normal) == !disable_grid_measurement_reuse
}

fn test_intrinsic_grid_measurement_rejects_changed_text_fonts_style_and_width() {
	mut document := html.parse_document('<!doctype html><section id="grid" style="display:grid;width:180px;grid-template-columns:1fr 1fr"><p id="item">Original wrapping text alpha beta gamma.</p><p>Other text.</p></section>')
	defer { document.finalize() }
	_ = layout_document_typed_in_viewport(document, 500, 400)
	root := grid_measurement_test_node(document, 'grid')
	mut source := LayoutState.new()
	source.enable_measurement_chunk_pool()
	defer { source.release_measurement_chunk_pool() }
	assert !intrinsic_grid_measurement_test_compare(mut source, root, 180, .max_content, .intrinsic_sizing)
	assert intrinsic_grid_measurement_test_compare(mut source, root, 180, .max_content, .intrinsic_sizing) == (!disable_grid_measurement_reuse && !disable_intrinsic_grid_measurement_reuse)
	assert !intrinsic_grid_measurement_test_compare(mut source, root, 181, .max_content, .intrinsic_sizing)
	mut item := grid_measurement_test_node(document, 'item')
	mut text := item.children()[0].as_text_node() or { panic('text') }
	mut data := (text.dom_node() or { panic('DOM') }).as_character_data() or { panic('data') }
	data.set_data('Replacement extraordinary wrapping words with a different height.')
	text.invalidate_text_for_rendering()
	assert !intrinsic_grid_measurement_test_compare(mut source, root, 180, .max_content, .intrinsic_sizing)
	mut computer := css.css_style_computer_for(document).font_computer()
	computer.did_load_font('IntrinsicGridFace')
	assert !intrinsic_grid_measurement_test_compare(mut source, root, 180, .max_content, .intrinsic_sizing)
	document.bump_style_environment_version()
	assert !intrinsic_grid_measurement_test_compare(mut source, root, 180, .max_content, .intrinsic_sizing)
}

fn test_intrinsic_grid_measurement_keeps_positioned_float_and_subgrid_effects_uncached() {
	for contents in ['<p style="position:absolute">Positioned</p>', '<p style="float:left">Float</p>', '<div style="display:grid;grid-template-columns:subgrid">Subgrid</div>'] {
		mut document := html.parse_document('<!doctype html><section id="grid" style="display:grid;width:180px;grid-template-columns:1fr 1fr">${contents}<p>Wrapping text with alpha beta gamma.</p></section>')
		defer { document.finalize() }
		_ = layout_document_typed_in_viewport(document, 500, 400)
		root := grid_measurement_test_node(document, 'grid')
		mut source := LayoutState.new()
		source.enable_measurement_chunk_pool()
		defer { source.release_measurement_chunk_pool() }
		for _ in 0 .. 2 { assert !intrinsic_grid_measurement_test_compare(mut source, root, 180, .max_content, .intrinsic_sizing) }
	}
}
