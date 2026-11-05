module layout

import css
import dom
import crypto.sha256
import html

fn auto_height_seed_test_document(style string, contents string) &dom.Document {
	mut document := html.parse_document('<!doctype html><style>body{margin:0}p{margin:3px}#root{display:grid;grid-template-columns:1fr 2fr;gap:7px;${style}}</style><main><section id="root">${contents}</section></main>')
	_ = layout_document_typed_in_viewport(document, 500, 400)
	return document
}

fn auto_height_seed_test_measure(mut state LayoutState, root &Node, width int) (&UsedValues, FormattingContextResult) {
	mut used := grid_measurement_test_prepare(mut state, root, width, 0, 500)
	space := AvailableSpace.new(AvailableSize.make_definite(CSSPixels.new(width)), AvailableSize.make_indefinite())
	result := run_uncached_grid_formatting_context_internal(mut state, root, mut used, .normal, space, false)
	used.set_content_height(result.automatic_content_height)
	used.set_has_definite_height(false)
	return used, result
}

fn test_auto_row_grid_height_seed_matches_uncached_intrinsic_measurements() {
	for chromium in [false, true] {
		for contents in [
			'<p>Wrapping alpha beta gamma delta epsilon words.</p><p>Second paragraph with more words.</p>',
			'<div style="height:37px"></div><div style="height:61px"></div>',
			'<p style="grid-row:span 2">Spanning text wraps over multiple lines.</p><p>Short</p><p>Other content.</p>',
			'<div style="display:grid;grid-template-columns:1fr 1fr;gap:9px"><p>Nested text wraps.</p><p>More nested words.</p></div><p>Outside nested grid.</p>',
		] {
			mut document := auto_height_seed_test_document('', contents)
			defer { document.finalize() }
			if chromium { document.set_font_rendering_policy(.chromium) }
			root := grid_measurement_test_node(document, 'root')
			mut box := root.as_box()?
			assert grid_auto_height_seed_is_closed(root) == !disable_grid_auto_height_seed
			for width in [180, 320] {
				mut state := LayoutState.new()
				mut used, result := auto_height_seed_test_measure(mut state, root, width)
				box.reset_cached_intrinsic_sizes()
				assert seed_grid_auto_item_block_height(root, used, false) == !disable_grid_auto_height_seed
				oracle := calculate_content_height_with_constraint(mut state, box, used.content_width(), .max_content)
				assert result.automatic_content_height == oracle
				assert calculate_max_content_height(mut state, box, used.content_width()) == oracle
				geometry := grid_measurement_test_geometry(state, root).join('\n')
				println('GRID_AUTO_HEIGHT_ORACLE ${chromium} ${width} ${oracle.raw_value()} ${sha256.hexhash(geometry)}')
				state.release_measurement_chunk_pool()
			}
		}
	}
}

fn test_auto_row_grid_height_seed_rejects_dependent_and_specialized_descendants() {
	for contents in [
		'<p style="height:25%">Percentage height.</p>',
		'<p style="min-height:25%">Percentage minimum.</p>',
		'<p style="max-height:25%">Percentage maximum.</p>',
		'<div style="position:absolute">Positioned descendant.</div>',
		'<div style="display:grid;grid-template-rows:1fr"><p>Explicit rows.</p></div>',
		'<div style="display:grid;row-gap:10%"><p>Percentage gap.</p></div>',
		'<div style="display:flex"><p>Specialized flex measurement.</p></div>',
		'<img src="missing.png">', '<input value="control">',
		'<svg width="20" height="20"><rect width="10" height="10"/></svg>',
		'<div style="columns:2">Multicolumn layout.</div>',
	] {
		mut document := auto_height_seed_test_document('', contents)
		defer { document.finalize() }
		assert !grid_auto_height_seed_is_closed(grid_measurement_test_node(document, 'root'))
	}
	for style in ['grid-template-rows:auto', 'grid-auto-rows:20px', 'row-gap:10%'] {
		mut document := auto_height_seed_test_document(style, '<p>Text.</p>')
		defer { document.finalize() }
		assert !grid_auto_height_seed_is_closed(grid_measurement_test_node(document, 'root'))
	}
}

fn test_auto_row_grid_height_seed_keeps_constrained_roots_on_full_measurement() {
	for style in ['height:40px', 'min-height:100px', 'max-height:20px', 'aspect-ratio:2', 'contain:size'] {
		mut document := auto_height_seed_test_document(style, '<p>First text.</p><p>Second text.</p>')
		defer { document.finalize() }
		root := grid_measurement_test_node(document, 'root')
		mut state := LayoutState.new()
		mut used, _ := auto_height_seed_test_measure(mut state, root, 200)
		assert !seed_grid_auto_item_block_height(root, used, false)
		state.release_measurement_chunk_pool()
	}
	mut document := auto_height_seed_test_document('', '<p>Text.</p>')
	defer { document.finalize() }
	root := grid_measurement_test_node(document, 'root')
	mut state := LayoutState.new()
	mut used, _ := auto_height_seed_test_measure(mut state, root, 200)
	assert !seed_grid_auto_item_block_height(root, used, true)
	used.set_has_definite_height(true)
	assert !seed_grid_auto_item_block_height(root, used, false)
	used.set_has_definite_height(false)
	used.height_constraint = .min_content
	assert !seed_grid_auto_item_block_height(root, used, false)
	state.release_measurement_chunk_pool()
}

fn test_auto_row_grid_height_seed_survives_producer_scratch_retirement() {
	mut document := auto_height_seed_test_document('', '<p>Wrapping words that require several lines.</p><p>Other text.</p>')
	document.enable_native_storage()
	mut owner := document.enter_native_storage()
	defer { owner.finish(); document.finalize(); document.release_native_storage() }
	root := grid_measurement_test_node(document, 'root')
	mut box := root.as_box()?
	mut source := LayoutState.new()
	source.enable_measurement_chunk_pool()
	styled := root.as_node_with_style()?
	mut producer := source.new_measurement_for_subtree(styled)
	mut used, result := auto_height_seed_test_measure(mut producer, root, 200)
	box.reset_cached_intrinsic_sizes()
	assert seed_grid_auto_item_block_height(root, used, false) == !disable_grid_auto_height_seed
	producer.release_measurement()
	assert calculate_max_content_height(mut source, box, CSSPixels.new(200)) == result.automatic_content_height
	source.release_measurement_chunk_pool()
}

fn test_auto_row_grid_height_seed_observes_live_text_and_width_changes() {
	mut document := html.parse_document('<!doctype html><style>body{margin:0}#outer{display:grid;width:160px;align-items:start}#root{display:grid;grid-template-columns:1fr}</style><div id="outer"><section id="root"><p id="text">Short.</p></section></div>')
	defer { document.finalize() }
	mut previous := CSSPixels.new(0)
	for text in ['Short.', 'Many wrapping words repeated to make this paragraph require a larger automatic height at this width.'] {
		mut element := document.get_element_by_id('text')?
		element.as_node().set_text_content(text)!
		result := run_document_layout(document, 500, 400)?
		root := grid_measurement_test_node(document, 'root')
		box := root.as_box()?
		styled := root.as_node_with_style()?
		used := result.used_values_for(styled)?
		mut state := result.state
		oracle := calculate_content_height_with_constraint(mut state, box, used.content_width(), .max_content)
		assert calculate_max_content_height(mut state, box, used.content_width()) == oracle
		if text != 'Short.' { assert oracle.raw_value() > previous.raw_value() }
		previous = oracle
	}
}
