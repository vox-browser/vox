module css

import dom

fn edge_resolution_style() &ComputedProperties {
	mut style := computed_properties_with_initial_values()
	style.set_property(.font_size, &dom.StyleValue{ css_text: '20px' }, .no, .no)
	style.set_property(.line_height, &dom.StyleValue{ css_text: '2' }, .no, .no)
	style.root_font_size_px_ = 12
	style.root_line_height_px_ = 18
	style.viewport_rect_ = CSSPixelRect.new(0, 0, 800, 600)
	return style
}

fn assert_resolved_edges_match_property_resolution(style &ComputedProperties, basis f64) {
	values := resolve_computed_values(style)
	edges := values.resolved_box_model_edges(basis)
	actual := [edges.padding_left, edges.padding_right, edges.padding_top, edges.padding_bottom,
		edges.margin_left, edges.margin_right, edges.margin_top, edges.margin_bottom]
	for index, property in [PropertyID.padding_left, .padding_right, .padding_top, .padding_bottom,
		.margin_left, .margin_right, .margin_top, .margin_bottom] {
		expected := CSSPixels.nearest_value_for(values.length_percentage_to_px(property, basis) or { 0.0 })
		assert actual[index] == expected, '${property} at ${basis}: ${actual[index].raw_value()} != ${expected.raw_value()}'
	}
	for index, property in [PropertyID.border_left_width, .border_right_width, .border_top_width,
		.border_bottom_width] {
		actual_border := [edges.border_left, edges.border_right, edges.border_top, edges.border_bottom][index]
		assert actual_border == CSSPixels.nearest_value_for(values.border_data(property).width.to_double())
	}
}

fn test_resolved_edges_keep_absolute_unit_rounding_auto_margins_and_saturation() {
	mut style := edge_resolution_style()
	for unit in ['px', 'cm', 'mm', 'q', 'in', 'pt', 'pc'] {
		for magnitude in ['0', '0.0078125', '1.125', '31.9921875', '100000000'] {
			for property in [PropertyID.padding_left, .padding_right, .padding_top, .padding_bottom,
				.margin_left, .margin_right, .margin_top, .margin_bottom] {
				value := parse_css_value(ParsingParams{}, magnitude + unit, property)?
				style.set_property(property, value, .no, .no)
			}
			for basis in [f64(0), 1.0078125, 100.125, 100000000] {
				assert_resolved_edges_match_property_resolution(style, basis)
			}
		}
	}
	for property, text in {
		PropertyID.margin_left: 'auto'
		.margin_right:          '-0.0078125px'
		.margin_top:            '-100000000px'
		.border_left_style:     'solid'
		.border_right_style:    'none'
		.border_top_style:      'hidden'
		.border_left_width:     '1.125px'
		.border_right_width:    '20px'
		.border_top_width:      '20px'
	} {
		value := parse_css_value(ParsingParams{}, text, property)?
		style.set_property(property, value, .no, .no)
	}
	assert_resolved_edges_match_property_resolution(style, 231.23456)
}

fn test_resolved_edges_keep_percentage_and_live_relative_calculation_contexts() {
	mut style := edge_resolution_style()
	for text in ['33.333333%', '0.5%', '250%', '2em', '2rem', '2lh', '2rlh', '10vw', '10vh', '10cqi',
		'calc(2em + 25%)'] {
		for property in [PropertyID.padding_left, .padding_right, .padding_top, .padding_bottom,
			.margin_left, .margin_right, .margin_top, .margin_bottom] {
			value := parse_css_value(ParsingParams{}, text, property)?
			style.set_property(property, value, .no, .no)
		}
		for basis in [f64(-33.125), 0, 0.0078125, 1.0078125, 100.125, 100000000] {
			assert_resolved_edges_match_property_resolution(style, basis)
		}
		style.root_font_size_px_ = 24
		style.root_line_height_px_ = 36
		style.viewport_rect_ = CSSPixelRect.new(0, 0, 400, 300)
		style.set_property(.font_size, &dom.StyleValue{ css_text: '30px' }, .no, .no)
		assert_resolved_edges_match_property_resolution(style, 200)
	}
}

fn test_resolved_edges_follow_animation_changes_and_copy_on_write_styles() {
	mut style := edge_resolution_style()
	base := parse_css_value(ParsingParams{}, '11px', .padding_left)?
	style.set_property(.padding_left, base, .no, .no)
	_ = resolve_computed_values(style)
	style.share_computed_layout_cache()
	copied := &ComputedProperties{ ...style }
	animated := parse_css_value(ParsingParams{}, '25%', .padding_left)?
	style.set_animated_property(.padding_left, animated, .no, .no)
	assert_resolved_edges_match_property_resolution(style, 200)
	assert resolve_computed_values(style).resolved_box_model_edges(200).padding_left.to_double() == 50
	assert resolve_computed_values(copied).resolved_box_model_edges(200).padding_left.to_double() == 11
	style.remove_animated_property(.padding_left)
	assert_resolved_edges_match_property_resolution(style, 200)
	assert resolve_computed_values(style).resolved_box_model_edges(200).padding_left.to_double() == 11
}

