module css

import dom

// Runtime smoke test of the ported CSS value parser. Validates that parsing +
// shorthand expansion + serialization work end to end now that the module
// compiles and runs natively. Guards against the first-token-drop regression
// (a failed CSS-wide-keyword probe used to swallow the value's first token).
fn parsed(text string, property PropertyID) ?string {
	value := parse_css_value(ParsingParams{}, text, property) or { return none }
	return value.css_text
}

fn test_longhands() {
	assert parsed('42px', PropertyID.width)? == '42px'
	assert parsed('red', PropertyID.color)? == 'red'
	assert parsed('block', PropertyID.display)? == 'block'
	assert parsed('0.5', PropertyID.opacity)? == '0.5'
}

fn test_box_shorthands_expand_all_four_edges() {
	// margin/padding are positional-value-list shorthands: they expand to four longhands
	// and serialize with the CSS 4->2->1 shortest-form collapse (upstream
	// serialize_a_positional_value_list).
	assert parsed('1px 2px', PropertyID.margin)? == '1px 2px'
	assert parsed('5px', PropertyID.margin)? == '5px'
	assert parsed('1px 2px 3px 4px', PropertyID.padding)? == '1px 2px 3px 4px'
	assert parsed('1px 2px 1px 2px', PropertyID.margin)? == '1px 2px'
}

fn test_border_radius_shorthand_reuses_the_radius_rect_parser() {
	value := parse_css_value_logic(.border_radius, '1px 2px 3px 4px / 5px 6px') or {
		panic('border-radius did not parse')
	}
	assert value is ShorthandStyleValue
	radius := value as ShorthandStyleValue
	assert radius.longhand(.border_top_left_radius)?.serialize(.normal) == '1px 5px'
	assert radius.longhand(.border_top_right_radius)?.serialize(.normal) == '2px 6px'
	assert radius.longhand(.border_bottom_right_radius)?.serialize(.normal) == '3px 5px'
	assert radius.longhand(.border_bottom_left_radius)?.serialize(.normal) == '4px 6px'
	assert parsed('-1px', .border_radius) == none
}

fn test_border_shorthand_retains_nested_shorthands_and_true_initials() {
	value := parse_css_value_logic(.border, '2px dashed red') or { panic('border did not parse') }
	assert value is ShorthandStyleValue
	border := value as ShorthandStyleValue
	width_value := border.longhand(.border_width) or { panic('missing border-width') }
	assert width_value is ShorthandStyleValue
	width := width_value as ShorthandStyleValue
	assert width.longhand(.border_top_width)?.serialize(.normal) == '2px'
	assert width.longhand(.border_left_width)?.serialize(.normal) == '2px'

	image_value := border.longhand(.border_image) or { panic('missing border-image reset') }
	assert image_value is ShorthandStyleValue
	image := image_value as ShorthandStyleValue
	assert image.longhand(.border_image_source)?.serialize(.normal) == 'none'
	assert image.longhand(.border_image_slice)?.serialize(.normal) == '100%'
	assert value.serialize(.normal) == '2px dashed red'

	block_value := parse_css_value_logic(.border_block, 'solid blue') or {
		panic('border-block did not parse')
	}
	assert block_value is ShorthandStyleValue
	block := block_value as ShorthandStyleValue
	block_style := block.longhand(.border_block_style) or { panic('missing border-block-style') }
	assert block_style is ShorthandStyleValue
	assert block.serialize(.normal) == 'solid blue'
}

fn test_border_image_slash_portions_match_upstream() {
	value := parse_css_value_logic(.border_image, 'url(frame.png) 30 / 10 / 2 round stretch') or {
		panic('border-image did not parse')
	}
	assert value is ShorthandStyleValue
	border_image := value as ShorthandStyleValue
	assert border_image.longhand(.border_image_source)?.serialize(.normal) == 'url("frame.png")'
	assert border_image.longhand(.border_image_slice)?.serialize(.normal) == '30'
	assert border_image.longhand(.border_image_width)?.serialize(.normal) == '10'
	assert border_image.longhand(.border_image_outset)?.serialize(.normal) == '2'
	assert border_image.longhand(.border_image_repeat)?.serialize(.normal) == 'round stretch'

	omitted_width := parse_css_value_logic(.border_image, '30 / / 2') or {
		panic('border-image with omitted width did not parse')
	}
	assert omitted_width is ShorthandStyleValue
	omitted := omitted_width as ShorthandStyleValue
	assert omitted.longhand(.border_image_width)?.serialize(.normal) == '1'
	assert omitted.longhand(.border_image_outset)?.serialize(.normal) == '2'
	assert parsed('30 / repeat', .border_image) == none
}

fn test_shorthands_first_token_not_dropped() {
	// Single-token values must not be swallowed by the CSS-wide-keyword probe.
	// (overflow-x == overflow-y == auto serializes as a single `auto`.)
	assert parsed('auto', PropertyID.overflow)? == 'auto'
	assert parsed('none', PropertyID.grid_template)?.len > 0
	assert parsed('1px', PropertyID.border)?.len > 0
	assert parsed('solid', PropertyID.border)?.len > 0
}

fn test_multi_component_shorthands() {
	// `||` shorthands where keyword components are followed by more tokens: a
	// component parser must not reject trailing tokens (regression).
	assert parsed('1px solid red', PropertyID.border)?.len > 0
	assert parsed('2px dashed blue', PropertyID.border_top)? == '2px dashed blue'
	assert parsed('thick solid green', PropertyID.outline)?.len > 0
	assert parsed('square inside', PropertyID.list_style)?.len > 0
	assert parsed('underline dotted red', PropertyID.text_decoration)?.len > 0
}

