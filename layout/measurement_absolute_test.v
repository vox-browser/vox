module layout

import css
import dom
import html
import platform

fn absolute_measurement_document(kind string, contents string, rules string) &dom.Document {
	mut document := html.parse_document('<!doctype html><main><section id="root" style="display:${kind};position:relative;grid-template-columns:[start] 1fr [middle] 2fr [end];gap:7px;align-items:start;${rules}">${contents}<p>Wrapping alpha beta gamma 😀 á words for retained lines.</p></section></main>')
	document.enable_native_storage()
	mut owner := document.enter_native_storage()
	_ = layout_document_typed_in_viewport(document, 500, 400)
	owner.finish()
	return document
}

fn absolute_measurement_geometry(state &LayoutState, root &Node) []string {
	mut result := measurement_image_geometry(state, root)
	absolute_measurement_positions(state, root, mut result)
	return result
}

fn absolute_measurement_positions(state &LayoutState, node &Node, mut result []string) {
	if styled := node.as_node_with_style() {
		if used := state.try_get(styled) {
			if rare := used.rare_ {
				result << '${rare.static_position_rect_} ${rare.abspos_containing_block_rect_}'
			}
			result << '${used.relative_inset_basis_width()} ${used.relative_inset_basis_height()}'
		}
	}
	for child in node.children() { absolute_measurement_positions(state, child, mut result) }
}

// Compare both pre-absolute static records and final absolute geometry to a
// separate unpooled full algorithm. Preserve scalar/glyph data before retiring
// the producer arena, and exercise committed consumption as well as probes.
fn absolute_measurement_compare(mut source LayoutState, root &Node, width int, height int,
	committed bool) bool {
	styled := root.as_node_with_style() or { panic('style') }
	space := AvailableSpace.new(AvailableSize.make_definite(CSSPixels.new(width)),
		if height > 0 { AvailableSize.make_definite(CSSPixels.new(height)) } else { AvailableSize.make_indefinite() })
	mut probe := source.new_measurement_for_subtree(styled)
	if committed { probe.subtree_root = none }
	mut used := measurement_image_prepare(mut probe, root, width, height)
	actual := measurement_image_run(mut probe, root, mut used, space, true)
	mut retained := platform.enter_retained_allocations()
	before := absolute_measurement_geometry(probe, root)
	retained.finish()
	mut reused := false
	key := u64(voidptr(root))
	mut snapshots := []RetainedBlockValues{}
	if root.display().is_grid_inside() {
		for entry in source.measurement_chunk_pool_.grid_measurements_[key] or { []&GridMeasurementLayout{} } { snapshots << entry.values }
	} else {
		for entry in source.measurement_chunk_pool_.flex_measurements_[key] or { []&FlexMeasurementLayout{} } { snapshots << entry.values }
	}
	for entry in snapshots {
		if entry.values.line_boxes.len == 0 { continue }
		if current := probe.try_get(entry.node) {
			if current.line_boxes.data == entry.values.line_boxes.data { reused = true }
		}
	}
	layout_absolutely_positioned_descendants(mut probe, root)
	retained = platform.enter_retained_allocations()
	after := absolute_measurement_geometry(probe, root)
	retained.finish()
	// A consumer modifying final absolute/static records must detach rare data
	// just as it detaches retained line/glyph arrays.
	for entry in snapshots {
		if entry.values.rare_ == none { continue }
		mut writable := probe.get_mutable(entry.node)
		writable.set_static_position_rect(StaticPositionRect{ rect: css.CSSPixelRect.new(999, 999, 1, 1) })
		if rare := entry.values.rare_ {
			if position := rare.static_position_rect_ { assert position.rect.x != CSSPixels.new(999) }
		}
	}
	probe.release_measurement()
	gc_collect()
	mut oracle := LayoutState.new_for_subtree(styled)
	if committed { oracle.subtree_root = none }
	mut expected := measurement_image_prepare(mut oracle, root, width, height)
	assert actual == measurement_image_run(mut oracle, root, mut expected, space, false)
	assert before == absolute_measurement_geometry(oracle, root)
	layout_absolutely_positioned_descendants(mut oracle, root)
	assert after == absolute_measurement_geometry(oracle, root)
	oracle.release_measurement()
	return reused
}

fn absolute_measurement_enabled(kind string) bool {
	return !retain_absolute_measurement_layout && if kind == 'grid' { !disable_grid_measurement_reuse } else { !disable_flex_measurement_reuse }
}