fn test_resolved_edges_keep_both_document_rounding_policies() {
	mut document := dom.Document.create(dom.url_about_blank())
	defer { document.finalize() }
	element := document.create_element('div')!
	mut style := edge_resolution_style()
	style.subject_element_ = element
	for chromium in [false, true] {
		if chromium { document.set_font_rendering_policy(.chromium) }
		for text in ['0.0078125px', '1.0078125px', '2.54cm', 'calc(1px + 12.5%)'] {
			value := parse_css_value(ParsingParams{}, text, .margin_left)?
			style.set_property(.margin_left, value, .no, .no)
			assert_resolved_edges_match_property_resolution(style, 123.0078125)
		}
	}
}

fn test_resolved_edge_reuse_keys_quantized_percentages_and_live_rounding_policy() {
	mut document := dom.Document.create(dom.url_about_blank())
	defer { document.finalize() }
	element := document.create_element('div')!
	mut style := edge_resolution_style()
	style.subject_element_ = element
	for property, text in {
		PropertyID.padding_left: '1.0078125px'
		.padding_right:          '33.333333%'
		.margin_top:             '-0.0078125px'
		.margin_bottom:          'auto'
	} {
		value := parse_css_value(ParsingParams{}, text, property)?
		style.set_property(property, value, .no, .no)
	}
	values := resolve_computed_values(style)
	for policy in [dom.FontRenderingPolicy.libweb, .chromium, .libweb] {
		document.set_font_rendering_policy(policy)
		for basis in [f64(0), 0.0078125, 100.0078125, 100.125, -33.125, 100000000] {
			assert values.resolved_box_model_edges(basis) == values.uncached_resolved_box_model_edges(basis)
			assert values.resolved_box_model_edges(basis) == values.uncached_resolved_box_model_edges(basis)
		}
	}
	if !disable_resolved_edge_reuse {
		assert style.computed_layout_cache().resolved_edge_memo_.valid
		assert style.computed_layout_cache().resolved_edge_memo_.kind == .percentage_edges
	}
}

fn test_resolved_edge_reuse_invalidates_typed_setters_and_keeps_shared_styles_independent() {
	mut style := edge_resolution_style()
	values := resolve_computed_values(style)
	original := values.resolved_box_model_edges(200)
	style.share_computed_layout_cache()
	copy := &ComputedProperties{ ...style }
	copied_values := unsafe { &ComputedValues(copy) }
	mut mutable := unsafe { &MutableComputedValues(style) }
	padding := LengthBox.with_values(LengthPercentageOrAuto.from_length(Length.make_px(3)), LengthPercentageOrAuto.from_percentage(Percentage.new(25)), LengthPercentageOrAuto.make_auto(), LengthPercentageOrAuto.from_length(Length.make_px(7)))
	mutable.set_padding(padding)
	assert values.resolved_box_model_edges(200) == values.uncached_resolved_box_model_edges(200)
	assert values.resolved_box_model_edges(200).padding_left == CSSPixels.new(7)
	assert copied_values.resolved_box_model_edges(200) == original
	mutable.set_margin(padding)
	assert values.resolved_box_model_edges(400).margin_right == CSSPixels.new(100)
	assert values.resolved_box_model_edges(400) == values.uncached_resolved_box_model_edges(400)
	for side in 0 .. 4 {
		_ = values.resolved_box_model_edges(400)
		border := BorderData{ width: CSSPixels.new(side + 2) }
		match side {
			0 { mutable.set_border_left(border) }
			1 { mutable.set_border_top(border) }
			2 { mutable.set_border_right(border) }
			else { mutable.set_border_bottom(border) }
		}
		assert values.resolved_box_model_edges(400) == values.uncached_resolved_box_model_edges(400)
	}
	assert copied_values.resolved_box_model_edges(200) == original
}

fn test_resolved_edge_reuse_keeps_relative_units_live_and_ignores_memos_when_sharing_geometry() {
	mut style := edge_resolution_style()
	for text in ['2em', '2rem', '2lh', '2rlh', '10vw', '10vh', '10cqi', 'calc(2px + 25%)'] {
		value := parse_css_value(ParsingParams{}, text, .padding_left)?
		style.set_property(.padding_left, value, .no, .no)
		values := resolve_computed_values(style)
		_ = values.resolved_box_model_edges(200)
		if !disable_resolved_edge_reuse {
			assert style.computed_layout_cache().resolved_edge_memo_.kind == .live_context
		}
		style.root_font_size_px_ += 7
		style.root_line_height_px_ += 9
		style.viewport_rect_ = CSSPixelRect.new(0, 0, 333, 222)
		assert values.resolved_box_model_edges(200) == values.uncached_resolved_box_model_edges(200)
		assert_resolved_edges_match_property_resolution(style, 200)
	}
	first := edge_resolution_style()
	second := edge_resolution_style()
	_ = resolve_computed_values(first).resolved_box_model_edges(200)
	_ = resolve_computed_values(second).resolved_box_model_edges(400)
	assert idle_layout_snapshots_equal(first.computed_layout_cache(), second.computed_layout_cache())
	assert share_idle_layout_snapshots([first, second]) == 1
	a := unsafe { &ComputedValues(first) }
	b := unsafe { &ComputedValues(second) }
	assert a.resolved_box_model_edges(800) == b.uncached_resolved_box_model_edges(800)
}