fn test_list_style_none_fills_only_the_missing_image_or_type() {
	value := parse_css_value_logic(.list_style, 'inside none square') or {
		panic('list-style did not parse')
	}
	assert value is ShorthandStyleValue
	list_style := value as ShorthandStyleValue
	assert list_style.longhand(.list_style_position)?.serialize(.normal) == 'inside'
	assert list_style.longhand(.list_style_image)?.serialize(.normal) == 'none'
	assert list_style.longhand(.list_style_type)?.serialize(.normal) == 'square'

	assert parsed('none square url(marker.svg)', .list_style) == none
}

fn test_text_decoration_reparses_the_full_line_component() {
	value := parse_css_value_logic(.text_decoration, 'overline underline dotted red 2px') or {
		panic('multi-line text-decoration did not parse')
	}
	assert value is ShorthandStyleValue
	decoration := value as ShorthandStyleValue
	assert decoration.longhand(.text_decoration_line)?.serialize(.normal) == 'underline overline'
	assert decoration.longhand(.text_decoration_style)?.serialize(.normal) == 'dotted'
	assert decoration.longhand(.text_decoration_color)?.serialize(.normal) == 'red'
	assert decoration.longhand(.text_decoration_thickness)?.serialize(.normal) == '2px'

	// spelling-error and grammar-error may only appear on their own.
	assert parsed('spelling-error underline', .text_decoration) == none
}

fn test_columns_shorthand_includes_column_height() {
	value := parse_css_value_logic(.columns, '12em / 30em') or {
		panic('columns with column-height did not parse')
	}
	assert value is ShorthandStyleValue
	shorthand := value as ShorthandStyleValue
	width := shorthand.longhand(.column_width) or { panic('missing column-width') }
	height := shorthand.longhand(.column_height) or { panic('missing column-height') }
	count := shorthand.longhand(.column_count) or { panic('missing column-count') }
	assert width.serialize(.normal) == '12em'
	assert height.serialize(.normal) == '30em'
	assert count.has_auto()
	assert parsed('/ 30em', .columns) == none
}

fn test_color_functions() {
	// Low-level numeric parsers must not consume-on-failure: bare-number hue and
	// percentage channels must parse (regression).
	assert parsed('hsl(120, 50%, 50%)', PropertyID.color)?.len > 0
	assert parsed('hsl(120 50% 50%)', PropertyID.color)?.len > 0
	assert parsed('rgb(50%, 50%, 50%)', PropertyID.color)?.len > 0
	assert parsed('rgb(1, 2, 3)', PropertyID.color)?.len > 0
}

fn test_quirky_colors_follow_generated_property_and_context_metadata() {
	// These legacy hashless forms are accepted only in quirks mode, only by
	// properties carrying Ladybird's HashlessHexColor quirk, and never inside a
	// child function context.
	assert parsed('abc', .color) == none

	mut document := dom.Document.create_for_fragment_parsing()
	document.set_quirks_mode(.yes)
	mut ident_parser := Parser.with_context(ParsingParams{
		document: document
	}, 'abc')
	ident_color := ident_parser.parse_css_value(.color) or {
		panic('quirky hashless identifier color did not parse')
	}
	assert ident_color is RGBColorStyleValue
	resolved_ident := (ident_color as RGBColorStyleValue).to_color(ColorResolutionContext{}) or {
		panic('quirky identifier color did not resolve')
	}
	assert resolved_ident.red() == 0xaa
	assert resolved_ident.green() == 0xbb
	assert resolved_ident.blue() == 0xcc

	mut number_parser := Parser.with_context(ParsingParams{
		document: document
	}, '123')
	number_color := number_parser.parse_css_value(.color) or {
		panic('quirky numeric color did not parse')
	}
	assert number_color is RGBColorStyleValue
	resolved_number := (number_color as RGBColorStyleValue).to_color(ColorResolutionContext{}) or {
		panic('quirky numeric color did not resolve')
	}
	assert resolved_number.red() == 0
	assert resolved_number.green() == 1
	assert resolved_number.blue() == 0x23

	mut unlisted_property_parser := Parser.with_context(ParsingParams{
		document: document
	}, 'abc')
	assert unlisted_property_parser.parse_css_value(.fill) == none

	mut nested_parser := Parser.with_context(ParsingParams{
		document: document
	}, 'color-mix(in srgb, abc 50%, red)')
	assert nested_parser.parse_css_value(.color) == none
}

fn test_background_layers() {
	// Image + repeat + position + size in a single layer (regression: the image
	// and repeat component parsers used to reject/require trailing tokens).
	assert parsed('url(a.png) no-repeat center / cover', PropertyID.background)?.len > 0
	assert parsed('url(a.png) center', PropertyID.background)?.len > 0
	assert parsed('no-repeat center', PropertyID.background)?.len > 0
	assert parsed('url(m.png) alpha', PropertyID.mask)?.len > 0
}