fn test_absolute_measurements_keep_static_rects_and_final_layout_exact_after_scratch_retirement() {
	for kind in ['grid', 'flex'] {
		for contents in [
			'<div id="absolute" style="position:absolute;width:40%;height:25%;left:10%;top:5px">Absolute wrapping words.</div>',
			'<span id="absolute" style="position:absolute;inset:auto;grid-column:middle/end;justify-self:center;align-self:end">Static words.</span>',
			'<div style="position:relative;display:flex"><p>Nested normal text.</p><span id="absolute" style="position:absolute;right:8%;bottom:3px;width:60px">Nested words.</span></div>',
			'<div><span>Inline start <span id="absolute" style="position:absolute;inset:auto;width:65px">Inline abs words.</span> after inline.</span></div>'
		] {
			mut document := absolute_measurement_document(kind, contents, 'direction:rtl;justify-content:center')
			mut owner := document.enter_native_storage()
			defer { owner.finish(); document.finalize(); document.release_native_storage() }
			root := measurement_image_node(document, 'root')
			mut source := LayoutState.new()
			source.enable_measurement_chunk_pool()
			source.measurement_chunk_pool_.scratch_enabled_ = true
			defer { source.release_measurement_chunk_pool() }
			for width in [120, 180] {
				for height in [0, 160] {
					assert !absolute_measurement_compare(mut source, root, width, height, false)
					for _ in 0 .. 3 { assert absolute_measurement_compare(mut source, root, width, height, false) == absolute_measurement_enabled(kind) }
					assert absolute_measurement_compare(mut source, root, width, height, true) == (absolute_measurement_enabled(kind)
						&& if kind == 'grid' { !disable_committed_grid_measurement_reuse } else { !disable_committed_flex_measurement_reuse })
				}
			}
			mut inputs := []RetainedInlineInput{}
			mut rejected := map[u64]bool{}
			assert !collect_retained_block_inputs(root, mut inputs, mut rejected)
		}
	}
}

fn test_absolute_measurements_validate_mutations_before_reusing_static_positions() {
	for kind in ['grid', 'flex'] {
		for change in ['inset', 'size', 'text', 'raw-alias', 'external-containing-block'] {
			mut document := absolute_measurement_document(kind, '<div id="absolute" style="position:absolute;left:4px;top:8px;width:65px">Original wrapping words.</div>', '')
			mut owner := document.enter_native_storage()
			defer { owner.finish(); document.finalize(); document.release_native_storage() }
			root := measurement_image_node(document, 'root')
			absolute := measurement_image_node(document, 'absolute')
			mut source := LayoutState.new()
			source.enable_measurement_chunk_pool()
			source.measurement_chunk_pool_.scratch_enabled_ = true
			defer { source.release_measurement_chunk_pool() }
			assert !absolute_measurement_compare(mut source, root, 180, 160, false)
			assert absolute_measurement_compare(mut source, root, 180, 160, false) == absolute_measurement_enabled(kind)
			if change == 'text' {
				mut text := absolute.children()[0].as_text_node()?
				mut data := text.dom_node()?.as_character_data()?
				data.set_data('Changed text that wraps quite differently.')
				text.invalidate_text_for_rendering()
			} else if change == 'external-containing-block' {
				mut node := unsafe { &Node(absolute) }
				node.containing_block_ = root.containing_block()
			} else {
				mut properties := unsafe { &css.ComputedProperties(absolute.computed_values()) }
				property := if change == 'size' { css.PropertyID.width } else { css.PropertyID.left }
				value := css.parse_css_value(css.ParsingParams{}, '27px', property) or { panic('value') }
				if change == 'raw-alias' { mut alias := *properties; alias.set_property(property, value, .no, .no) }
				else { properties.set_property(property, value, .no, .no) }
			}
			if kind == 'grid' {
				for entry in source.measurement_chunk_pool_.grid_measurements_[u64(voidptr(root))] or { []&GridMeasurementLayout{} } { assert !grid_measurement_inputs_are_current(entry.inputs), change }
			} else {
				for entry in source.measurement_chunk_pool_.flex_measurements_[u64(voidptr(root))] or { []&FlexMeasurementLayout{} } { assert !grid_measurement_inputs_are_current(entry.inputs), change }
			}
			assert !absolute_measurement_compare(mut source, root, 180, 160, false), change
			// A changed absolute subtree may retain stale font-owner projections
			// until final layout. Correctly declining admission is allowed.
			for _ in 0 .. 2 { _ = absolute_measurement_compare(mut source, root, 180, 160, false) }
		}
	}
}

fn test_absolute_measurements_keep_specialized_positions_and_roots_on_full_layout() {
	for contents in [
		'<div style="position:fixed">Fixed</div>', '<div style="position:sticky;top:2px">Sticky</div>',
		'<div style="position:relative;left:2px">Relative</div>',
		'<dialog style="display:block;position:absolute">Dialog</dialog>',
		'<div style="position:absolute;left:calc(10% + 2px)">Calculation</div>',
		'<div style="position:absolute;left:anchor(--outside left)">Anchor</div>',
		'<div style="position:absolute;position-anchor:--outside">Named anchor</div>',
		'<input style="position:absolute" value="control">'
	] {
		mut document := absolute_measurement_document('grid', contents, '')
		mut owner := document.enter_native_storage()
		defer { owner.finish(); document.finalize(); document.release_native_storage() }
		root := measurement_image_node(document, 'root')
		mut inputs := []RetainedInlineInput{}
		mut rejected := map[u64]bool{}
		assert !collect_grid_measurement_inputs(root, mut inputs, mut rejected), contents
	}
	mut document := absolute_measurement_document('grid', '<div id="absolute" style="position:absolute;display:grid"><p>Words.</p></div>', '')
	mut owner := document.enter_native_storage()
	defer { owner.finish(); document.finalize(); document.release_native_storage() }
	root := measurement_image_node(document, 'absolute')
	mut inputs := []RetainedInlineInput{}
	mut rejected := map[u64]bool{}
	assert !collect_grid_measurement_inputs(root, mut inputs, mut rejected)
}
