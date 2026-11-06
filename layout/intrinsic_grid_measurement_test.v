module layout

import css
import dom
import html
import platform

fn intrinsic_grid_probe_prepare(mut probe LayoutState, root &Node, width int, height int, parent_width int) &UsedValues {
	mut used := grid_measurement_test_prepare(mut probe, root, width, height, parent_width)
	used.set_grid_template_columns([CSSPixels.new(937)])
	used.set_grid_template_rows([CSSPixels.new(941)])
	used.set_grid_line_names([['caller-column']], [['caller-row']])
	used.set_grid_subgridded_axes(true, true)
	used.set_derived_baselines(CSSPixels.new(17), CSSPixels.new(19))
	return used
}

fn intrinsic_grid_probe_compare(mut source LayoutState, root &Node, width int, height int, parent_width int, constraint SizeConstraint) bool {
	pool := source.measurement_chunk_pool_
	key := u64(voidptr(root))
	before := (pool.intrinsic_grid_measurements_[key] or { []&GridMeasurementLayout{} }).map(u64(voidptr(it)))
	space := AvailableSpace.new(AvailableSize.make_definite(CSSPixels.new(width)),
		if constraint == .min_content { AvailableSize.make_min_content() } else { AvailableSize.make_max_content() })
	mut probe := source.new_measurement_for_subtree(root.as_node_with_style() or { panic('missing style') })
	mut used := intrinsic_grid_probe_prepare(mut probe, root, width, height, parent_width)
	used.height_constraint = constraint
	actual := run_grid_formatting_context_internal(mut probe, root, mut used, .intrinsic_sizing, space, false)
	mut retained := platform.enter_retained_allocations()
	geometry := grid_measurement_test_geometry(probe, root)
	retained.finish()
	assert used.grid_template_columns() == [CSSPixels.new(937)]
	assert used.grid_template_rows() == [CSSPixels.new(941)]
	assert used.grid_column_line_names() == [['caller-column']]
	assert used.grid_row_line_names() == [['caller-row']]
	assert used.grid_columns_are_subgrid() && used.grid_rows_are_subgrid()
	assert (used.derived_first_baseline() or { panic('lost first baseline') }) == CSSPixels.new(17)
	assert (used.derived_last_baseline() or { panic('lost last baseline') }) == CSSPixels.new(19)
	after := (pool.intrinsic_grid_measurements_[key] or { []&GridMeasurementLayout{} }).map(u64(voidptr(it)))
	reused := before.len > 0 && before.len == after.len && after.all(it in before)
	probe.release_measurement()
	gc_collect()
	mut oracle := LayoutState.new_for_subtree(root.as_node_with_style() or { panic('missing style') })
	mut expected := intrinsic_grid_probe_prepare(mut oracle, root, width, height, parent_width)
	expected.height_constraint = constraint
	assert actual == run_uncached_grid_formatting_context_internal(mut oracle, root, mut expected, .intrinsic_sizing, space, false)
	assert geometry == grid_measurement_test_geometry(oracle, root)
	oracle.release_measurement()
	return reused
}

fn test_intrinsic_grid_replays_owned_height_and_descendants_after_scratch_release() {
	for rules in ['grid-template-columns:1fr 2fr;gap:7px', 'grid-template-columns:repeat(auto-fit,minmax(60px,1fr));gap:3px;direction:rtl'] {
		mut document := html.parse_document('<!doctype html><section id="grid" style="display:grid;${rules}"><div style="display:grid;grid-template-columns:1fr 1fr"><p>Nested wrapping alpha beta gamma.</p><p>More text.</p></div><div style="display:flex"><p>Flex text.</p><p>Other text.</p></div><p>Last text.</p></section>')
		document.enable_native_storage()
		mut owner := document.enter_native_storage()
		defer { owner.finish(); document.finalize(); document.release_native_storage() }
		_ = layout_document_typed_in_viewport(document, 500, 400)
		root := grid_measurement_test_node(document, 'grid')
		mut source := LayoutState.new()
		source.enable_measurement_chunk_pool()
		source.measurement_chunk_pool_.scratch_enabled_ = true
		for constraint in [SizeConstraint.min_content, .max_content] {
			assert !intrinsic_grid_probe_compare(mut source, root, 240, 0, 500, constraint)
			for _ in 0 .. 3 {
				assert intrinsic_grid_probe_compare(mut source, root, 240, 0, 500, constraint) == (!disable_grid_measurement_reuse && !disable_intrinsic_grid_measurement_reuse)
			}
		}
		pool := source.measurement_chunk_pool_
		source.release_measurement_chunk_pool()
		assert pool.closed && pool.intrinsic_grid_measurements_.len == 0
	}
}

fn test_intrinsic_grid_keys_recheck_width_height_constraints_and_external_bases() {
	mut document := html.parse_document('<!doctype html><main><section id="grid" style="display:grid;grid-template-columns:1fr 2fr"><p style="height:25%">Alpha beta gamma text.</p><p>Other text.</p></section></main>')
	defer { document.finalize() }
	_ = layout_document_typed_in_viewport(document, 500, 400)
	root := grid_measurement_test_node(document, 'grid')
	mut source := LayoutState.new()
	source.enable_measurement_chunk_pool()
	defer { source.release_measurement_chunk_pool() }
	for dimensions in [[180, 0, 500], [181, 0, 500], [180, 0, 501], [180, 160, 500]] {
		assert !intrinsic_grid_probe_compare(mut source, root, dimensions[0], dimensions[1], dimensions[2], .min_content)
		assert intrinsic_grid_probe_compare(mut source, root, dimensions[0], dimensions[1], dimensions[2], .min_content) == (!disable_grid_measurement_reuse && !disable_intrinsic_grid_measurement_reuse)
	}
	assert (source.measurement_chunk_pool_.intrinsic_grid_measurements_[u64(voidptr(root))] or { []&GridMeasurementLayout{} }).len <= 4
}