fn test_background_retains_the_nested_position_shorthand() {
	value := parse_css_value_logic(.background, 'url(first.png) left top / 10px 20px no-repeat padding-box content-box, red') or {
		panic('layered background did not parse')
	}
	assert value is ShorthandStyleValue
	background := value as ShorthandStyleValue
	position_value := background.longhand(.background_position) or {
		panic('missing background-position')
	}
	assert position_value is ShorthandStyleValue
	position := position_value as ShorthandStyleValue
	assert position.longhand(.background_position_x)?.serialize(.normal) == 'left, 0%'
	assert position.longhand(.background_position_y)?.serialize(.normal) == 'top, 0%'
	assert background.longhand(.background_size)?.serialize(.normal) == '10px 20px, auto'
	assert background.longhand(.background_origin)?.serialize(.normal) == 'padding-box, padding-box'
	assert background.longhand(.background_clip)?.serialize(.normal) == 'content-box, border-box'

	// background-color may only occur in the final layer.
	assert parsed('red, url(second.png)', .background) == none
}

fn test_mask_layers_and_geometry_defaults_match_upstream() {
	value := parse_css_value_logic(.mask, 'url(mask.png) left top / 10px 20px no-repeat padding-box no-clip add alpha') or {
		panic('single-layer mask did not parse')
	}
	assert value is ShorthandStyleValue
	mask := value as ShorthandStyleValue
	image := mask.longhand(.mask_image) or { panic('missing mask-image') }
	position := mask.longhand(.mask_position) or { panic('missing mask-position') }
	size := mask.longhand(.mask_size) or { panic('missing mask-size') }
	origin := mask.longhand(.mask_origin) or { panic('missing mask-origin') }
	clip := mask.longhand(.mask_clip) or { panic('missing mask-clip') }
	assert image !is StyleValueList
	assert position !is StyleValueList
	assert size.serialize(.normal) == '10px 20px'
	assert origin.serialize(.normal) == 'padding-box'
	assert clip.serialize(.normal) == 'no-clip'
	assert mask.longhand(.mask_repeat)?.serialize(.normal) == 'no-repeat'
	assert mask.longhand(.mask_composite)?.serialize(.normal) == 'add'
	assert mask.longhand(.mask_mode)?.serialize(.normal) == 'alpha'

	shared_box_value := parse_css_value_logic(.mask, 'padding-box') or {
		panic('mask geometry box did not parse')
	}
	assert shared_box_value is ShorthandStyleValue
	shared_box := shared_box_value as ShorthandStyleValue
	assert shared_box.longhand(.mask_origin)?.serialize(.normal) == 'padding-box'
	assert shared_box.longhand(.mask_clip)?.serialize(.normal) == 'padding-box'

	multi_value := parse_css_value_logic(.mask, 'url(first.png), url(second.png)') or {
		panic('multi-layer mask did not parse')
	}
	assert multi_value is ShorthandStyleValue
	multi := multi_value as ShorthandStyleValue
	multi_images := multi.longhand(.mask_image) or { panic('missing layered mask-image') }
	assert multi_images is StyleValueList
	assert (multi_images as StyleValueList).values().len == 2
	assert parsed('url(mask.png),', .mask) == none
}

fn test_font_shorthand_retains_font_variant_and_css2_width_rules() {
	value := parse_css_value_logic(.font, 'italic small-caps 700 condensed 16px/1.5 "Port Test", serif') or {
		panic('font shorthand did not parse')
	}
	assert value is ShorthandStyleValue
	font := value as ShorthandStyleValue
	assert font.sub_properties().len == 12
	assert font.longhand(.font_style)?.serialize(.normal) == 'italic'
	assert font.longhand(.font_weight)?.serialize(.normal) == '700'
	assert font.longhand(.font_width)?.serialize(.normal) == 'condensed'
	assert font.longhand(.font_size)?.serialize(.normal) == '16px'
	assert font.longhand(.line_height)?.serialize(.normal) == '1.5'

	variant_value := font.longhand(.font_variant) or { panic('missing nested font-variant') }
	assert variant_value is ShorthandStyleValue
	variant := variant_value as ShorthandStyleValue
	assert variant.longhand(.font_variant_caps)?.serialize(.normal) == 'small-caps'
	assert variant.longhand(.font_variant_numeric)?.serialize(.normal) == 'normal'
	assert value.serialize(.normal) == 'italic small-caps 700 condensed 16px / 1.5 "Port Test", serif'

	// font-width accepts percentages as a longhand, but <font-width-css3> in
	// this shorthand is deliberately restricted to its keyword grammar.
	assert parsed('75% 16px serif', .font) == none
}

fn test_font_variant_category_parser_matches_upstream() {
	value := parse_css_value_logic(.font_variant, 'historical-forms small-caps oldstyle-nums ruby sub emoji') or {
		panic('multi-category font-variant did not parse')
	}
	assert value is ShorthandStyleValue
	variant := value as ShorthandStyleValue
	assert variant.longhand(.font_variant_alternates)?.serialize(.normal) == 'historical-forms'
	assert variant.longhand(.font_variant_caps)?.serialize(.normal) == 'small-caps'
	assert variant.longhand(.font_variant_east_asian)?.serialize(.normal) == 'ruby'
	assert variant.longhand(.font_variant_emoji)?.serialize(.normal) == 'emoji'
	assert variant.longhand(.font_variant_ligatures)?.serialize(.normal) == 'normal'
	assert variant.longhand(.font_variant_numeric)?.serialize(.normal) == 'oldstyle-nums'
	assert variant.longhand(.font_variant_position)?.serialize(.normal) == 'sub'

	none_value := parse_css_value_logic(.font_variant, 'none') or {
		panic('font-variant none did not parse')
	}
	assert none_value is ShorthandStyleValue
	none_variant := none_value as ShorthandStyleValue
	assert none_variant.longhand(.font_variant_ligatures)?.serialize(.normal) == 'none'
	assert none_variant.longhand(.font_variant_caps)?.serialize(.normal) == 'normal'
	assert parsed('normal small-caps', .font_variant) == none
	assert parsed('none small-caps', .font_variant) == none
}

fn test_grid_placement_shorthands_apply_upstream_omission_rules() {
	row_value := parse_css_value_logic(.grid_row, 'content') or { panic('grid-row did not parse') }
	assert row_value is ShorthandStyleValue
	row := row_value as ShorthandStyleValue
	assert row.longhand(.grid_row_start)?.serialize(.normal) == 'content'
	assert row.longhand(.grid_row_end)?.serialize(.normal) == 'content'

	column_value := parse_css_value_logic(.grid_column, '2') or {
		panic('grid-column did not parse')
	}
	assert column_value is ShorthandStyleValue
	column := column_value as ShorthandStyleValue
	assert column.longhand(.grid_column_start)?.serialize(.normal) == '2'
	assert column.longhand(.grid_column_end)?.serialize(.normal) == 'auto'
	assert parsed('2 /', .grid_column) == none

	area_value := parse_css_value_logic(.grid_area, 'card') or { panic('grid-area did not parse') }
	assert area_value is ShorthandStyleValue
	area := area_value as ShorthandStyleValue
	assert area.longhand(.grid_row_start)?.serialize(.normal) == 'card'
	assert area.longhand(.grid_column_start)?.serialize(.normal) == 'card'
	assert area.longhand(.grid_row_end)?.serialize(.normal) == 'card'
	assert area.longhand(.grid_column_end)?.serialize(.normal) == 'card'
}

fn test_grid_template_and_auto_flow_branches_retain_upstream_longhands() {
	template_value := parse_css_value_logic(.grid_template, '"hero hero" "nav main" / 1fr 2fr') or {
		panic('area-form grid-template did not parse')
	}
	assert template_value is ShorthandStyleValue
	template := template_value as ShorthandStyleValue
	assert template.longhand(.grid_template_areas)?.serialize(.normal) == '"hero hero" "nav main"'
	assert template.longhand(.grid_template_rows)?.serialize(.normal) == 'auto auto'
	assert template.longhand(.grid_template_columns)?.serialize(.normal) == '1fr 2fr'

	row_flow_value := parse_css_value_logic(.grid, 'auto-flow dense 40px / 1fr 2fr') or {
		panic('row auto-flow grid did not parse')
	}
	assert row_flow_value is ShorthandStyleValue
	row_flow := row_flow_value as ShorthandStyleValue
	assert row_flow.longhand(.grid_auto_flow)?.serialize(.normal) == 'dense'
	assert row_flow.longhand(.grid_auto_rows)?.serialize(.normal) == '40px'
	assert row_flow.longhand(.grid_template_columns)?.serialize(.normal) == '1fr 2fr'

	column_flow_value := parse_css_value_logic(.grid, '100px / dense auto-flow 20px') or {
		panic('column auto-flow grid did not parse')
	}
	assert column_flow_value is ShorthandStyleValue
	column_flow := column_flow_value as ShorthandStyleValue
	assert column_flow.longhand(.grid_auto_flow)?.serialize(.normal) == 'column dense'
	assert column_flow.longhand(.grid_auto_columns)?.serialize(.normal) == '20px'
	assert column_flow.longhand(.grid_template_rows)?.serialize(.normal) == '100px'
}

fn test_subgrid_track_list_parsing_and_serialization() {
	assert parsed('subgrid', .grid_template_columns)? == 'subgrid'
	assert parsed('subgrid [a] [b]', .grid_template_columns)? == 'subgrid [a] [b]'
	assert parsed('subgrid repeat(2, [a] [b]) [c]', .grid_template_columns)? ==
		'subgrid repeat(2, [a] [b]) [c]'
	assert parsed('subgrid [a] repeat(auto-fill, [b]) [c]', .grid_template_columns)? ==
		'subgrid [a] repeat(auto-fill, [b]) [c]'
	assert parsed('subgrid 10px', .grid_template_columns) == none
	assert parsed('subgrid repeat(auto-fit, [a])', .grid_template_columns) == none
	assert parsed('subgrid repeat(auto-fill, [a]) repeat(auto-fill, [b])',
		.grid_template_columns) == none
}

fn test_resolved_subgrid_track_list_keeps_local_line_name_sets() {
	resolved := cssom_resolved_grid_template([40.0, 50.0], [['a'], ['b'], ['c']], true) or {
		panic('subgrid resolved value was not created')
	}
	assert resolved.css_text == 'subgrid [a] [b] [c]'
}

fn test_coordinated_list_shorthands() {
	// animation/transition components include keyword easings (linear/ease/...);
	// the easing must bind to timing-function, not fall through to name.
	anim := parsed('spin 2s linear', PropertyID.animation)?
	assert anim.contains('linear') && anim.contains('spin')
	trans := parsed('color 1s ease-in 2s', PropertyID.transition)?
	assert trans.contains('ease-in')
}