fn test_intrinsic_grid_rechecks_font_environment_text_and_style_mutation() {
	mut document := html.parse_document('<!doctype html><section id="grid" style="display:grid;grid-template-columns:1fr 1fr"><p id="item">Alpha beta gamma wrapping text.</p><p>Other text.</p></section>')
	defer { document.finalize() }
	_ = layout_document_typed_in_viewport(document, 500, 400)
	root := grid_measurement_test_node(document, 'grid')
	mut source := LayoutState.new()
	source.enable_measurement_chunk_pool()
	defer { source.release_measurement_chunk_pool() }
	assert !intrinsic_grid_probe_compare(mut source, root, 180, 0, 500, .max_content)
	mut computer := css.css_style_computer_for(document).font_computer()
	computer.did_load_font('UnrelatedIntrinsicGridFace')
	assert !intrinsic_grid_probe_compare(mut source, root, 180, 0, 500, .max_content)
	document.bump_style_environment_version()
	assert !intrinsic_grid_probe_compare(mut source, root, 180, 0, 500, .max_content)
	mut item := grid_measurement_test_node(document, 'item')
	mut text := item.children()[0].as_text_node()?
	mut data := text.dom_node()?.as_character_data()?
	data.set_data('Different longer wrapping text repeated repeated repeated.')
	text.invalidate_text_for_rendering()
	assert !intrinsic_grid_probe_compare(mut source, root, 180, 0, 500, .max_content)
	mut style_owner := document.create_element('p')!
	style_owner.set_attribute_value('style', 'display:block;font-size:27px')
	mut styled := item.as_node_with_style()?
	styled.apply_style(css.css_style_computer_for(document).compute_style(dom.AbstractElement.new(style_owner, none)))
	assert !intrinsic_grid_probe_compare(mut source, root, 180, 0, 500, .max_content)
}

fn test_intrinsic_grid_entries_do_not_evict_or_replay_ordinary_grid_entries() {
	mut document := html.parse_document('<!doctype html><section id="grid" style="display:grid;grid-template-columns:1fr 2fr"><p>Wrapping alpha beta gamma.</p><p>Other text.</p></section>')
	defer { document.finalize() }
	_ = layout_document_typed_in_viewport(document, 500, 400)
	root := grid_measurement_test_node(document, 'grid')
	mut source := LayoutState.new()
	source.enable_measurement_chunk_pool()
	defer { source.release_measurement_chunk_pool() }
	assert !grid_measurement_test_compare(mut source, root, 180, 0, 500)
	ordinary := (source.measurement_chunk_pool_.grid_measurements_[u64(voidptr(root))] or { []&GridMeasurementLayout{} }).map(u64(voidptr(it)))
	for width in [180, 190, 200, 210, 220] { assert !intrinsic_grid_probe_compare(mut source, root, width, 0, 500, .max_content) }
	assert ordinary == (source.measurement_chunk_pool_.grid_measurements_[u64(voidptr(root))] or { []&GridMeasurementLayout{} }).map(u64(voidptr(it)))
	assert grid_measurement_test_compare(mut source, root, 180, 0, 500) == !disable_grid_measurement_reuse
}

fn test_intrinsic_grid_keeps_committed_definite_height_and_width_only_paths_uncached() {
	mut document := html.parse_document('<!doctype html><section id="grid" style="display:grid;grid-template-columns:1fr 1fr"><p>Text.</p><p>Other text.</p></section>')
	defer { document.finalize() }
	_ = layout_document_typed_in_viewport(document, 500, 400)
	root := grid_measurement_test_node(document, 'grid')
	mut source := LayoutState.new()
	source.enable_measurement_chunk_pool()
	defer { source.release_measurement_chunk_pool() }
	for kind in ['committed', 'definite', 'width-only'] {
		mut probe := if kind == 'committed' { LayoutState.new() } else { source.new_measurement_for_subtree(root.as_node_with_style() or { panic('missing style') }) }
		if kind == 'committed' { probe.enable_measurement_chunk_pool() }
		mut used := intrinsic_grid_probe_prepare(mut probe, root, 180, 160, 500)
		space := AvailableSpace.new(AvailableSize.make_definite(CSSPixels.new(180)),
			if kind == 'definite' { AvailableSize.make_definite(CSSPixels.new(160)) } else { AvailableSize.make_max_content() })
		actual := run_grid_formatting_context_internal(mut probe, root, mut used, .intrinsic_sizing, space, kind == 'width-only')
		mut oracle := LayoutState.new_for_subtree(root.as_node_with_style() or { panic('missing style') })
		mut expected := intrinsic_grid_probe_prepare(mut oracle, root, 180, 160, 500)
		assert actual == run_uncached_grid_formatting_context_internal(mut oracle, root, mut expected, .intrinsic_sizing, space, kind == 'width-only')
		assert grid_measurement_test_geometry(probe, root) == grid_measurement_test_geometry(oracle, root)
		assert probe.measurement_chunk_pool_.intrinsic_grid_measurements_.len == 0
		oracle.release_measurement()
		if kind == 'committed' { probe.release_measurement_chunk_pool() } else { probe.release_measurement() }
	}
}