fn test_coordinated_list_shorthands_use_property_metadata() {
	// The first <time> is the duration. Ladybird does not reinterpret a
	// negative duration as the delay when the duration range check fails.
	assert parsed('opacity -1s', .transition) == none
	assert parsed('spin -1s', .animation) == none

	// animation-timeline is reset-only in the animation shorthand. A timeline
	// function therefore cannot be consumed as an animation component.
	assert parsed('scroll()', .animation) == none

	// Coordinating longhands use the same per-item metadata path. This keeps
	// keywords, commas, and numeric ranges aligned without splitting/reparsing.
	assert parsed('auto, 2s', .animation_duration)? == 'auto, 2s'
	assert parsed('2, infinite', .animation_iteration_count)? == '2, infinite'
	assert parsed('-1s, 2s', .animation_delay)? == '-1s, 2s'
	assert parsed('-1s, 2s', .transition_duration) == none
}

fn test_flex_shorthands_follow_property_metadata_and_upstream_defaults() {
	zero_value := parse_css_value_logic(.flex, '0') or { panic('flex: 0 did not parse') }
	assert zero_value is ShorthandStyleValue
	zero := zero_value as ShorthandStyleValue
	assert zero.longhand(.flex_grow)?.serialize(.normal) == '0'
	assert zero.longhand(.flex_shrink)?.serialize(.normal) == '1'
	assert zero.longhand(.flex_basis)?.serialize(.normal) == '0%'

	basis_value := parse_css_value_logic(.flex, '10px') or { panic('flex: 10px did not parse') }
	assert basis_value is ShorthandStyleValue
	basis := basis_value as ShorthandStyleValue
	assert basis.longhand(.flex_grow)?.serialize(.normal) == '1'
	assert basis.longhand(.flex_shrink)?.serialize(.normal) == '1'
	assert basis.longhand(.flex_basis)?.serialize(.normal) == '10px'

	none_value := parse_css_value_logic(.flex, 'none') or { panic('flex: none did not parse') }
	assert none_value is ShorthandStyleValue
	none_ := none_value as ShorthandStyleValue
	assert none_.longhand(.flex_grow)?.serialize(.normal) == '0'
	assert none_.longhand(.flex_shrink)?.serialize(.normal) == '0'
	assert none_.longhand(.flex_basis)?.has_auto()

	flow_value := parse_css_value_logic(.flex_flow, 'wrap column') or {
		panic('flex-flow: wrap column did not parse')
	}
	assert flow_value is ShorthandStyleValue
	flow := flow_value as ShorthandStyleValue
	assert flow.longhand(.flex_direction)?.serialize(.normal) == 'column'
	assert flow.longhand(.flex_wrap)?.serialize(.normal) == 'wrap'
}

fn test_timeline_shorthands_require_the_upstream_component_order() {
	scroll_value := parse_css_value_logic(.scroll_timeline, '--first, --second inline') or {
		panic('scroll-timeline did not parse')
	}
	assert scroll_value is ShorthandStyleValue
	scroll := scroll_value as ShorthandStyleValue
	assert scroll.longhand(.scroll_timeline_name)?.serialize(.normal) == '--first, --second'
	assert scroll.longhand(.scroll_timeline_axis)?.serialize(.normal) == 'block, inline'
	assert parsed('inline --first', .scroll_timeline) == none

	view_value := parse_css_value_logic(.view_timeline, '--first 10% inline, --second') or {
		panic('view-timeline did not parse')
	}
	assert view_value is ShorthandStyleValue
	view := view_value as ShorthandStyleValue
	assert view.longhand(.view_timeline_name)?.serialize(.normal) == '--first, --second'
	assert view.longhand(.view_timeline_axis)?.serialize(.normal) == 'inline, block'
	assert view.longhand(.view_timeline_inset)?.serialize(.normal) == '10%, auto'
	assert parsed('inline --first', .view_timeline) == none
	assert parsed('--first inline block', .view_timeline) == none
}

fn test_place_shorthands_use_their_distinct_longhand_grammars() {
	items_value := parse_css_value_logic(.place_items, 'normal legacy') or {
		panic('place-items did not parse')
	}
	assert items_value is ShorthandStyleValue
	items := items_value as ShorthandStyleValue
	assert items.longhand(.align_items)?.serialize(.normal) == 'normal'
	assert items.longhand(.justify_items)?.serialize(.normal) == 'legacy'
	assert parsed('legacy normal', .place_items) == none

	content_value := parse_css_value_logic(.place_content, 'center left') or {
		panic('place-content did not parse')
	}
	assert content_value is ShorthandStyleValue
	content := content_value as ShorthandStyleValue
	assert content.longhand(.align_content)?.serialize(.normal) == 'center'
	assert content.longhand(.justify_content)?.serialize(.normal) == 'left'

	self_value := parse_css_value_logic(.place_self, 'stretch right') or {
		panic('place-self did not parse')
	}
	assert self_value is ShorthandStyleValue
	self := self_value as ShorthandStyleValue
	assert self.longhand(.align_self)?.serialize(.normal) == 'stretch'
	assert self.longhand(.justify_self)?.serialize(.normal) == 'right'
}

fn test_css_wide_keyword() {
	assert parsed('inherit', PropertyID.width)? == 'inherit'
}

fn test_invalid_returns_none() {
	assert parsed('not-a-length', PropertyID.width) == none
	assert parsed('12px', PropertyID.color) == none
}

fn test_numeric_dimension_parsing_matches_upstream_modes_and_ranges() {
	// Unitless zero is only a <length>, not a general substitute for every
	// dimension type. SVG presentation attributes are the upstream exception
	// for unitless angles and non-zero lengths.
	assert parsed('0', .rotate) == none
	assert parsed_type('0', .time) == none
	assert parsed_type('0s', .time)?.serialize(.normal) == '0s'

	// CSS Values requires non-negative resolutions at parse time.
	assert parsed_type('-1dppx', .resolution) == none
	assert parsed_type('1dppx', .resolution)?.serialize(.normal) == '1dppx'

	mut normal_length_parser := Parser.with_context(ParsingParams{}, '12')
	assert normal_length_parser.parse_css_value(.width) == none

	mut svg_length_parser := Parser.with_context(ParsingParams{
		mode: .svg_presentation_attribute
	}, '12')
	svg_length := svg_length_parser.parse_css_value(.width) or {
		panic('unitless SVG presentation-attribute length did not parse')
	}
	assert svg_length is LengthStyleValue
	assert svg_length.serialize(.normal) == '12px'

	mut svg_angle_parser := Parser.with_context(ParsingParams{
		mode: .svg_presentation_attribute
	}, '45')
	svg_angle := svg_angle_parser.parse_as_type(.angle) or {
		panic('unitless SVG presentation-attribute angle did not parse')
	}
	assert svg_angle is AngleStyleValue
	assert svg_angle.serialize(.normal) == '45deg'

	mut quirks_document := dom.Document.create_for_fragment_parsing()
	quirks_document.set_quirks_mode(.yes)
	mut quirky_length_parser := Parser.with_context(ParsingParams{
		document: quirks_document
	}, '12')
	quirky_length := quirky_length_parser.parse_css_value(.width) or {
		panic('generated unitless-length quirk was not applied')
	}
	assert quirky_length is LengthStyleValue
	assert quirky_length.serialize(.normal) == '12px'

	// LibWeb tracks every nested value grammar. Functional notation normally
	// disables quirky lengths, with the CSS2 clip/rect() exception.
	mut nested_length_parser := Parser.with_context(ParsingParams{
		document: quirks_document
	}, 'fit-content(12)')
	assert nested_length_parser.parse_css_value(.width) == none
	assert nested_length_parser.value_context.len == 0

	mut anchor_fallback_parser := Parser.with_context(ParsingParams{
		document: quirks_document
	}, 'anchor(top, 12)')
	assert anchor_fallback_parser.parse_css_value(.top) == none

	mut rect_parser := Parser.with_context(ParsingParams{
		document: quirks_document
	}, 'rect(1 2 3 4)')
	rect := rect_parser.parse_css_value(.clip) or {
		panic('clip rect() did not preserve the quirky-length exception')
	}
	assert rect is RectStyleValue

	mut seeded_context_parser := Parser.with_context(ParsingParams{
		document: quirks_document
		value_context: [ValueParsingContext(PropertyID.background)]
	}, '12')
	assert seeded_context_parser.parse_css_value(.width) == none

	mut logical_alias_parser := Parser.with_context(ParsingParams{
		document: quirks_document
	}, '12')
	assert logical_alias_parser.parse_css_value(.inline_size) == none

	// A failed dimension-unit probe must leave the component-value stream at
	// its original position so another branch can parse the same token.
	mut invalid_frequency_parser := Parser.from_css_text('1px')
	mut frequency_tokens := ComponentValueStream.new(invalid_frequency_parser.component_values)
	start_index := frequency_tokens.index
	assert invalid_frequency_parser.parse_frequency_value(mut frequency_tokens) == none
	assert frequency_tokens.index == start_index
}

fn test_numeric_value_parsing_includes_upstream_tree_counting_functions() {
	z_index := parse_css_value_logic(.z_index, 'sibling-index()') or {
		panic('sibling-index() did not parse as an integer')
	}
	assert z_index is TreeCountingFunctionStyleValue
	assert (z_index as TreeCountingFunctionStyleValue).computed_type() == .integer
	assert z_index.serialize(.normal) == 'sibling-index()'

	count := parsed_type('sibling-count( )', .number) or {
		panic('sibling-count() did not parse as a number')
	}
	assert count is TreeCountingFunctionStyleValue
	assert (count as TreeCountingFunctionStyleValue).computed_type() == .number
	assert count.serialize(.normal) == 'sibling-count()'
	assert parsed_type('sibling-index(1)', .integer) == none

	calculated := parse_css_value_logic(.opacity, 'calc(sibling-index() / 2)') or {
		panic('tree-counting function did not parse as a non-math calculation leaf')
	}
	assert calculated is CalculatedStyleValue
	assert calculated.serialize(.normal).contains('sibling-index()')

	mut media_context_parser := Parser.with_context(ParsingParams{
		value_context: [ValueParsingContext(SpecialContext.media_condition)]
	}, 'calc(sibling-count())')
	assert media_context_parser.parse_as_type(.number) == none

	// Like TokenStream::next_token() in C++, invalid ordinary values are only
	// peeked. Alternate grammar branches must still see the same token.
	mut invalid_integer_parser := Parser.from_css_text('1.5')
	mut integer_tokens := ComponentValueStream.new(invalid_integer_parser.component_values)
	integer_start := integer_tokens.index
	assert invalid_integer_parser.parse_integer_value(mut integer_tokens) == none
	assert integer_tokens.index == integer_start

	mut invalid_keyword_parser := Parser.from_css_text('"not-an-ident"')
	mut keyword_tokens := ComponentValueStream.new(invalid_keyword_parser.component_values)
	keyword_start := keyword_tokens.index
	assert invalid_keyword_parser.parse_keyword_value(mut keyword_tokens) == none
	assert keyword_tokens.index == keyword_start
}

fn test_grid_track_placement_preserves_tree_counting_style_values() {
	line := parse_css_value_logic(.grid_row_start, 'sibling-count()') or {
		panic('tree-counting grid line did not parse')
	}
	assert line is GridTrackPlacementStyleValue
	line_placement := (line as GridTrackPlacementStyleValue).grid_track_placement()
	assert line_placement.line_number() is TreeCountingFunctionStyleValue
	assert line.serialize(.normal) == 'sibling-count()'

	span := parse_css_value_logic(.grid_row_start, 'span sibling-count()') or {
		panic('tree-counting grid span did not parse')
	}
	assert span is GridTrackPlacementStyleValue
	span_placement := (span as GridTrackPlacementStyleValue).grid_track_placement()
	assert span_placement.span() is TreeCountingFunctionStyleValue
	assert span.serialize(.normal) == 'span sibling-count()'
}

fn test_dom_style_value_retains_typed_css_value() {
	value := parse_css_value(ParsingParams{}, '42px', .width) or {
		panic('width did not parse')
	}
	assert value.css_value_handle != unsafe { nil }
	typed := typed_style_value_logic_from_dom(value) or {
		panic('typed value handle was not retained')
	}
	assert typed is LengthStyleValue
	assert typed.serialize(.normal) == '42px'

	// DOM callers may still construct a serialized-only value. Keep the
	// compatibility parser at that boundary while typed parser output takes the
	// allocation-free path above.
	serialized_only := &dom.StyleValue{
		css_text: '17px'
	}
	assert typed_style_value_logic_from_dom(serialized_only) == none
	fallback := style_value_logic_from_dom(.width, serialized_only) or {
		panic('serialized fallback did not parse')
	}
	assert fallback is LengthStyleValue
	assert fallback.serialize(.normal) == '17px'
}

fn test_initial_values_are_typed_and_cached() {
	first := computed_interpolation_property_initial_value(.width)
	second := computed_interpolation_property_initial_value(.width)
	assert voidptr(first) == voidptr(second)
	assert first.css_value_handle != unsafe { nil }
	assert typed_style_value_logic_from_dom(first) != none
}

fn test_generated_keyword_table_matches_upstream_surface() {
	assert keyword_from_string('fit-content')? == .fit_content
	assert keyword_from_string('max-content')? == .max_content
	assert keyword_from_string('most-inline-size')? == .most_inline_size
	assert keyword_from_string('scroll-position')? == .scroll_position
	assert keyword_from_string('span-self-x-start')? == .span_self_x_start
	assert string_from_keyword(.xyz_d65) == 'xyz-d65'
}

fn test_anchor_and_fit_content_values_are_typed() {
	fit_content := parse_css_value_logic(.width, 'fit-content(25%)')?
	assert fit_content is FunctionStyleValue
	assert (fit_content as FunctionStyleValue).name() == 'fit-content'
	assert fit_content.serialize(.normal) == 'fit-content(25%)'

	anchor := parse_css_value_logic(.top, 'anchor(--card bottom, 10px)')?
	assert anchor is AnchorStyleValue
	anchor_value := anchor as AnchorStyleValue
	assert (anchor_value.anchor_name() or { '' }) == '--card'
	assert anchor_value.anchor_side().to_keyword() == .bottom
	assert (anchor_value.fallback_value() or { panic('missing anchor fallback') }).serialize(.normal) == '10px'
	assert anchor_value.serialize(.normal) == 'anchor(--card bottom, 10px)'

	anchor_size := parse_css_value_logic(.width, 'anchor-size(--card inline, 20%)')?
	assert anchor_size is AnchorSizeStyleValue
	anchor_size_value := anchor_size as AnchorSizeStyleValue
	assert (anchor_size_value.anchor_name() or { '' }) == '--card'
	assert (anchor_size_value.anchor_size() or { panic('missing anchor size') }) == .inline_
	assert (anchor_size_value.fallback_value() or { panic('missing anchor-size fallback') }).serialize(.normal) == '20%'
	assert anchor_size_value.serialize(.normal) == 'anchor-size(--card inline, 20%)'

	assert parse_css_value_logic(.color, 'anchor-size(width)') == none
}

fn test_position_anchor_accepts_current_keywords_and_uses_normal_initial_value() {
	for keyword in ['normal', 'none', 'auto'] {
		value := parse_css_value_logic(.position_anchor, keyword) or {
			panic('position-anchor rejected ${keyword}')
		}
		assert value.serialize(.normal) == keyword
	}
	assert parse_css_value_logic(.position_anchor, '--card')?.serialize(.normal) == '--card'
	assert parse_css_value_logic(.position_anchor, 'card') == none
	assert property_initial_value_string(.position_anchor) == 'normal'
	assert property_accepts_keyword(.position_anchor, .normal)
	assert property_accepts_keyword(.position_anchor, .none_)
	assert property_accepts_keyword(.position_anchor, .auto)
}

fn parsed_type(text string, value_type ValueType) ?StyleValue {
	mut parser := Parser.with_context(ParsingParams{}, text)
	return parser.parse_as_type(value_type)
}

fn test_parse_as_type_covers_the_upstream_value_type_switch() {
	assert parsed_type('25%', .angle_percentage)?.serialize(.normal) == '25%'
	assert parsed_type('left 10px top 20px', .background_position)?.serialize(.normal).len > 0
	assert parsed_type('circle()', .basic_shape)?.serialize(.normal).starts_with('circle(')
	assert parsed_type('path("")', .basic_shape) == none
	assert parsed_type('path("L 1 2")', .basic_shape) == none
	assert parsed_type('path("M0 0L3 4")', .basic_shape)?.serialize(.normal) == 'path("M 0 0 L 3 4")'
	assert parsed_type('counter(item)', .counter)?.serialize(.normal).starts_with('counter(')
	assert parsed_type('decimal', .counter_style)?.serialize(.normal) == 'decimal'
	assert parsed_type('blur(2px)', .filter_value_list)?.serialize(.normal) == 'blur(2px)'
	url_filter := parsed_type('url("filters.svg#blur") blur(2px)', .filter_value_list)?
	assert url_filter is FilterValueListStyleValue
	assert url_filter.serialize(.normal).contains('filters.svg#blur')
	assert (url_filter as FilterValueListStyleValue).contains_url()
	assert parsed_type('fit-content(20%)', .fit_content)?.serialize(.normal) == 'fit-content(20%)'
	assert parsed_type('normal', .font_variant_alternates)?.serialize(.normal) == 'normal'
	assert parsed_type('normal', .font_variant_east_asian)?.serialize(.normal) == 'normal'
	assert parsed_type('normal', .font_variant_ligatures)?.serialize(.normal) == 'normal'
	assert parsed_type('normal', .font_variant_numeric)?.serialize(.normal) == 'normal'
	assert parsed_type('25%', .frequency_percentage)?.serialize(.normal) == '25%'
	assert parsed_type('url("image.png")', .image)?.serialize(.normal).contains('image.png')
	assert parsed_type('"kern"', .opentype_tag)?.serialize(.normal) == '"kern"'
	assert parsed_type('red', .paint)?.serialize(.normal) == 'red'
	assert parsed_type('center', .position)?.serialize(.normal).len > 0
	assert parsed_type('rect(1px, auto, 3px, 4px)', .rect)?.serialize(.normal) == 'rect(1px, auto, 3px, 4px)'
	assert parsed_type('25%', .time_percentage)?.serialize(.normal) == '25%'
	assert parsed_type('url("asset.dat")', .url)?.serialize(.normal).contains('asset.dat')
	assert parsed_type('"toolong"', .opentype_tag) == none
}

fn test_svg_d_property_accepts_none_and_path_only() {
	assert property_id_from_string('d')? == .d
	assert property_initial_value_string(.d) == 'none'
	assert parse_css_value_logic(.d, 'none')?.serialize(.normal) == 'none'
	path := parse_css_value_logic(.d, 'path("M0 0L3 4")')?
	assert path is BasicShapeStyleValue
	assert path.serialize(.normal) == 'path("M 0 0 L 3 4")'
	assert parse_css_value_logic(.d, 'circle(10px)') == none
	assert parse_css_value_logic(.d, 'M0 0L3 4') == none
}

fn test_vector_effect_property_accepts_only_supported_keywords() {
	assert property_id_from_string('vector-effect')? == .vector_effect
	assert property_initial_value_string(.vector_effect) == 'none'
	assert parse_css_value_logic(.vector_effect, 'none')?.serialize(.normal) == 'none'
	assert parse_css_value_logic(.vector_effect, 'non-scaling-stroke')?.serialize(.normal) == 'non-scaling-stroke'
	assert parse_css_value_logic(.vector_effect, 'non-scaling-size') == none
}

fn test_parser_helpers_preserve_source_and_decode_css_bytes() {
	sheet := parse_css_stylesheet(ParsingParams{}, 'a { color: red; }', none, none)
	assert sheet.source_text()? == 'a { color: red; }'
	assert sheet.css_rules().length() == 1
	assert css_decode_bytes(none, 'windows-1252', [u8(0x80)])! == '€'
	assert css_decode_bytes(none, none, '@charset "utf-8";a{}'.bytes())! == '@charset "utf-8";a{}'
}

fn test_sizes_attribute_auto_uses_rendered_width() {
	document := dom.Document.create(dom.url_about_blank())
	element := document.create_element('img')!
	assert parse_sizes_attribute_source_size(element, 'auto, 50vw', 137.0) == 137
}

fn test_sizes_attribute_rejects_invalid_lengths_and_unknown_media_conditions() {
	document := dom.Document.create(dom.url_about_blank())
	element := document.create_element('img')!
	assert parse_sizes_attribute_source_size(element, '-10px, 25px', none) == 25
	assert parse_sizes_attribute_source_size(element, 'calc(infinity * 1px), 30px', none) == 30
	assert parse_sizes_attribute_source_size(element, '(unknown-feature: 1px) 35px, 40px', none) == 40
	assert parse_sizes_attribute_source_size(element, '(width < calc(0)) 45px, 50px', none) == 50
}

fn test_media_general_enclosed_rejects_non_any_value_tokens() {
	mut parser := Parser.from_css_text('(unknown("unterminated\n))')
	mut tokens := ComponentValueStream.new(parser.component_values)
	assert parser.parse_media_condition(mut tokens) == none
}
