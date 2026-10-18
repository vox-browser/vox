module layout

import css
import dom
import html
import math
import painting

fn dark_preferred_color_scheme_for_svg_image_test(_ voidptr) string {
	return 'dark'
}

fn typed_paint_node_with_id(root &Node, id string) ?&Node {
	if dom_node := root.dom_node() {
		if element := dom_node.as_element() {
			if element.get_attribute_value('id') == id {
				return root
			}
		}
	}
	for child in root.children() {
		if found := typed_paint_node_with_id(child, id) {
			return found
		}
	}
	return none
}

fn append_typed_scroll_frame_index(indices_pointer &[]int, index int) {
	unsafe {
		mut indices := *indices_pointer
		indices << index
		*indices_pointer = indices
	}
}

fn typed_video_paint_fetch(_ dom.URL, _ u64) !html.MediaResourceResponse {
	return html.MediaResourceResponse{
		mime_type: 'video/mp4'
		video_tracks: [html.MediaTrackMetadata{ identifier: 1, name: 'video' }]
	}
}

fn typed_video_poster_fetch(_ dom.URL) !&dom.Bitmap_ {
	return &dom.Bitmap_{
		width: 30
		height: 15
		pitch: 120
		data: []u8{len: 30 * 15 * 4}
	}
}

fn computed_paint_test_style(style string) &css.ComputedProperties {
	document := dom.Document.create(dom.url_about_blank())
	mut element := document.create_element_ns('http://www.w3.org/1999/xhtml', 'div') or {
		panic(err)
	}
	element.set_attribute_value('style', style)
	mut computer := css.StyleComputer.new(document)
	computed := computer.compute_style(dom.AbstractElement.new(element, none))
	_ = css.resolve_computed_values_for_document(computed, document)
	return computed
}

fn test_typed_paint_adapter_retains_composite_values_without_css_text_reparse() {
	computed := computed_paint_test_style('color: rgb(1 2 3); background-color: currentColor; border-right: 7px dashed red; border-top-left-radius: 10% 20%; box-shadow: rgb(10 20 30) 2px 3px 4px 5px inset')
	values := css.resolve_computed_values(computed)

	// Poison the compatibility serialization. The adapter must consume the
	// retained StyleValue objects, as the C++ paint path does.
	for property in [css.PropertyID.background_color, .border_right_width, .border_right_style,
		.border_top_left_radius, .box_shadow] {
		value := computed.property(property, .yes) or { panic('missing computed property') }
		mut mutable_value := unsafe { &dom.StyleValue(value) }
		mutable_value.css_text = 'not-a-valid-${css.string_from_property_id(property)}'
	}

	current_color := css.Color{1, 2, 3, 255}
	color_context := css.ColorResolutionContext{
		current_color: current_color
	}
	assert computed_paint_color(computed, .background_color, color_context, current_color) == current_color
	assert values.border_right().line_style == .dashed
	assert math.abs(values.border_right().width.to_double() - 7.0) < 0.001
	assert values.has_noninitial_border_radii()

	radius := paintable_box_border_radii_data(values, CSSPixels.new(200), CSSPixels.new(100)).top_left
	assert math.abs(radius.x - 20.0) < 0.001
	assert math.abs(radius.y - 20.0) < 0.001

	shadows := computed_box_shadows(values)
	assert shadows.len == 1
	assert math.abs(shadows[0].offset_x - 2.0) < 0.001
	assert math.abs(shadows[0].offset_y - 3.0) < 0.001
	assert math.abs(shadows[0].blur - 4.0) < 0.001
	assert math.abs(shadows[0].spread - 5.0) < 0.001
	assert shadows[0].inset
	assert shadows[0].color == css.Color{10, 20, 30, 255}
}

fn test_paintable_box_border_radii_use_fixed_point_overlap_scaling() {
	computed := computed_paint_test_style('border-top-left-radius: 50px; border-top-right-radius: 70px')
	values := css.resolve_computed_values(computed)

	radii := paintable_box_border_radii_data(values, CSSPixels.new(100), CSSPixels.new(100))

	// Paintable.cpp multiplies each fixed-point radius by the exact 100/120
	// CSSPixelFraction. That truncates to a CSS pixel quantum; an f64 rewrite
	// instead leaves 41.666... and 58.333... in the paint transport.
	assert radii.top_left.x == CSSPixels.from_raw(2666).to_double()
	assert radii.top_right.x == CSSPixels.from_raw(3733).to_double()
	assert radii.top_left.x + radii.top_right.x <= 100
	assert radii.bottom_left == CornerRadius{}
	assert radii.bottom_right == CornerRadius{}
}

fn test_paintable_box_normalized_border_radii_only_shrink_for_borders() {
	computed := computed_paint_test_style('border-left: 90px solid; border-top-right-radius: 100px')
	values := css.resolve_computed_values(computed)
	border_radii := paintable_box_border_radii_data(values, CSSPixels.new(100), CSSPixels.new(100))

	padding_radii := paintable_box_normalized_border_radii_data(border_radii, values, .yes)

	// normalized_border_radii_data() shrinks each corner by its adjacent border
	// widths but does not normalize the result against the padding box. The
	// unrelated 90px left border therefore cannot shrink this top-right radius.
	assert padding_radii.top_right.x == 100
	assert padding_radii.top_left == CornerRadius{}
}

fn test_typed_paint_adapter_uses_computed_enums_and_lengths() {
	computed := computed_paint_test_style('appearance: none; outline: solid 7px; outline-offset: 3px; text-decoration-style: wavy; text-decoration-thickness: 25%; font-size: 20px; font-style: italic; font-family: monospace')

	assert computed.appearance() == .none_
	outline := paintable_box_outline_data(css.resolve_computed_values(computed)) or {
		panic('missing outline data')
	}
	assert math.abs(outline.top.width - 7.0) < 0.001
	assert outline.top.line_style == .solid
	assert computed_text_decoration_style(computed) == 'wavy'
	assert math.abs(computed_text_decoration_thickness(computed, 20) - 5.0) < 0.001
	assert computed.font_slope() != 0
	assert computed_font_is_monospace(computed)
}

fn test_typed_paint_adapter_treats_flex_and_grid_items_with_z_index_as_positioned() {
	document := html.parse_document('<!doctype html><style>html, body { margin: 0 } #grid { display: grid } #grid-item { z-index: 7 } #flex { display: flex } #flex-item { z-index: -3 } #ordinary { z-index: 9 }</style><body><div id="grid"><div id="grid-item"></div></div><div id="flex"><div id="flex-item"></div></div><div id="ordinary"></div></body>')
	root := layout_document_typed_in_viewport(document, 200, 120)
	item := document.get_element_by_id('grid-item') or { panic('missing grid item') }
	item_box := root.find_box(i64(item.as_node().unique_id())) or { panic('missing grid item box') }
	assert item_box.positioned
	assert item_box.z_index == 7
	assert !item_box.z_index_auto

	flex_item := document.get_element_by_id('flex-item') or { panic('missing flex item') }
	flex_item_box := root.find_box(i64(flex_item.as_node().unique_id())) or {
		panic('missing flex item box')
	}
	assert flex_item_box.positioned
	assert flex_item_box.z_index == -3
	assert !flex_item_box.z_index_auto

	ordinary := document.get_element_by_id('ordinary') or { panic('missing ordinary box') }
	ordinary_box := root.find_box(i64(ordinary.as_node().unique_id())) or {
		panic('missing ordinary paint box')
	}
	assert !ordinary_box.positioned
	assert ordinary_box.z_index == 0
	assert ordinary_box.z_index_auto
}

fn test_css_filter_resolver_uses_retained_computed_operations() {
	computed := computed_paint_test_style('color: rgb(9 10 11); filter: blur(3px) drop-shadow(2px -1px 4px currentColor) contrast(150%) hue-rotate(.25turn)')
	values := css.resolve_computed_values(computed)
	resolved := resolved_css_filter(values, css.ColorResolutionContext{
		current_color: values.color()
	})
	assert resolved.operations.len == 4
	assert resolved.operations[0] is painting.BlurFilter
	blur := resolved.operations[0] as painting.BlurFilter
	assert blur.radius == 3
	assert resolved.operations[1] is painting.DropShadowFilter
	shadow := resolved.operations[1] as painting.DropShadowFilter
	assert shadow.offset_x == 2
	assert shadow.offset_y == -1
	assert shadow.radius == 4
	assert shadow.color == painting.Color{9, 10, 11, 255}
	assert resolved.operations[2] is painting.ColorFilter
	color_filter := resolved.operations[2] as painting.ColorFilter
	assert color_filter.operation == .contrast
	assert color_filter.amount == 1.5
	assert resolved.operations[3] is painting.HueRotateFilter
	assert (resolved.operations[3] as painting.HueRotateFilter).angle_degrees == 90
}

fn test_css_filter_is_lowered_once_around_the_complete_subtree() {
	document := html.parse_document('<!doctype html><style>html, body { margin: 0 } #filtered { filter: blur(3px) contrast(150%) } .part { width: 40px; height: 20px } </style><body><div id="filtered"><div class="part" style="background:red"></div><div class="part" style="background:blue"></div></div></body>')
	_ = layout_document_typed_in_viewport(document, 160, 120)
	mut mutable_document := unsafe { &dom.Document(document) }
	display_list := record_retained_display_list(mut mutable_document) or { panic('missing display list') }
	commands := display_list_commands(display_list)
	filter_begins := commands.filter(it.kind == 'begin_css_filter_layer')
	filter_ends := commands.filter(it.kind == 'end_css_filter_layer')
	assert filter_begins.len == 1
	assert filter_ends.len == 1
	filter := filter_begins[0].visual_layer().filter or { panic('missing retained filter') }
	assert filter.operations.len == 2
	// Gfx::Filter composition stores the outer (later CSS) operation first.
	assert filter.operations[0].kind == 'color'
	assert filter.operations[1].kind == 'blur'
	mut inside_filter := false
	mut filtered_parts := 0
	for command in commands {
		if command.kind == 'begin_css_filter_layer' {
			inside_filter = true
		} else if command.kind == 'end_css_filter_layer' {
			inside_filter = false
		} else if command.kind == 'fill_rect'
			&& command.color in ['rgb(255 0 0)', 'rgb(0 0 255)'] {
			assert inside_filter
			filtered_parts++
		}
	}
	assert filtered_parts == 2
}

fn test_css_opacity_is_lowered_as_one_retained_subtree_effect() {
	document := html.parse_document('<!doctype html><style>html, body { margin: 0 } #faded { opacity: .4 } .part { width: 40px; height: 20px } </style><body><div id="faded"><div class="part" style="background:red"></div><div class="part" style="background:blue"></div></div></body>')
	_ = layout_document_typed_in_viewport(document, 160, 120)
	mut mutable_document := unsafe { &dom.Document(document) }
	commands := display_list_commands(record_retained_display_list(mut mutable_document) or {
		panic('missing display list')
	})
	effect_begins := commands.filter(it.kind == 'begin_css_effect_layer')
	effect_ends := commands.filter(it.kind == 'end_css_effect_layer')
	assert effect_begins.len == 1
	assert effect_ends.len == 1
	assert math.abs(effect_begins[0].visual_layer().opacity - 0.4) < 0.0001
	mut inside_effect := false
	mut faded_parts := 0
	for command in commands {
		if command.kind == 'begin_css_effect_layer' {
			inside_effect = true
		} else if command.kind == 'end_css_effect_layer' {
			inside_effect = false
		} else if command.kind == 'fill_rect'
			&& command.color in ['rgb(255 0 0)', 'rgb(0 0 255)'] {
			assert inside_effect
			assert math.abs(command.opacity - 0.4) < 0.0001
			assert math.abs(command.group_opacity - 0.4) < 0.0001
			faded_parts++
		}
	}
	assert faded_parts == 2
}

fn test_document_display_list_dump_uses_retained_paint_commands() {
	document := html.parse_document('<!doctype html><style>html, body { margin: 0 } #target { width: 40px; height: 20px; background: rgb(12 34 56) }</style><body><div id="target"></div></body>')
	_ = layout_document_typed_in_viewport(document, 160, 120)
	mut mutable_document := unsafe { &dom.Document(document) }
	dump_text := mutable_document.dump_display_list()

	assert dump_text.starts_with('AccumulatedVisualContext Tree:\n')
	assert dump_text.contains('\nDisplayList:\n')
	assert dump_text.contains('fill_rect')
	assert dump_text.contains('color=rgb(12 34 56)')
}

fn test_backdrop_filter_records_cpp_background_phase_command() {
	document := html.parse_document('<!doctype html><style>html, body { margin: 0 } #target { margin: 10px; width: 80px; height: 40px; padding: 4px; border: 3px solid black; border-radius: 10px 20px 30px 40px / 5px 10px 15px 20px; background: rgb(12 34 56); backdrop-filter: blur(3px) contrast(150%); box-shadow: 1px 2px 3px red }</style><body><div id="target"></div></body>')
	root := layout_document_typed_in_viewport(document, 180, 120)
	target := document.get_element_by_id('target') or { panic('missing target') }
	target_box := root.find_box(i64(target.as_node().unique_id())) or {
		panic('missing target box')
	}
	mut mutable_document := unsafe { &dom.Document(document) }
	commands := display_list_commands(record_retained_display_list(mut mutable_document) or {
		panic('missing display list')
	})
	backdrops := commands.filter(it.kind == 'apply_backdrop_filter')
	assert backdrops.len == 1
	backdrop := backdrops[0]
	assert backdrop.x == math.round(target_box.x - target_box.padding.left - target_box.border.left)
	assert backdrop.y == math.round(target_box.y - target_box.padding.top - target_box.border.top)
	assert backdrop.width == math.round(target_box.width + target_box.padding.left + target_box.padding.right + target_box.border.left + target_box.border.right)
	assert backdrop.height == math.round(target_box.height + target_box.padding.top + target_box.padding.bottom + target_box.border.top + target_box.border.bottom)
	assert backdrop.corner_radii.top_left.x == math.floor(target_box.border_radii.top_left.x)
	assert backdrop.corner_radii.bottom_left.y == math.floor(target_box.border_radii.bottom_left.y)
	assert !backdrop.backdrop_source_outside_filter
	filter := backdrop.backdrop_filter() or { panic('missing backdrop filter') }
	// Gfx::Filter stores the later CSS operation outside the earlier one.
	assert filter.operations.len == 2
	assert filter.operations[0].kind == 'color'
	assert filter.operations[0].first == 1.5
	assert filter.operations[1].kind == 'blur'
	assert filter.operations[1].first == 3
	mut backdrop_index := -1
	mut background_index := -1
	mut shadow_index := -1
	for index, command in commands {
		if command.kind == 'apply_backdrop_filter' {
			backdrop_index = index
		} else if command.kind == 'fill_rounded_rect' && command.color == 'rgb(12 34 56)' {
			background_index = index
		} else if command.kind == 'paint_outer_box_shadow' && command.color == 'rgb(255 0 0)' {
			shadow_index = index
		}
	}
	assert backdrop_index >= 0
	assert background_index > backdrop_index
	assert shadow_index > background_index
}

fn test_backdrop_filter_samples_outside_own_css_filter_layer() {
	document := html.parse_document('<!doctype html><style>html, body { margin: 0 } #target { width: 80px; height: 40px; background: rgb(11 22 33); filter: saturate(50%); backdrop-filter: brightness(120%) }</style><body><div id="target"></div></body>')
	_ = layout_document_typed_in_viewport(document, 160, 120)
	mut mutable_document := unsafe { &dom.Document(document) }
	commands := display_list_commands(record_retained_display_list(mut mutable_document) or {
		panic('missing display list')
	})
	mut begin_index := -1
	mut backdrop_index := -1
	mut background_index := -1
	mut end_index := -1
	for index, command in commands {
		if command.kind == 'begin_css_filter_layer' {
			begin_index = index
		} else if command.kind == 'apply_backdrop_filter' {
			backdrop_index = index
			assert command.backdrop_source_outside_filter
		} else if command.kind == 'fill_rect' && command.color == 'rgb(11 22 33)' {
			background_index = index
		} else if command.kind == 'end_css_filter_layer' {
			end_index = index
		}
	}
	assert begin_index >= 0
	assert backdrop_index > begin_index
	assert background_index > backdrop_index
	assert end_index > background_index
}

fn test_same_document_svg_backdrop_filter_retains_the_translated_graph() {
	document := html.parse_document('<!doctype html><style>html, body { margin: 0 } #target { width: 80px; height: 40px; backdrop-filter: url(#soft) }</style><body><svg width="0" height="0"><defs><filter id="soft" color-interpolation-filters="sRGB"><feGaussianBlur in="SourceGraphic" stdDeviation="2 3"/></filter></defs></svg><div id="target"></div></body>')
	_ = layout_document_typed_in_viewport(document, 160, 120)
	mut mutable_document := unsafe { &dom.Document(document) }
	commands := display_list_commands(record_retained_display_list(mut mutable_document) or {
		panic('missing display list')
	})
	backdrops := commands.filter(it.kind == 'apply_backdrop_filter')
	assert backdrops.len == 1
	filter := backdrops[0].backdrop_filter() or { panic('missing backdrop filter') }
	assert filter.operations.len == 0
	assert filter.nodes.len == 1
	assert filter.root_id or { -1 } == 0
	assert filter.nodes[0].kind == 'blur'
	assert filter.nodes[0].input_ids == [-1]
	assert filter.nodes[0].parameters['radius_x'] == 2
	assert filter.nodes[0].parameters['radius_y'] == 3
	bounds := filter.bounds or { panic('missing backdrop filter bounds') }
	assert bounds.x == backdrops[0].x
	assert bounds.y == backdrops[0].y
	assert bounds.width == backdrops[0].width
	assert bounds.height == backdrops[0].height
}

fn test_same_document_svg_filter_url_retains_the_translated_graph() {
	document := html.parse_document('<!doctype html><style>html, body { margin: 0 } #filtered { width: 80px; height: 40px; background: red; filter: contrast(150%) url(#soft) } feFlood { flood-color: rgb(12 34 56); flood-opacity: .25 }</style><body><svg width="0" height="0"><defs><filter id="soft" color-interpolation-filters="sRGB"><feGaussianBlur in="SourceGraphic" stdDeviation="2 3" result="blurred"/><feOffset in="blurred" dx="4" dy="5" result="shifted"/><feFlood result="paint"/><feBlend in="shifted" in2="paint" mode="multiply"/></filter></defs></svg><div id="filtered"></div></body>')
	_ = layout_document_typed_in_viewport(document, 160, 120)
	mut mutable_document := unsafe { &dom.Document(document) }
	display_list := record_retained_display_list(mut mutable_document) or { panic('missing display list') }
	filter_commands := display_list_commands(display_list).filter(it.kind == 'begin_css_filter_layer')
	assert filter_commands.len == 1
	filter := filter_commands[0].visual_layer().filter or { panic('missing retained filter') }
	assert filter.operations.len == 1
	assert filter.operations[0].kind == 'color'
	assert filter.nodes.len == 4
	assert filter.root_id or { -1 } == 3
	assert filter.nodes[0].kind == 'blur'
	assert filter.nodes[0].input_ids == [-1]
	assert filter.nodes[0].parameters['radius_x'] == 2
	assert filter.nodes[0].parameters['radius_y'] == 3
	assert filter.nodes[1].kind == 'offset'
	assert filter.nodes[1].input_ids == [0]
	assert filter.nodes[2].kind == 'flood'
	assert filter.nodes[2].color == painting.Color{12, 34, 56, 255}
	assert filter.nodes[2].parameters['opacity'] == 0.25
	assert filter.nodes[3].kind == 'blend'
	assert filter.nodes[3].input_ids == [2, 1]
	assert filter.nodes[3].string_parameters['mode'] == 'multiply'
}

fn test_same_document_svg_filter_uses_computed_interpolation_color_space() {
	document := html.parse_document('<!doctype html><style>html, body { margin: 0 } #filtered { width: 80px; height: 40px; background: rgb(128 0 0); filter: url(#matrix) } feColorMatrix { color-interpolation-filters: linearRGB }</style><body><svg width="0" height="0"><defs><filter id="matrix" color-interpolation-filters="sRGB"><feColorMatrix type="matrix" values="1 0 0 0 0 0 1 0 0 0 0 0 1 0 0 0 0 0 1 0"/></filter></defs></svg><div id="filtered"></div></body>')
	_ = layout_document_typed_in_viewport(document, 160, 120)
	mut mutable_document := unsafe { &dom.Document(document) }
	display_list := record_retained_display_list(mut mutable_document) or { panic('missing display list') }
	filter_commands := display_list_commands(display_list).filter(it.kind == 'begin_css_filter_layer')
	assert filter_commands.len == 1
	filter := filter_commands[0].visual_layer().filter or { panic('missing retained filter') }
	assert filter.nodes.map(it.kind) == ['color-space-conversion', 'color-matrix',
		'color-space-conversion']
	assert filter.nodes[0].input_ids == [-1]
	assert filter.nodes[0].string_parameters['source'] == 'srgb'
	assert filter.nodes[0].string_parameters['destination'] == 'linear-rgb'
	assert filter.nodes[1].input_ids == [0]
	assert filter.nodes[2].input_ids == [1]
	assert filter.nodes[2].string_parameters['source'] == 'linear-rgb'
	assert filter.nodes[2].string_parameters['destination'] == 'srgb'
	assert filter.root_id? == 2
}

fn test_same_document_svg_filter_retains_absolute_feimage_resource() {
	document := html.parse_document('<!doctype html><style>html, body { margin: 0 } #filtered { width: 80px; height: 40px; filter: url(#picture) }</style><body><svg width="0" height="0"><defs><filter id="picture"><feImage href="data:image/png;base64,AAAA" result="decoded"/><feOffset in="decoded" dx="2"/></filter></defs></svg><div id="filtered"></div></body>')
	_ = layout_document_typed_in_viewport(document, 160, 120)
	mut mutable_document := unsafe { &dom.Document(document) }
	display_list := record_retained_display_list(mut mutable_document) or { panic('missing display list') }
	filter_commands := display_list_commands(display_list).filter(it.kind == 'begin_css_filter_layer')
	assert filter_commands.len == 1
	filter := filter_commands[0].visual_layer().filter or { panic('missing retained filter') }
	assert filter.nodes.map(it.kind) == ['image', 'offset']
	assert filter.nodes[0].image_url == 'data:image/png;base64,AAAA'
	assert filter.nodes[0].input_ids == [-1]
	assert filter.nodes[1].input_ids == [0]
}

fn test_svg_filter_content_generation_records_the_cpp_transparent_bounds_trigger() {
	document := html.parse_document('<!doctype html><style>html, body { margin: 0 } #filtered { width: 80px; height: 40px; filter: url(#paint) }</style><body><svg width="0" height="0"><defs><filter id="paint"><feFlood flood-color="green"/></filter></defs></svg><div id="filtered"></div></body>')
	_ = layout_document_typed_in_viewport(document, 160, 120)
	mut mutable_document := unsafe { &dom.Document(document) }
	display_list := record_retained_display_list(mut mutable_document) or { panic('missing display list') }
	commands := display_list_commands(display_list)
	mut begin_index := -1
	mut trigger_index := -1
	mut end_index := -1
	for index, command in commands {
		if command.kind == 'begin_css_filter_layer' && begin_index < 0 {
			begin_index = index
		} else if command.kind == 'fill_rect_transparent' && trigger_index < 0 {
			trigger_index = index
		} else if command.kind == 'end_css_filter_layer' && end_index < 0 {
			end_index = index
		}
	}
	assert begin_index >= 0
	assert trigger_index > begin_index
	assert end_index > trigger_index
	trigger := commands[trigger_index]
	assert trigger.width == 80
	assert trigger.height == 40
	filter := commands[begin_index].visual_layer().filter or { panic('missing retained filter') }
	bounds := filter.bounds or { panic('missing retained filter bounds') }
	assert bounds.x == trigger.x
	assert bounds.y == trigger.y
	assert bounds.width == trigger.width
	assert bounds.height == trigger.height
}

fn test_external_and_non_filter_css_urls_do_not_create_svg_graphs() {
	document := html.parse_document('<!doctype html><style>#target { filter: url(https://example.test/filter.svg#remote) url(#not-filter) blur(2px) }</style><body><div id="not-filter"></div><div id="target">text</div></body>')
	_ = layout_document_typed_in_viewport(document, 160, 120)
	mut mutable_document := unsafe { &dom.Document(document) }
	display_list := record_retained_display_list(mut mutable_document) or { panic('missing display list') }
	filter_commands := display_list_commands(display_list).filter(it.kind == 'begin_css_filter_layer')
	assert filter_commands.len == 1
	filter := filter_commands[0].visual_layer().filter or { panic('missing retained filter') }
	assert filter.operations.len == 1
	assert filter.operations[0].kind == 'blur'
	assert filter.nodes.len == 0
	assert filter.root_id == none
}

fn test_css_filter_and_svg_mask_keep_visual_context_nesting_order() {
	document := html.parse_document('<!doctype html><style>html, body { margin: 0 } #filtered { filter: saturate(50%) } svg { display:block }</style><body><div id="filtered"><svg width="120" height="80"><defs><mask id="fade" mask-type="alpha"><rect width="120" height="80" fill="white"/></mask></defs><g mask="url(#fade)"><rect width="120" height="80" fill="red"/></g></svg></div></body>')
	_ = layout_document_typed_in_viewport(document, 160, 120)
	mut mutable_document := unsafe { &dom.Document(document) }
	display_list := record_retained_display_list(mut mutable_document) or { panic('missing display list') }
	mut significant := []string{}
	for command in display_list_commands(display_list) {
		if command.kind in ['begin_css_filter_layer', 'begin_svg_mask_layer', 'draw_svg_path',
			'end_svg_mask_layer', 'end_css_filter_layer'] {
			significant << command.kind
		}
	}
	assert significant == ['begin_css_filter_layer', 'begin_svg_mask_layer', 'draw_svg_path',
		'end_svg_mask_layer', 'end_css_filter_layer']
}

fn test_typed_paint_adapter_resolves_gradients_from_retained_style_values() {
	linear := computed_paint_test_style('background-image: linear-gradient(90deg, red 10%, blue 90%)')
	linear_value := linear.property(.background_image, .yes) or { panic('missing gradient') }
	mut mutable_linear_value := unsafe { &dom.StyleValue(linear_value) }
	mutable_linear_value.css_text = 'none'
	color_context := css.ColorResolutionContext{
		current_color: css.Color{0, 0, 0, 255}
	}
	resolved_linear := computed_background_gradient(linear, 200, 100, color_context) or {
		panic('linear gradient was reparsed from poisoned text')
	}
	assert resolved_linear.kind == 'linear'
	assert math.abs(resolved_linear.x1) < 0.001
	assert math.abs(resolved_linear.x2 - 1.0) < 0.001
	assert resolved_linear.stops.len == 2
	assert math.abs(resolved_linear.stops[0].offset - 0.1) < 0.001
	assert math.abs(resolved_linear.stops[1].offset - 0.9) < 0.001
	hinted := computed_paint_test_style('background-image: linear-gradient(red 0%, 25%, blue 100%)')
	resolved_hint := computed_background_gradient(hinted, 100, 100, color_context) or {
		panic('transition-hint gradient did not resolve')
	}
	assert resolved_hint.stops.len == 7
	assert math.abs(resolved_hint.stops[3].offset - 0.25) < 0.001
	assert resolved_hint.stops[3].color.r in [u8(127), 128]
	assert resolved_hint.stops[3].color.b in [u8(127), 128]
	// ComputedProperties.cpp converts the default `background-size: auto` entries through
	// LengthPercentageOrAuto::from_style_value; this must remain auto rather than reaching the
	// length-only VERIFY_NOT_REACHED path.
	layers := linear.background_layers()
	assert layers.len == 1
	assert layers[0].size_type == .length_percentage
	assert layers[0].size_x.is_auto()
	assert layers[0].size_y.is_auto()

	radial := computed_paint_test_style('background-image: radial-gradient(circle closest-side at 25% 75%, red, blue)')
	resolved_radial := computed_background_gradient(radial, 200, 100, color_context) or {
		panic('missing radial gradient')
	}
	assert resolved_radial.kind == 'radial'
	assert math.abs(resolved_radial.center_x - 0.25) < 0.001
	assert math.abs(resolved_radial.center_y - 0.75) < 0.001
	assert math.abs(resolved_radial.radius_x - 0.125) < 0.001
	assert math.abs(resolved_radial.radius_y - 0.25) < 0.001

	conic := computed_paint_test_style('background-image: conic-gradient(from 45deg at 20% 30%, red 0deg, blue 1turn)')
	resolved_conic := computed_background_gradient(conic, 200, 100, color_context) or {
		panic('missing conic gradient')
	}
	assert resolved_conic.kind == 'conic'
	assert math.abs(resolved_conic.center_x - 0.2) < 0.001
	assert math.abs(resolved_conic.center_y - 0.3) < 0.001
	assert math.abs(resolved_conic.start_degrees - 45.0) < 0.001
	assert math.abs(resolved_conic.stops[1].offset - 1.0) < 0.001
}

fn test_typed_gradient_sampler_retains_cpp_interpolation_method() {
	color_context := css.ColorResolutionContext{
		current_color: css.Color{0, 0, 0, 255}
	}
	linear := computed_paint_test_style('background-image: linear-gradient(in srgb-linear, red, blue)')
	resolved_linear := computed_background_gradient(linear, 200, 100, color_context) or {
		panic('missing linear gradient')
	}
	method := resolved_linear.interpolation_method or { panic('lost interpolation method') }
	assert method == css.ColorInterpolationMethod(css.RectangularColorSpace.srgb_linear)
	linear_midpoint := gradient_color_at(resolved_linear, 0.5)
	assert math.abs(f64(linear_midpoint.r) - 188.0) <= 1
	assert linear_midpoint.g == 0
	assert math.abs(f64(linear_midpoint.b) - 188.0) <= 1

	modern := computed_paint_test_style('background-image: radial-gradient(color(srgb 1 0 0), blue)')
	resolved_modern := computed_background_gradient(modern, 200, 100, color_context) or {
		panic('missing modern gradient')
	}
	modern_method := resolved_modern.interpolation_method or {
		panic('lost modern default interpolation method')
	}
	assert modern_method == css.ColorInterpolationMethod(css.RectangularColorSpace.oklab)
	modern_midpoint := gradient_color_at(resolved_modern, 0.5)
	assert math.abs(f64(modern_midpoint.r) - 140.0) <= 1
	assert math.abs(f64(modern_midpoint.g) - 83.0) <= 1
	assert math.abs(f64(modern_midpoint.b) - 162.0) <= 1
}

fn test_portable_svg_preserves_or_samples_css_gradient_interpolation_space() {
	document := html.parse_document('<!doctype html><style>html, body { margin: 0 } div { width: 100px; height: 20px } #linear { background-image: linear-gradient(in srgb-linear, red, blue) } #oklab { background-image: linear-gradient(in oklab, red, blue) }</style><body><div id="linear"></div><div id="oklab"></div></body>')
	root := layout_document_typed_in_viewport(document, 120, 80)
	svg := root.render_svg(120, 80)
	assert svg.contains('color-interpolation="linearRGB"')
	assert svg.contains('color-interpolation="sRGB"')
	// OKLab has no native SVG interpolation mode, so the portable backend
	// materializes sampled sRGB stops, including the exact 50% midpoint.
	assert svg.contains('offset="50%" stop-color="rgb(140 83 162)"')
}

fn test_typed_background_images_keep_gradient_url_layer_order_and_geometry() {
	document := html.parse_document('<!doctype html><style>
		html, body { margin: 0 }
		#target {
			width: 100px; height: 60px; padding: 10px; border: 5px solid;
			border-radius: 20px / 12px;
			background-image: linear-gradient(90deg, red, blue), url("back.png");
			background-size: 25px auto, 12px 8px;
			background-repeat: space no-repeat, no-repeat;
			background-position: 75% 25%, 10% 20%;
			background-origin: content-box, padding-box;
			background-clip: padding-box, content-box;
			background-attachment: local, fixed;
			background-blend-mode: multiply, screen;
		}
	</style><body><div id="target"></div></body>')
	root := layout_document_typed_in_viewport(document, 320, 200)
	target_element := document.get_element_by_id('target') or { panic('missing target') }
	target := root.find_box(i64(target_element.as_node().unique_id())) or {
		panic('missing target box')
	}
	assert target.background_images.len == 2
	assert target.background_images[0].gradient_source != none
	assert target.background_images[0].url == ''
	assert target.background_images[1].gradient_source == none
	assert target.background_images[1].url.ends_with('back.png')

	commands := target.paint_commands()
	background_commands := commands.filter(it.kind in ['fill_gradient', 'draw_background_image'])
	assert background_commands.len == 2
	// CSS stores image layers front-to-back; BackgroundPainting paints them back-to-front.
	assert background_commands[0].kind == 'draw_background_image'
	assert background_commands[1].kind == 'fill_gradient'
	gradient_command := background_commands[1]
	assert gradient_command.gradient_background_layer
	assert gradient_command.width == 100
	assert gradient_command.height == 60
	assert gradient_command.image().image_clip_width == 120
	assert gradient_command.image().image_clip_height == 80
	assert gradient_command.image().image_attachment == 'local'
	assert gradient_command.image().background_blend_mode == .multiply
	gradient_data := gradient_command.image().background_layer_data or {
		panic('gradient lost its typed BackgroundLayerData')
	}
	gradient_layer := gradient_data.layer
	assert gradient_layer.repeat_x == .space
	assert gradient_layer.repeat_y == .no_repeat
	assert gradient_layer.origin == .content_box
	assert gradient_layer.clip == .padding_box
	gradient := gradient_command.gradient or { panic('gradient was not resolved for its tile') }
	assert math.abs(gradient.x1) < 0.001
	assert math.abs(gradient.x2 - 1.0) < 0.001
	gradient_tiles := resolved_background_gradient_tiles(gradient_command)
	// The padding-box clip extends one tile beyond each side of the content-box positioning area.
	assert gradient_tiles.len == 6
	assert gradient_tiles[0].width == 25
	assert gradient_tiles[0].height == 60

	assert background_commands[0].image().background_blend_mode == .screen
	assert background_commands[0].image().image_clip_width == 100
	assert background_commands[0].image().image_clip_height == 60
	svg := target.render_svg(160, 120)
	assert svg.contains('style="mix-blend-mode:multiply"')
	assert svg.contains('style="mix-blend-mode:screen"')
	assert svg.contains('<g style="isolation:isolate">')
	assert svg.contains('<clipPath id="gradient-clip')
}

fn test_fixed_background_layers_compensate_nested_scroll_frames_independently() {
	document := html.parse_document('<!doctype html><style>
		html, body { margin: 0 }
		#scroller { width: 100px; height: 50px; overflow: auto }
		#target {
			width: 100px; height: 160px;
			background-image: linear-gradient(red, red), linear-gradient(blue, blue);
			background-size: 20px 20px;
			background-repeat: no-repeat;
			background-attachment: fixed, scroll;
		}
	</style><body><div id="scroller"><div id="target"></div></div></body>')
	root := layout_document_typed_in_viewport(document, 320, 100)
	target_element := document.get_element_by_id('target') or { panic('missing target') }
	target := root.find_box(i64(target_element.as_node().unique_id())) or {
		panic('missing target box')
	}
	fixed_context := target.fixed_background_visual_context or {
		panic('missing fixed-background visual context')
	}
	result := document_layout_result(document) or { panic('missing layout result') }
	mut compensation_count := 0
	mut context_index := fixed_context
	for context_index > 0 {
		context_node := result.visual_context_tree.node_at(context_index)
		if context_node.data is painting.ScrollCompensationVisualData {
			compensation_count++
		}
		context_index = context_node.parent_index
	}
	// The target is below both the mandatory viewport frame and #scroller.
	assert compensation_count == 2

	scroller := document.get_element_by_id('scroller') or { panic('missing scroller') }
	mut scroller_paintable := scroller.paintable_box() or { panic('missing scroller paintable') }
	assert scroller_paintable.set_scroll_offset(dom.CSSPixelPoint_{ y_: 25 })
	mut mutable_document := unsafe { &dom.Document(document) }
	display_list := record_retained_display_list(mut mutable_document) or { panic('missing display list') }
	gradients := display_list_commands(display_list).filter(it.kind == 'fill_gradient'
		&& it.gradient_background_layer)
	assert gradients.len == 2
	// Layers paint back-to-front. The scroll layer keeps the live scroll
	// transform; only the fixed layer switches to the compensating context and
	// uses the initial containing block as its positioning area.
	assert gradients[0].width == 100
	assert gradients[0].height == 160
	assert gradients[0].transform[5] == -25
	assert gradients[1].width == 320
	assert gradients[1].height == 100
	assert gradients[1].transform[5] == 0

	retained_command_count := result.paint_phase_command_count
	assert scroller_paintable.set_scroll_offset(dom.CSSPixelPoint_{ y_: 35 })
	replayed := record_retained_display_list(mut mutable_document) or { panic('missing replayed display list') }
	replayed_gradients := display_list_commands(replayed).filter(it.kind == 'fill_gradient'
		&& it.gradient_background_layer)
	assert replayed_gradients[0].transform[5] == -35
	assert replayed_gradients[1].transform[5] == 0
	assert result.paint_phase_command_count == retained_command_count
}

fn test_fixed_background_inside_transform_behaves_as_scroll() {
	document := html.parse_document('<!doctype html><style>
		html, body { margin: 0 }
		#outer { width: 100px; transform: translateX(10px); transform-origin: 0 0 }
		#target {
			width: 100px; height: 60px;
			background-image: linear-gradient(red, blue);
			background-size: 20px 20px;
			background-repeat: no-repeat;
			background-attachment: fixed;
		}
	</style><body><div id="outer"><div id="target"></div></div></body>')
	root := layout_document_typed_in_viewport(document, 320, 100)
	target_element := document.get_element_by_id('target') or { panic('missing target') }
	target := root.find_box(i64(target_element.as_node().unique_id())) or {
		panic('missing target box')
	}
	assert target.fixed_background_visual_context == none
	mut mutable_document := unsafe { &dom.Document(document) }
	display_list := record_retained_display_list(mut mutable_document) or { panic('missing display list') }
	gradients := display_list_commands(display_list).filter(it.kind == 'fill_gradient'
		&& it.gradient_background_layer)
	assert gradients.len == 1
	assert gradients[0].width == 100
	assert gradients[0].height == 60
	assert gradients[0].transform[4] == 10
}

fn test_typed_background_image_set_selects_candidate_for_device_pixel_ratio() {
	document := html.parse_document('<!doctype html><style>
		html, body { margin: 0 }
		#target { width: 20px; height: 20px; background-image: image-set(url("one.png") 1x, url("two.png") 2x) }
	</style><body><div id="target"></div></body>')
	root := layout_document_typed_in_viewport(document, 100, 100)
	target_element := document.get_element_by_id('target') or { panic('missing target') }
	target := root.find_box(i64(target_element.as_node().unique_id())) or {
		panic('missing target box')
	}
	assert target.background_images.len == 1
	assert target.background_images[0].url.ends_with('one.png')
}

fn test_svg_background_image_retains_its_isolated_document_for_nested_painting() {
	source := 'data:image/svg+xml,%3Csvg%20xmlns%3D%22http%3A%2F%2Fwww.w3.org%2F2000%2Fsvg%22%20width%3D%2232%22%20height%3D%2216%22%20viewBox%3D%220%200%2032%2016%22%3E%3Cpath%20d%3D%22M2%2027L16-2L30%2027Z%22%20fill%3D%22%23999%22%2F%3E%3C%2Fsvg%3E'
	document := html.parse_document('<!doctype html><style>html,body{margin:0}#arrow{width:10px;height:10px;background:url("${source}") no-repeat;background-size:10px}</style><div id="arrow"></div>')
	root := layout_document_typed_in_viewport(document, 80, 60)
	backgrounds := root.paint_commands().filter(it.kind == 'draw_background_image')
	assert backgrounds.len == 1
	assert backgrounds[0].image().background_svg_document != none
	assert backgrounds[0].image().image_intrinsic_width == 32
	assert backgrounds[0].image().image_intrinsic_height == 16
	assert backgrounds[0].image().image_size.starts_with('10px')
}

fn test_svg_background_image_uses_the_embedding_elements_color_scheme() {
	source := 'data:image/svg+xml,%3Csvg%20xmlns%3D%22http%3A%2F%2Fwww.w3.org%2F2000%2Fsvg%22%20viewBox%3D%220%200%2010%2010%22%3E%3Cpath%20d%3D%22M0%200H10V10H0Z%22%2F%3E%3C%2Fsvg%3E'
	document := html.parse_document('<!doctype html><style>html,body{margin:0}#target{width:10px;height:10px;color-scheme:dark;background-image:url("${source}")}</style><div id="target"></div>')
	root := layout_document_typed_in_viewport(document, 40, 40)
	backgrounds := root.paint_commands().filter(it.kind == 'draw_background_image')
	assert backgrounds.len == 1
	assert backgrounds[0].image().background_svg_color_scheme == .dark
	isolated_document := backgrounds[0].image().background_svg_document or {
		panic('missing isolated SVG document')
	}
	assert isolated_document.svg_image_color_scheme()? == 'dark'
	assert isolated_document.preferred_color_scheme() == 'dark'
}

fn test_svg_images_use_page_preference_without_a_supported_color_scheme() {
	source := 'data:image/svg+xml,%3Csvg%20xmlns%3D%22http%3A%2F%2Fwww.w3.org%2F2000%2Fsvg%22%20viewBox%3D%220%200%2010%2010%22%3E%3Cpath%20d%3D%22M0%200H10V10H0Z%22%2F%3E%3C%2Fsvg%3E'
	mut document := html.parse_document('<!doctype html><style>html,body{margin:0}.sample{width:10px;height:10px;background-image:url("${source}")}.light{color-scheme:light}.dark{color-scheme:dark}.custom{color-scheme:custom}img{display:block;width:10px;height:10px}</style><div id="normal" class="sample"></div><div id="light" class="sample light"></div><div id="dark" class="sample dark"></div><div id="custom" class="sample custom"></div><img id="normal-image" src="${source}"><img id="light-image" class="light" src="${source}"><img id="custom-image" class="custom" src="${source}">')
	mut page_target := 0
	document.set_page(&dom.Page{
		target: unsafe { voidptr(&page_target) }
		preferred_color_scheme_callback: dark_preferred_color_scheme_for_svg_image_test
	})
	root := layout_document_typed_in_viewport(document, 80, 100)

	for id, expected in {
		'normal': css.PreferredColorScheme.dark
		'light':  css.PreferredColorScheme.light
		'dark':   css.PreferredColorScheme.dark
		'custom': css.PreferredColorScheme.dark
	} {
		element := document.get_element_by_id(id) or { panic('missing ${id}') }
		box := root.find_box(i64(element.as_node().unique_id())) or { panic('missing ${id} box') }
		assert box.background_images.len == 1
		assert box.background_images[0].color_scheme == expected
		assert box.background_images[0].svg_document?.svg_image_color_scheme()? == css.preferred_color_scheme_to_string(expected)
	}

	for id, expected in {
		'normal-image': css.PreferredColorScheme.dark
		'light-image':  css.PreferredColorScheme.light
		'custom-image': css.PreferredColorScheme.dark
	} {
		element := document.get_element_by_id(id) or { panic('missing ${id}') }
		box := root.find_box(i64(element.as_node().unique_id())) or { panic('missing ${id} box') }
		svg_document := box.nested_viewport_document or { panic('missing ${id} SVG document') }
		assert svg_document.svg_image_color_scheme()? == css.preferred_color_scheme_to_string(expected)
	}
}

fn test_typed_background_clip_text_reaches_the_group_mask() {
	document := html.parse_document('<!doctype html><style>html, body { margin: 0 } #target { width: 180px; height: 50px; color: transparent; font-size: 24px; background-color: red; background-image: linear-gradient(90deg, yellow, blue); background-clip: text }</style><body><div id="target">Clipped words</div></body>')
	root := layout_document_typed_in_viewport(document, 240, 100)
	target_element := document.get_element_by_id('target') or { panic('missing target') }
	target := root.find_box(i64(target_element.as_node().unique_id())) or {
		panic('missing target box')
	}
	assert target.background_color_clip == 'text'
	commands := target.paint_commands()
	begin_commands := commands.filter(it.kind == 'begin_background_text_clip')
	assert begin_commands.len == 1
	assert begin_commands[0].text_clip_runs.len == 1
	assert begin_commands[0].text_clip_runs[0].text == 'Clipped words'
	clip_glyph_run := begin_commands[0].text_clip_runs[0].glyph_run or {
		panic('background text clip discarded its retained glyph run')
	}
	assert clip_glyph_run.glyphs().len > 0
	assert begin_commands[0].text_clip_runs[0].glyph_translation_y > begin_commands[0].text_clip_runs[0].y
	assert commands.filter(it.kind == 'end_background_text_clip').len == 1
	assert target.render_svg(240, 100).contains('<g mask="url(#background-text-mask')
}

fn test_fieldset_background_clip_text_collects_each_glyph_run_once() {
	document := html.parse_document('<!doctype html><style>html, body { margin: 0 } fieldset { padding: 20px; border: 6px solid black; font-size: 40px; background: linear-gradient(#6d98cc, #8a64e5); background-clip: text; color: transparent } legend { color: black }</style><body><fieldset id="target"><legend>Legend</legend>Hello fieldset text</fieldset></body>')
	root := layout_document_typed_in_viewport(document, 800, 600)
	target_element := document.get_element_by_id('target') or { panic('missing fieldset') }
	target := root.find_box(i64(target_element.as_node().unique_id())) or {
		panic('missing fieldset box')
	}
	begin_commands := target.paint_commands().filter(it.kind == 'begin_background_text_clip')
	assert begin_commands.len == 1
	assert begin_commands[0].text_clip_runs.map(it.text) == ['Legend', 'Hello fieldset text']
}

fn test_body_background_is_propagated_to_canvas_and_not_painted_twice() {
	document := html.parse_document('<!doctype html><style>html { background: transparent } body { margin: 20px; width: 100px; height: 40px; background: rgb(12 34 56) }</style><body id="body"></body>')
	root := layout_document_typed_in_viewport(document, 320, 200)
	body := document.get_element_by_id('body') or { panic('missing body') }
	body_box := root.find_box(i64(body.as_node().unique_id())) or { panic('missing body box') }

	assert root.paints_canvas_background
	assert root.background_color == css.Color{12, 34, 56, 255}
	assert document.background_color() == dom.Color{12, 34, 56, 255}
	assert body_box.skip_background_paint
	fills := root.paint_commands().filter(it.kind == 'fill_rect' && it.color == 'rgb(12 34 56)')
	assert fills.len == 1
	assert fills[0].x == 0
	assert fills[0].y == 0
	assert fills[0].width == 320
	assert fills[0].height == 200
}

fn test_containment_disables_body_background_propagation() {
	document := html.parse_document('<!doctype html><style>html { background: transparent } body { contain: paint; margin: 20px; width: 100px; height: 40px; background: rgb(12 34 56) }</style><body id="body"></body>')
	root := layout_document_typed_in_viewport(document, 320, 200)
	body := document.get_element_by_id('body') or { panic('missing body') }
	body_box := root.find_box(i64(body.as_node().unique_id())) or { panic('missing body box') }

	assert root.background_color.a == 0
	assert !body_box.skip_background_paint
	fills := root.paint_commands().filter(it.kind == 'fill_rect' && it.color == 'rgb(12 34 56)')
	assert fills.len == 1
	assert fills[0].x != 0 || fills[0].width != 320
}

fn test_body_without_a_generated_box_prevents_later_body_background_propagation() {
	mut document := html.parse_document('<!doctype html><style>html { background: transparent } #rendered { margin: 20px; width: 100px; height: 40px; background: rgb(12 34 56) }</style><body id="rendered"></body>')
	html_element := document.html_element() or { panic('missing html element') }
	rendered_body := document.body() or { panic('missing rendered body') }
	mut hidden_body := document.create_element('body')!
	hidden_body.set_attribute_value('style', 'display: none')
	mut html_node := unsafe { &dom.Element(html_element) }.as_node()
	html_node.pre_insert(hidden_body.as_node(), unsafe { &dom.Element(rendered_body) }.as_node())!
	assert voidptr(unsafe { &dom.Element(document.body()?) }.as_node()) == voidptr(hidden_body.as_node())

	root := layout_document_typed_in_viewport(document, 320, 200)
	rendered_box := root.find_box(i64(unsafe { &dom.Element(rendered_body) }.as_node().unique_id())) or {
		panic('missing rendered body box')
	}
	assert root.background_color.a == 0
	assert !rendered_box.skip_background_paint
	fills := root.paint_commands().filter(it.kind == 'fill_rect' && it.color == 'rgb(12 34 56)')
	assert fills.len == 1
	assert fills[0].x != 0 || fills[0].width != 320
}

fn test_body_background_layers_are_propagated_to_root_canvas() {
	document := html.parse_document('<!doctype html><style>html { background: transparent } body { margin: 20px; width: 100px; height: 40px; background-image: linear-gradient(red, blue); image-rendering: pixelated }</style><body id="body"></body>')
	root := layout_document_typed_in_viewport(document, 320, 200)
	body := document.get_element_by_id('body') or { panic('missing body') }
	body_box := root.find_box(i64(body.as_node().unique_id())) or { panic('missing body box') }

	assert body_box.skip_background_paint
	assert root.background_gradient != none
	assert root.replaced_image_rendering == .pixelated
	gradients := root.paint_commands().filter(it.kind == 'fill_gradient')
	assert gradients.len == 1
	assert gradients[0].x == 0
	assert gradients[0].y == 0
	assert gradients[0].width == 320
	assert gradients[0].height == root.border_box().height
	root_tiles := resolved_background_gradient_tiles(gradients[0])
	assert root_tiles.len > 1
	assert root_tiles.last().bottom() >= 200

	// Document's painting helpers cross the DOM -> CSS dependency boundary but
	// must expose the same retained typed values as the body Layout::Box.
	dom_layers := document.background_layers() or { panic('missing document background layers') }
	assert dom_layers.len == 1
	typed_layer := css.background_layer_from_dom(dom_layers[0]) or {
		panic('background layer was not retained as typed CSS data')
	}
	assert typed_layer.image.contains('linear-gradient')
	assert document.background_image_rendering() == .pixelated
}

fn test_root_background_layer_prevents_body_propagation() {
	document := html.parse_document('<!doctype html><style>html { background-image: linear-gradient(black, white) } body { margin: 20px; width: 100px; height: 40px; background: rgb(12 34 56) }</style><body id="body"></body>')
	root := layout_document_typed_in_viewport(document, 320, 200)
	body := document.get_element_by_id('body') or { panic('missing body') }
	body_box := root.find_box(i64(body.as_node().unique_id())) or { panic('missing body box') }

	assert !body_box.skip_background_paint
	gradients := root.paint_commands().filter(it.kind == 'fill_gradient')
	assert gradients.len == 1
	assert gradients[0].width == 320
	fills := root.paint_commands().filter(it.kind == 'fill_rect' && it.color == 'rgb(12 34 56)')
	assert fills.len == 1
	assert fills[0].x != 0 || fills[0].width != 320
}

fn test_typed_paint_adapter_composes_nested_transforms_while_descending() {
	document := html.parse_document('<!doctype html><style>
		html, body { margin:0 }
		#outer { transform:translateX(10px); transform-origin:0 0 }
		#middle { transform:translateY(20px); transform-origin:0 0 }
		#inner { width:20px; height:10px; transform:scale(2); transform-origin:0 0 }
	</style><body><div id="outer"><div id="middle"><div id="inner"></div></div></div></body>')
	root := layout_document_typed_in_viewport(document, 320, 200)
	outer_element := document.get_element_by_id('outer') or { panic('missing outer') }
	middle_element := document.get_element_by_id('middle') or { panic('missing middle') }
	inner_element := document.get_element_by_id('inner') or { panic('missing inner') }
	outer := root.find_box(i64(outer_element.as_node().unique_id())) or {
		panic('missing outer box')
	}
	middle := root.find_box(i64(middle_element.as_node().unique_id())) or {
		panic('missing middle box')
	}
	inner := root.find_box(i64(inner_element.as_node().unique_id())) or {
		panic('missing inner box')
	}
	assert outer.paint_transform == [f64(1), 0, 0, 1, 10, 0]!
	assert middle.paint_transform == [f64(1), 0, 0, 1, 10, 20]!
	assert inner.paint_transform == [f64(2), 0, 0, 2, 10, 20]!
}

fn test_paintable_box_coordinate_bridge_uses_accumulated_visual_context() {
	mut tree := painting.new_accumulated_visual_context_tree()
	transform := tree.append(painting.TransformVisualData{
		matrix: painting.Affine{
			a: 2
			d: 2
		}
	}, 0)
	scroll := tree.append(painting.ScrollVisualData{
		scroll_frame_index: 1
	}, transform)
	clip := tree.append(painting.ClipVisualData{
		rect: painting.IntRect{0, 0, 100, 100}
	}, scroll)
	snapshot := painting.ScrollStateSnapshot{
		device_offsets: [painting.Point{}, painting.Point{-4, -6}]
	}
	mut box := BlockBox{}
	box.accumulated_visual_context_index = transform
	box.accumulated_visual_context_for_descendants_idx = clip
	local_point := paintable_box_transform_point_to_local(&box, painting.Point{40, 40}, 1, tree, snapshot) or { panic('missing local coordinate') }
	assert local_point == painting.Point{20, 20}
	descendant_point := paintable_box_transform_point_to_local_for_descendants(&box, painting.Point{40, 40}, 1, tree, snapshot) or {
		panic('missing descendant coordinate')
	}
	assert descendant_point == painting.Point{24, 26}
	double_density_descendant_point := paintable_box_transform_point_to_local_for_descendants(&box, painting.Point{40, 40}, 2, tree, snapshot) or {
		panic('missing double-density descendant coordinate')
	}
	// Scroll snapshots are already in device pixels, so their CSS-pixel effect
	// shrinks as the device scale increases.
	assert double_density_descendant_point == painting.Point{22, 23}
	assert paintable_box_inverse_transform_point(&box, painting.Point{40, 40}, 1, tree) == painting.Point{20, 20}
	assert paintable_box_transform_rect_to_viewport(&box, LayoutRect{10, 20, 5, 10}, 1, tree, snapshot) == LayoutRect{20, 40, 10, 20}

	box.accumulated_visual_context_index = scroll
	assert paintable_box_transform_rect_to_viewport(&box, LayoutRect{10, 20, 5, 10}, 1, tree, snapshot) == LayoutRect{12, 28, 10, 20}
	box.accumulated_visual_context_index = clip
	assert paintable_box_transform_point_to_local(&box, painting.Point{500, 500}, 1, tree, snapshot) == none
	assert paintable_box_transform_to_local_coordinates(&box, painting.Point{500, 500}, 1, tree, snapshot) == painting.Point{500, 500}

	// The zero context is the upstream sentinel and bypasses float/device-pixel
	// conversion entirely.
	box.accumulated_visual_context_index = 0
	identity_point := paintable_box_transform_point_to_local(&box, painting.Point{0.1, 0.2}, 2, tree, snapshot) or { panic('missing identity coordinate') }
	assert identity_point == painting.Point{0.1, 0.2}
}

fn test_transform_box_uses_content_or_border_reference_for_css_boxes() {
	document := html.parse_document('<!doctype html><style>html, body { margin: 0 } .target { position: absolute; top: 0; width: 40px; height: 20px; padding: 5px; border: 10px solid black; transform: scale(2); transform-origin: 0 0 } #content { left: 0; transform-box: content-box } #border { left: 100px; transform-box: border-box }</style><body><div id="content" class="target"></div><div id="border" class="target"></div></body>')
	root := layout_document_typed_in_viewport(document, 320, 200)
	content_element := document.get_element_by_id('content') or { panic('missing content box') }
	border_element := document.get_element_by_id('border') or { panic('missing border box') }
	content := root.find_box(i64(content_element.as_node().unique_id())) or {
		panic('missing content paint box')
	}
	border := root.find_box(i64(border_element.as_node().unique_id())) or {
		panic('missing border paint box')
	}
	assert content.own_paint_transform == [f64(2), 0, 0, 2, -15, -15]!
	assert border.own_paint_transform == [f64(2), 0, 0, 2, -100, 0]!
}

fn test_transform_box_uses_nearest_svg_viewport_reference() {
	document := html.parse_document('<!doctype html><style>html, body, svg { margin: 0; display: block } .target { transform: scale(2); transform-origin: 0 0 }</style><body><svg width="200" height="100"><rect id="fill" class="target" style="transform-box: fill-box" x="10" y="10" width="10" height="10" fill="red"/><rect id="view" class="target" style="transform-box: view-box" x="10" y="40" width="10" height="10" fill="blue"/></svg></body>')
	root := layout_document_typed_in_viewport(document, 320, 200)
	fill_element := document.get_element_by_id('fill') or { panic('missing fill-box rect') }
	view_element := document.get_element_by_id('view') or { panic('missing view-box rect') }
	fill := root.find_box(i64(fill_element.as_node().unique_id())) or {
		panic('missing fill paint box')
	}
	view := root.find_box(i64(view_element.as_node().unique_id())) or {
		panic('missing view paint box')
	}
	assert fill.own_paint_transform == [f64(2), 0, 0, 2, -10, -10]!
	assert view.own_paint_transform == [f64(2), 0, 0, 2, 0, 0]!
}

fn test_individual_transforms_compose_before_transform_list_against_reference_box() {
	document := html.parse_document('<!doctype html><style>html, body { margin: 0 } #target { position: absolute; width: 40px; height: 20px; padding: 5px; border: 10px solid black; transform-box: content-box; translate: 100% 50%; rotate: 90deg; scale: 2; transform: translateX(5px); transform-origin: 0 0 }</style><body><div id="target"></div></body>')
	root := layout_document_typed_in_viewport(document, 320, 200)
	element := document.get_element_by_id('target') or { panic('missing transform target') }
	target := root.find_box(i64(element.as_node().unique_id())) or {
		panic('missing transform paint box')
	}
	matrix := target.own_paint_transform
	assert math.abs(matrix[0]) < 0.000001
	assert math.abs(matrix[1] - 2) < 0.000001
	assert math.abs(matrix[2] + 2) < 0.000001
	assert math.abs(matrix[3]) < 0.000001
	assert math.abs(matrix[4] - 85) < 0.000001
	assert math.abs(matrix[5] - 5) < 0.000001
}

fn test_backface_visibility_builds_a_culled_3d_visual_context() {
	document := html.parse_document('<!doctype html><style>html,body{margin:0}#scene{transform-style:preserve-3d}#target{width:100px;height:100px;background:red;transform:rotateY(180deg);backface-visibility:hidden}</style><body><div id="scene"><div id="target"></div></div></body>')
	mut root := layout_document_typed_in_viewport(document, 200, 120)
	mut boxes_by_layout := map[u64]&BlockBox{}
	collect_compatibility_boxes(mut root, mut boxes_by_layout)
	mut tree := painting.new_accumulated_visual_context_tree()
	assign_compatibility_visual_contexts(mut root, none, boxes_by_layout, mut tree)
	target_element := document.get_element_by_id('target') or { panic('missing target') }
	target := root.find_box(i64(target_element.as_node().unique_id())) or {
		panic('missing target paint box')
	}
	assert target.uses_own_paint_transform_4x4
	assert math.abs(target.own_paint_transform_4x4.m33 + 1) < 0.000001
	assert tree.context_is_backface_culled(target.accumulated_visual_context_index, painting.ScrollStateSnapshot{})
	assert paintable_box_transform_point_to_local(&target, painting.Point{50, 50}, 1, tree, painting.ScrollStateSnapshot{}) == none
}

fn test_animated_transform_updates_backface_culling() {
	mut document := html.parse_document('<!doctype html><style>html,body{margin:0}@keyframes flip{0%{transform:rotateY(60deg)}0.01%,100%{transform:rotateY(180deg)}}.flip{animation:10s linear infinite flip}#scene{width:100px;height:100px;transform:rotateY(60deg);transform-style:preserve-3d}#target{width:100px;height:100px;background:lightblue;transform:rotateY(180deg);backface-visibility:hidden}</style><div id="scene"><div id="target"></div></div>')
	mut root := layout_document_typed_in_viewport(document, 200, 120)
	assert !css.document_has_running_css_animations(document)
	target_element := document.get_element_by_id('target') or { panic('missing target') }
	mut scene_element := document.get_element_by_id('scene') or { panic('missing scene') }
	mut target := root.find_box(i64(target_element.as_node().unique_id())) or {
		panic('missing target paint box')
	}
	mut boxes_by_layout := map[u64]&BlockBox{}
	collect_compatibility_boxes(mut root, mut boxes_by_layout)
	mut tree := painting.new_accumulated_visual_context_tree()
	assign_compatibility_visual_contexts(mut root, none, boxes_by_layout, mut tree)
	assert tree.context_is_backface_culled(target.accumulated_visual_context_index, painting.ScrollStateSnapshot{})

	scene_element.set_attribute_value('class', 'flip')
	root = layout_document_typed_in_viewport(document, 200, 120)
	assert css.document_has_running_css_animations(document)
	document.update_animations_and_send_events(16)
	root = layout_document_typed_in_viewport(document, 200, 120)
	scene := root.find_box(i64(scene_element.as_node().unique_id())) or {
		panic('missing animated scene paint box')
	}
	assert scene.own_paint_transform_4x4.m33 < -0.9
	target = root.find_box(i64(target_element.as_node().unique_id())) or {
		panic('missing updated target paint box')
	}
	boxes_by_layout = map[u64]&BlockBox{}
	collect_compatibility_boxes(mut root, mut boxes_by_layout)
	tree = painting.new_accumulated_visual_context_tree()
	assign_compatibility_visual_contexts(mut root, none, boxes_by_layout, mut tree)
	assert !tree.context_is_backface_culled(target.accumulated_visual_context_index, painting.ScrollStateSnapshot{})
}

fn test_hidden_backface_in_3d_context_establishes_descendant_containing_blocks() {
	document := html.parse_document('<!doctype html><style>#scene{transform-style:preserve-3d}#target{backface-visibility:hidden}#fixed{position:fixed}</style><div id="scene"><div id="target"><div id="fixed"></div></div></div>')
	result := run_document_layout(document, 200, 120) or { panic('layout failed') }
	target := typed_paint_node_with_id(result.root, 'target') or { panic('missing target') }
	fixed := typed_paint_node_with_id(result.root, 'fixed') or { panic('missing fixed') }
	assert target.is_transformable()
	assert target.participates_in_a_3d_rendering_context()
	assert target.establishes_stacking_context()
	containing_block := fixed.containing_block() or { panic('missing fixed containing block') }
	assert voidptr(containing_block) == voidptr(target)
}

fn test_hidden_backface_ancestor_culls_only_its_own_3d_plane() {
	document := html.parse_document('<!doctype html><style>html,body{margin:0}.scene{transform-style:preserve-3d;transform:rotateY(142deg)}.wrapper{width:100px;height:100px;transform-style:preserve-3d;backface-visibility:hidden;background:red}.card{width:100px;height:100px;background:green;transform:rotateY(-142deg);backface-visibility:hidden}</style><div class="scene"><div id="wrapper" class="wrapper"><div id="card" class="card"></div></div></div>')
	mut root := layout_document_typed_in_viewport(document, 400, 400)
	mut boxes_by_layout := map[u64]&BlockBox{}
	collect_compatibility_boxes(mut root, mut boxes_by_layout)
	mut tree := painting.new_accumulated_visual_context_tree()
	assign_compatibility_visual_contexts(mut root, none, boxes_by_layout, mut tree)
	wrapper_element := document.get_element_by_id('wrapper') or { panic('missing wrapper') }
	card_element := document.get_element_by_id('card') or { panic('missing card') }
	wrapper := root.find_box(i64(wrapper_element.as_node().unique_id())) or {
		panic('missing wrapper paint box')
	}
	card := root.find_box(i64(card_element.as_node().unique_id())) or {
		panic('missing card paint box')
	}
	assert tree.context_is_backface_culled(wrapper.accumulated_visual_context_index, painting.ScrollStateSnapshot{})
	assert !tree.context_is_backface_culled(card.accumulated_visual_context_index, painting.ScrollStateSnapshot{})
}

fn test_hidden_backface_ancestor_keeps_descendant_3d_contexts() {
	document := html.parse_document('<!doctype html><style>html,body{margin:0}.flipped{width:300px;height:300px;background:blue;transform:rotateY(180deg);backface-visibility:hidden}.context{transform-style:preserve-3d;width:200px;height:200px;background:green}.participant{width:100px;height:100px;background:orange;transform:translateZ(10px)}.lone-context{width:60px;height:60px;background:purple;transform-style:preserve-3d}</style><div id="flipped" class="flipped"><div id="context" class="context"><div id="participant" class="participant"></div></div><div id="lone-context" class="lone-context"></div></div>')
	mut root := layout_document_typed_in_viewport(document, 400, 400)
	mut boxes_by_layout := map[u64]&BlockBox{}
	collect_compatibility_boxes(mut root, mut boxes_by_layout)
	mut tree := painting.new_accumulated_visual_context_tree()
	assign_compatibility_visual_contexts(mut root, none, boxes_by_layout, mut tree)
	for id in ['flipped', 'context', 'participant', 'lone-context'] {
		element := document.get_element_by_id(id) or { panic('missing ${id}') }
		box := root.find_box(i64(element.as_node().unique_id())) or {
			panic('missing ${id} paint box')
		}
		culled := tree.context_is_backface_culled(box.accumulated_visual_context_index, painting.ScrollStateSnapshot{})
		assert culled == (id == 'flipped')
	}
}

fn test_typed_paint_adapter_preserves_large_committed_text_fragment() {
	text := ('word '.repeat(2048)).trim_space()
	document := html.parse_document('<!doctype html><style>html, body { margin: 0 } #text { white-space: nowrap }</style><body><p id="text">${text}</p></body>')
	root := layout_document_typed_in_viewport(document, 320, 200)
	element := document.get_element_by_id('text') or { panic('missing text element') }
	paragraph := root.find_box(i64(element.as_node().unique_id())) or {
		panic('missing text box')
	}
	assert paragraph.lines.len == 1
	assert paragraph.lines[0].fragments.len == 1
	assert paragraph.lines[0].fragments[0].text == text
	draws := root.paint_commands().filter(it.kind == 'draw_text' && it.text == text)
	assert draws.len == 1
}

fn test_typed_paint_adapter_keeps_retained_run_across_default_ignorables() {
	plain_text := 'Search in r/programming'
	isolated_text := 'Search in ⁨r/programming⁩'
	document := html.parse_document('<!doctype html><style>html,body{margin:0}div{font:24px Arial}</style><div>${plain_text}</div><div>${isolated_text}</div>')
	root := layout_document_typed_in_viewport(document, 500, 200)
	draws := root.paint_commands().filter(it.kind == 'draw_text'
		&& it.text in [plain_text, isolated_text])
	assert draws.len == 2
	plain_run := draws.filter(it.text == plain_text)[0].glyph_run or {
		panic('plain text lost its retained glyph run')
	}
	isolated_run := draws.filter(it.text == isolated_text)[0].glyph_run or {
		panic('isolated text fell back to raw-string painting')
	}
	assert isolated_run.glyph_indices() == plain_run.glyph_indices()
	assert isolated_run.glyph_positions() == plain_run.glyph_positions()
}

fn test_box_shadows_follow_source_order_rectangles_and_elliptical_radii() {
	document := html.parse_document('<!doctype html><style>
		html, body { margin: 0 }
		#target { width: 100px; height: 50px; padding: 4px; border: 3px solid black;
			border-radius: 10px 20px 30px 40px / 5px 10px 15px 20px;
			background: rgb(0 200 0);
			box-shadow: 1px 2px 3px 2px rgb(200 0 0),
				inset 4px 5px 6px 1px rgb(0 0 200) }
	</style><body><div id="target"></div></body>')
	root := layout_document_typed_in_viewport(document, 320, 200)
	commands := root.paint_commands()
	mut background_index := -1
	mut inner_index := -1
	mut outer_index := -1
	for index, command in commands {
		if command.kind == 'fill_rounded_rect' && command.color == 'rgb(0 200 0)' {
			background_index = index
		} else if command.kind == 'paint_inner_box_shadow' && command.color == 'rgb(0 0 200)' {
			inner_index = index
		} else if command.kind == 'paint_outer_box_shadow' && command.color == 'rgb(200 0 0)' {
			outer_index = index
		}
	}
	assert background_index >= 0
	assert inner_index > background_index
	assert outer_index > inner_index
	inner := commands[inner_index]
	outer := commands[outer_index]
	// Inner shadows use the padding box; outer shadows use the border box.
	assert inner.box_shadow().content_rect.width == 108
	assert inner.box_shadow().content_rect.height == 58
	assert outer.box_shadow().content_rect.width == 114
	assert outer.box_shadow().content_rect.height == 64
	assert outer.corner_radii.top_left != outer.corner_radii.bottom_left
	assert outer.corner_radii.top_left.x != outer.corner_radii.top_left.y
	assert inner.box_shadow().inner_radii.top_right != inner.box_shadow().inner_radii.bottom_right
	svg := root.render_svg(320, 200)
	assert svg.contains('outer-shadow-clip')
	assert svg.contains('inner-shadow-scoped')
	assert svg.contains('fill-rule="evenodd"')
}

fn test_document_viewport_paintable_records_and_hit_tests_committed_layout() {
	document := html.parse_document('<!doctype html><style>html, body { margin: 0 } #target { position: relative; z-index: 2; width: 120px; height: 60px; background: red }</style><body><div id="target"></div></body>')
	root := layout_document_typed_in_viewport(document, 320, 200)
	target := document.get_element_by_id('target') or { panic('missing target') }

	viewport := document.layout_node() or { panic('missing retained layout viewport') }
	assert viewport.root_layout_node() != none
	viewport_paintable := document.paintable() or { panic('missing viewport paintable') }
	mut mutable_document := unsafe { &dom.Document(document) }
	display_list := record_retained_display_list(mut mutable_document) or { panic('missing display list') }
	commands := display_list_commands(display_list)
	assert commands.len == display_list.command_count()
	assert commands.len == root.paint_commands().len
	assert commands.any(it.kind == 'fill_rect' && it.color == 'rgb(255 0 0)')

	hit := mutable_document.element_from_point(10, 10) or { panic('missing hit') }
	assert hit == target
	hits := mutable_document.elements_from_point(10, 10)
	assert hits.len >= 1
	assert hits[0] == target
	viewport_paintable.build_stacking_context_tree_if_needed()
	stacking_context := viewport_paintable.stacking_context() or {
		panic('missing stacking context')
	}
	dump_text := stacking_context.dump()
	assert dump_text.contains('SC for')
	assert dump_text.contains(target.as_node().debug_description())
}

fn test_document_display_list_retains_one_stacking_plan_and_command_store() {
	document := html.parse_document('<!doctype html><style>html, body { margin: 0 } .front { position: relative; z-index: 2 }</style><body><div id="back">back</div><div id="front" class="front">front</div></body>')
	_ := layout_document_typed_in_viewport(document, 320, 200)
	mut mutable_document := unsafe { &dom.Document(document) }
	display_list := record_retained_display_list(mut mutable_document) or { panic('missing display list') }
	result := document_layout_result(document) or { panic('missing layout result') }
	assert result.stacking_context_tree_is_valid
	assert result.paint_order.len > 0
	assert result.paint_steps.len > result.paint_order.len
	assert result.hit_test_order.len == result.paint_order.len
	assert result.paint_phase_cache_valid
	assert result.paint_phase_commands.len == result.paint_order.len * compatibility_paint_phase_count
	assert result.paint_phase_entry_valid.len == result.paint_order.len
	assert result.paint_phase_entry_valid.all(it)
	for index, entry in result.paint_order {
		assert result.hit_test_order[index] == entry.box
	}

	first_commands := display_list_commands(display_list)
	second_commands := display_list_commands(display_list)
	assert first_commands.len > 0
	assert first_commands.data == second_commands.data
	paint_order_data := result.paint_order.data
	paint_steps_data := result.paint_steps.data
	paint_phase_commands_data := result.paint_phase_commands.data
	paintable := document.paintable_box() or { panic('missing viewport paintable') }
	assert result.hit_test_display_list_is_valid

	// Document::set_needs_repaint() invalidates the assembled display list, not
	// the source-shaped stacking tree or any PaintableBox phase cache. Its
	// default full mode does invalidate the independently retained hit-test plan.
	mutable_document.set_needs_repaint()
	assert mutable_document.cached_display_list() == none
	assert !result.hit_test_display_list_is_valid
	_ = record_retained_display_list(mut mutable_document) or { panic('missing repainted display list') }
	assert result.hit_test_display_list_is_valid
	assert result.paint_order.data == paint_order_data
	assert result.paint_steps.data == paint_steps_data
	assert result.paint_phase_commands.data == paint_phase_commands_data
	assert result.paint_phase_entry_valid.all(it)

	// PaintableBox::set_needs_repaint() invalidates that box's phase vectors and
	// its anonymous children before forwarding to Document. The viewport is the
	// root paintable in this module-cycle bridge.
	paintable.set_needs_repaint()
	mut root_entry_index := -1
	for index, entry in result.paint_order {
		if entry.box == &result.paint_tree {
			root_entry_index = index
			break
		}
	}
	assert root_entry_index >= 0
	assert !result.paint_phase_entry_valid[root_entry_index]
	_ = record_retained_display_list(mut mutable_document) or { panic('missing box-invalidated display list') }
	assert result.paint_phase_entry_valid.all(it)
	assert result.paint_phase_commands.data == paint_phase_commands_data

	// Node::set_needs_repaint() reaches the concrete child PaintableBox cache,
	// not just the viewport bridge. Other retained paintables stay valid.
	front := document.get_element_by_id('front') or { panic('missing front element') }
	mut front_paintable := front.paintable_box() or { panic('missing front paintable') }
	mut front_entry_index := -1
	mut containing_block_entry_index := -1
	front_layout_node := unsafe { &Node(front_paintable.layout_handle) }
	front_containing_block := front_layout_node.containing_block() or {
		panic('missing front containing block')
	}
	front_containing_block_handle := voidptr(unsafe { &Node(front_containing_block) })
	for index, entry in result.paint_order {
		if entry.box.layout_handle == front_paintable.layout_handle {
			front_entry_index = index
		}
		if entry.box.layout_handle == front_containing_block_handle {
			containing_block_entry_index = index
		}
	}
	assert front_entry_index >= 0
	assert containing_block_entry_index >= 0
	front_paintable.set_needs_repaint(.paint_commands_and_hit_test_list)
	assert mutable_document.cached_display_list() == none
	assert !result.hit_test_display_list_is_valid
	assert !result.paint_phase_entry_valid[front_entry_index]
	assert !result.paint_phase_entry_valid[containing_block_entry_index]
	assert result.paint_phase_entry_valid[root_entry_index]
	_ = record_retained_display_list(mut mutable_document) or { panic('missing child-invalidated display list') }
	assert result.hit_test_display_list_is_valid
	assert result.paint_phase_entry_valid.all(it)
	assert result.paint_phase_commands.data == paint_phase_commands_data

	// A paint-command-only repaint refreshes the target's phase cache while
	// preserving the hit-test plan for input events before the next frame.
	front_paintable.set_needs_repaint(.paint_commands)
	assert mutable_document.cached_display_list() == none
	assert result.hit_test_display_list_is_valid
	assert !result.paint_phase_entry_valid[front_entry_index]
	_ = record_retained_display_list(mut mutable_document) or { panic('missing paint-only display list') }
	assert result.hit_test_display_list_is_valid

	// Full invalidation discards every phase record while keeping private
	// bucket storage for the next recording from the retained paintables.
	paintable.invalidate_all_paint_caches()
	assert !result.paint_phase_cache_valid
	assert result.paint_phase_commands.data == paint_phase_commands_data
	assert result.paint_phase_commands.len == result.paint_order.len * compatibility_paint_phase_count
	assert result.paint_phase_commands.all(it.len == 0)
	assert result.paint_phase_entry_valid.len == 0
	mutable_document.set_needs_repaint()
	_ = record_retained_display_list(mut mutable_document) or { panic('missing uncached display list') }
	assert result.paint_phase_cache_valid
	assert result.paint_phase_commands.len == result.paint_order.len * compatibility_paint_phase_count
}

fn test_paint_only_style_change_keeps_hit_test_display_list() {
	document := html.parse_document('<!doctype html><style>
		html, body { margin: 0 }
		#box { position: absolute; width: 100px; height: 100px; background: green }
	</style><body><div id="box"></div></body>')
	_ = layout_document_typed_in_viewport(document, 320, 200)
	box := document.get_element_by_id('box') or { panic('missing box') }
	mut mutable_document := unsafe { &dom.Document(document) }
	_ = record_retained_display_list(mut mutable_document) or { panic('missing initial display list') }
	initial_hit := mutable_document.element_from_point(50, 50) or { panic('missing initial hit') }
	assert initial_hit.as_node().unique_id() == box.as_node().unique_id()
	mut result := document_layout_result(document) or { panic('missing layout result') }
	assert result.hit_test_display_list_is_valid

	mut mutable_box := unsafe { &dom.Element(box) }
	mutable_box.set_attribute_value('style', 'background-color: blue')
	_ = layout_document_typed_in_viewport(document, 320, 200)
	result = document_layout_result(document) or { panic('missing refreshed layout result') }
	assert result.hit_test_display_list_is_valid
	assert mutable_document.cached_display_list() == none
	paint_only_hit := mutable_document.element_from_point(50, 50) or {
		panic('missing paint-only hit')
	}
	assert paint_only_hit.as_node().unique_id() == box.as_node().unique_id()
	assert result.hit_test_display_list_is_valid

	_ = record_retained_display_list(mut mutable_document) or { panic('missing refreshed display list') }
	mutable_box.set_attribute_value('style', 'pointer-events: none')
	_ = layout_document_typed_in_viewport(document, 320, 200)
	result = document_layout_result(document) or { panic('missing hit-test-invalidated result') }
	assert !result.hit_test_display_list_is_valid
	hit_test_change_hit := mutable_document.element_from_point(50, 50) or {
		panic('missing fallback hit')
	}
	assert hit_test_change_hit.local_name() != 'div'
	assert result.hit_test_display_list_is_valid
}

fn test_document_hit_testing_reuses_paint_order_and_maps_transforms_to_local_space() {
	document := html.parse_document('<!doctype html><style>
		html, body { margin: 0 }
		#under { position: absolute; left: 0; top: 0; z-index: 1; width: 20px; height: 20px; transform: translateX(100px); transform-origin: 0 0 }
		#cover { position: absolute; left: 100px; top: 0; z-index: 2; width: 20px; height: 20px; pointer-events: none }
		#flat { position: absolute; left: 100px; top: 0; z-index: 3; width: 20px; height: 20px; transform: matrix(0, 0, 0, 0, 100, 0); transform-origin: 0 0 }
	</style><body><div id="under"></div><div id="cover"></div><div id="flat"></div></body>')
	_ = layout_document_typed_in_viewport(document, 320, 200)
	under := document.get_element_by_id('under') or { panic('missing under') }
	result := document_layout_result(document) or { panic('missing layout result') }
	assert result.hit_test_order.len == 0

	mut mutable_document := unsafe { &dom.Document(document) }
	hit := mutable_document.element_from_point(105, 10) or { panic('missing transformed hit') }
	assert hit.as_node().unique_id() == under.as_node().unique_id()
	assert result.hit_test_order.len > 0
	retained_count := result.hit_test_order.len
	second_hit := mutable_document.element_from_point(105, 10) or { panic('missing repeated hit') }
	assert second_hit.as_node().unique_id() == under.as_node().unique_id()
	assert result.hit_test_order.len == retained_count

	mutable_document.invalidate_stacking_context_tree()
	assert result.hit_test_order.len == 0
	rebuilt_hit := mutable_document.element_from_point(105, 10) or { panic('missing rebuilt hit') }
	assert rebuilt_hit.as_node().unique_id() == under.as_node().unique_id()
	assert result.hit_test_order.len == retained_count
}

fn test_stacking_context_hit_test_keeps_zero_opacity_and_skips_noninvertible_contexts() {
	document := html.parse_document('<!doctype html><style>
		html, body { margin: 0 }
		#under { position: absolute; z-index: 1; width: 100px; height: 100px }
		#transparent { position: absolute; z-index: 2; width: 40px; height: 40px; opacity: 0 }
		#flat { position: absolute; z-index: 3; width: 40px; height: 40px; transform: matrix(0, 0, 0, 0, 10, 70); transform-origin: 0 0 }
	</style><body><div id="under"></div><div id="transparent"></div><div id="flat"></div></body>')
	_ = layout_document_typed_in_viewport(document, 320, 200)
	under := document.get_element_by_id('under') or { panic('missing opacity underlay') }
	transparent := document.get_element_by_id('transparent') or {
		panic('missing transparent context')
	}
	flat := document.get_element_by_id('flat') or { panic('missing noninvertible context') }
	mut mutable_document := unsafe { &dom.Document(document) }
	transparent_hit := mutable_document.element_from_point(10, 10) or {
		panic('missing transparent hit')
	}
	assert transparent_hit.as_node().unique_id() == transparent.as_node().unique_id()
	flat_hit := mutable_document.element_from_point(10, 70) or {
		panic('missing noninvertible fallback hit')
	}
	assert flat_hit.as_node().unique_id() == under.as_node().unique_id()

	result := document_layout_result(document) or { panic('missing hit phase plans') }
	transparent_id := i64(transparent.as_node().unique_id())
	flat_id := i64(flat.as_node().unique_id())
	assert result.paint_steps.all(it.box.node_id != transparent_id)
	assert result.hit_test_steps.any(it.box.node_id == transparent_id)
	assert result.hit_test_steps.all(it.box.node_id != flat_id)
}

fn test_document_hit_testing_preserves_stacking_context_rounded_corner_distinction() {
	document := html.parse_document('<!doctype html><style>
		html, body { margin: 0 }
		#under { position: absolute; z-index: 1; width: 100px; height: 100px; background: blue }
		#rounded { position: absolute; z-index: 2; width: 100px; height: 100px; border-radius: 50px; background: red }
	</style><body><div id="under"></div><div id="rounded"></div></body>')
	_ = layout_document_typed_in_viewport(document, 320, 200)
	rounded := document.get_element_by_id('rounded') or { panic('missing rounded element') }
	mut mutable_document := unsafe { &dom.Document(document) }
	corner_hit := mutable_document.element_from_point(1, 1) or { panic('missing corner hit') }
	// StackingContext::hit_test() uses its root's border rectangle directly.
	assert corner_hit.as_node().unique_id() == rounded.as_node().unique_id()
	center_hit := mutable_document.element_from_point(50, 50) or { panic('missing center hit') }
	assert center_hit.as_node().unique_id() == rounded.as_node().unique_id()

	non_context_document := html.parse_document('<!doctype html><style>
		html, body { margin: 0 }
		#under { position: absolute; z-index: -1; width: 100px; height: 100px; background: blue }
		#rounded { position: absolute; width: 100px; height: 100px; border-radius: 50px; background: red }
	</style><body><div id="under"></div><div id="rounded"></div></body>')
	_ = layout_document_typed_in_viewport(non_context_document, 320, 200)
	non_context_under := non_context_document.get_element_by_id('under') or {
		panic('missing non-context underlay')
	}
	mut mutable_non_context_document := unsafe { &dom.Document(non_context_document) }
	non_context_corner := mutable_non_context_document.element_from_point(1, 1) or {
		panic('missing non-context corner hit')
	}
	// PaintableBox::hit_test() applies the normalized radii before its callback.
	assert non_context_corner.as_node().unique_id() == non_context_under.as_node().unique_id()
}

fn test_document_hit_testing_skips_inert_paintables() {
	document := html.parse_document('<!doctype html><style>
		html, body { margin: 0 }
		#under { position: absolute; z-index: 1; width: 100px; height: 100px; background: blue }
		#inert { position: absolute; z-index: 2; width: 100px; height: 100px; background: red }
	</style><body><div id="under"></div><div id="inert" inert></div></body>')
	_ = layout_document_typed_in_viewport(document, 320, 200)
	under := document.get_element_by_id('under') or { panic('missing underlying element') }
	mut mutable_document := unsafe { &dom.Document(document) }
	hit := mutable_document.element_from_point(10, 10) or { panic('missing inert-filtered hit') }
	assert hit.as_node().unique_id() == under.as_node().unique_id()
}

fn test_paintable_with_lines_hit_testing_returns_text_node_and_utf16_cursor_index() {
	document := html.parse_document('<!doctype html><style>
		html, body, p { margin: 0 }
		p { width: 220px; line-height: 20px }
	</style><body><p id="target" contenteditable>a😀bc</p></body>')
	root := layout_document_typed_in_viewport(document, 240, 100)
	target := document.get_element_by_id('target') or { panic('missing hit-test target') }
	text_node := target.as_node().first_child() or { panic('missing hit-test text') }
	target_box := root.find_box(i64(target.as_node().unique_id())) or {
		panic('missing hit-test paint box')
	}
	assert target_box.lines.len == 1
	// The emoji has the Common bidi class and is therefore its own shaping run
	// between the two LTR runs. Hit testing still addresses the shared DOM text
	// node in UTF-16 code units across all three fragments.
	assert target_box.lines[0].fragments.len == 3
	assert target_box.lines[0].fragments.map(it.paintable_fragment.length_in_code_units) == [
		1,
		2,
		2,
	]
	assert target_box.lines[0].fragments.all(it.paintable_fragment.text_value == 'a😀bc')
	fragment := target_box.lines[0].fragments[1]
	fragment_rect := fragment.paintable_fragment.absolute_rect()
	inside_point := painting.Point{fragment_rect.x + fragment_rect.width / 2, fragment_rect.y + fragment_rect.height / 2}
	viewport := document.paintable_box() or { panic('missing viewport paintable') }
	inside := viewport.hit_test(inside_point.x, inside_point.y, .exact) or {
		panic('missing exact fragment hit')
	}
	assert inside.node == text_node
	assert inside.element == target
	assert inside.index_in_node == fragment.paintable_fragment.index_in_node_for_point(inside_point)
	assert (inside.vertical_distance or { panic('missing exact vertical distance') }) == 0
	assert (inside.horizontal_distance or { panic('missing exact horizontal distance') }) == 0

	mut selection := document.get_selection() or { panic('missing hit-test selection') }
	selection.collapse(text_node, 2) or { panic(err) }
	last_fragment := target_box.lines[0].fragments.last()
	last_fragment_rect := last_fragment.paintable_fragment.absolute_rect()
	beyond_x := last_fragment_rect.right() + 12
	beyond := viewport.hit_test(beyond_x, inside_point.y, .text_cursor) or {
		panic('missing nearest text cursor hit')
	}
	assert beyond.node == text_node
	assert beyond.index_in_node == last_fragment.paintable_fragment.start_offset + last_fragment.paintable_fragment.length_in_code_units
	assert (beyond.vertical_distance or { panic('missing cursor vertical distance') }) == 0
	assert (beyond.horizontal_distance or { panic('missing cursor horizontal distance') }) == 12
}

fn test_selection_scrolls_cursor_into_nearest_overflow_ancestor() {
	document := html.parse_document('<!doctype html><style>html, body { margin: 0 } #scroller { width: 90px; height: 30px; overflow: auto } #target { margin: 0; width: 70px; line-height: 20px }</style><body><div id="scroller"><p id="target" contenteditable>one two three four five six seven eight nine ten</p></div></body>')
	_ = layout_document_typed_in_viewport(document, 240, 140)
	scroller := document.get_element_by_id('scroller') or { panic('missing scroller') }
	target := document.get_element_by_id('target') or { panic('missing editable target') }
	text_node := target.as_node().first_child() or { panic('missing editable text node') }
	assert scroller.el_scroll_offset().y() == 0

	mut selection := document.get_selection() or { panic('missing selection') }
	selection.collapse(text_node, text_node.length()) or { panic(err) }
	selection.scroll_focus_into_view()
	assert scroller.el_scroll_offset().y() > 0
}

fn test_textarea_scrolls_its_anonymous_cursor_into_view() {
	document := html.parse_document('<!doctype html><style>html, body { margin: 0 } textarea { display: block; box-sizing: border-box; width: 90px; height: 34px; overflow: auto; line-height: 20px }</style><body><textarea id="control">one two three four five six seven eight nine ten</textarea></body>')
	control := document.get_element_by_id('control') or { panic('missing textarea') }
	mut textarea := html.HTMLTextAreaElementModel.create(unsafe { &dom.HTMLTextAreaElement(control) })
	textarea.create_shadow_tree_if_needed()
	_ = layout_document_typed_in_viewport(document, 240, 140)
	assert control.el_scroll_offset().y() == 0

	textarea.text.scroll_cursor_into_view()
	assert control.el_scroll_offset().y() > 0
}

fn test_input_cursor_scroll_keeps_the_block_axis_stable() {
	document := html.parse_document('<!doctype html><style>html, body { margin:0 } input { display:block;box-sizing:border-box;font:15px/15px monospace;width:70px;height:38px;padding:7px 10px 10px 0;border:0 } #vertical { writing-mode:vertical-rl;width:38px;height:8px;padding:0 }</style><body><input id="horizontal" value="xxxxxxxxxxxxxxxx"><input id="vertical" value="xxxxxxxxxxxxxxxx"></body>')
	horizontal_element := document.get_element_by_id('horizontal') or { panic('missing horizontal input') }
	mut horizontal := html.HTMLInputElementModel.create(unsafe {
		&dom.HTMLInputElement(horizontal_element)
	})
	horizontal.text_control.set_selection_range(16, 16, 'none') or { panic(err) }
	vertical_element := document.get_element_by_id('vertical') or { panic('missing vertical input') }
	mut vertical := html.HTMLInputElementModel.create(unsafe { &dom.HTMLInputElement(vertical_element) })
	vertical.text_control.set_selection_range(16, 16, 'none') or { panic(err) }
	_ = layout_document_typed_in_viewport(document, 240, 140)

	horizontal.text_control.scroll_cursor_into_view()
	assert horizontal_element.el_scroll_offset().x() > 0
	assert horizontal_element.el_scroll_offset().y() == 0
	vertical.text_control.scroll_cursor_into_view()
	assert vertical_element.el_scroll_offset().y() > 0
	assert vertical_element.el_scroll_offset().x() == 0
}

fn test_selection_scrolls_cursor_into_viewport() {
	document := html.parse_document('<!doctype html><style>html, body, p { margin: 0 } p { width: 80px; line-height: 20px }</style><body><p id="target" contenteditable>one two three four five six seven eight nine ten eleven twelve</p></body>')
	mut mutable_document := unsafe { &dom.Document(document) }
	host := &dom.Navigable{
		active_document_: document
	}
	_ := html.NavigableModel.create(host, none) or { panic(err) }
	mutable_document.set_cached_navigable(host)
	_ = layout_document_typed_in_viewport(document, 100, 40)
	target := document.get_element_by_id('target') or { panic('missing viewport target') }
	text_node := target.as_node().first_child() or { panic('missing viewport text') }
	assert document.viewport_rect().y == 0

	mut selection := document.get_selection() or { panic('missing viewport selection') }
	selection.collapse(text_node, text_node.length()) or { panic(err) }
	selection.scroll_focus_into_view()
	assert document.viewport_rect().y > 0
}

struct LabelClickPositionObservation {
mut:
	offset_x f64
	offset_y f64
	called   bool
}

fn test_label_activation_recomputes_click_offset_for_control_paintable() {
	document := html.parse_document('<!doctype html><style>html, body { margin: 0 } label { position: absolute; left: 100px; top: 80px } input { appearance: none; position: absolute; box-sizing: content-box; left: 30px; top: 20px; width: 80px; height: 20px; padding: 5px; border: 3px solid }</style><body><label id="label" for="control">Caption</label><input id="control"></body>')
	mut mutable_document := unsafe { &dom.Document(document) }
	host := &dom.Navigable{
		active_document_: document
	}
	_ := html.NavigableModel.create(host, none) or { panic(err) }
	mutable_document.set_cached_navigable(host)
	_ = layout_document_typed_in_viewport(document, 240, 140)
	label_element := document.get_element_by_id('label') or { panic('missing label') }
	control := document.get_element_by_id('control') or { panic('missing control') }
	paintable := control.as_node().paintable() or { panic('missing control paintable') }
	assert paintable.box_type_agnostic_position() == dom.CSSPixelPoint_{ x_: 38, y_: 28 }

	observation := &LabelClickPositionObservation{}
	listener := dom.IDLEventListener.create(&dom.CallbackType{
		handle_event: fn [observation] (event &dom.Event, _ ?&dom.EventTarget) dom.JSValue {
			mouse := unsafe { &dom.MouseEvent(event) }
			mut mutable_observation := unsafe { &LabelClickPositionObservation(observation) }
			mutable_observation.offset_x = mouse.offset_x()
			mutable_observation.offset_y = mouse.offset_y()
			mutable_observation.called = true
			return dom.js_undefined()
		}
	})
	unsafe { &dom.EventTarget(control.as_node()) }.add_event_listener_without_options('click', listener)
	click := dom.MouseEvent.create('click', dom.MouseEventInit{
		UIEventInit: dom.UIEventInit{
			EventInit: dom.EventInit{}
			detail: 1
		}
		client_x: 70
		client_y: 60
		offset_x: 999
		offset_y: 999
	})
	html.html_label_element_activation_behavior(unsafe { &dom.HTMLLabelElement(label_element) }, unsafe { &dom.Event(click) })
	assert observation.called
	assert observation.offset_x == 32
	assert observation.offset_y == 32
}

fn test_highlighted_node_records_box_and_text_inspector_overlays_without_clipping() {
	document := html.parse_document('<!doctype html><style>html, body { margin: 0 } #clip { width: 25px; height: 25px; overflow: hidden } #target { box-sizing: content-box; width: 20px; height: 10px; margin: 7px; border: 3px solid; padding: 5px; transform: translate(11px, 13px); background: white }</style><body><div id="clip"><div id="target">text</div></div></body>')
	root := layout_document_typed_in_viewport(document, 240, 140)
	target := document.get_element_by_id('target') or { panic('missing highlighted target') }
	target_box := root.find_box(i64(target.as_node().unique_id())) or {
		panic('missing highlighted target box')
	}
	mut mutable_document := unsafe { &dom.Document(document) }
	initial := display_list_commands(record_retained_display_list(mut mutable_document) or {
		panic('missing initial display list')
	})
	assert !initial.any(it.color in ['#ffff0064', '#00ffff64', '#00800064', '#ff00ff64'])

	mutable_document.set_highlighted_node(target.as_node(), none)
	box_commands := display_list_commands(record_retained_display_list(mut mutable_document) or {
		panic('missing box inspector display list')
	})
	box_overlay := box_commands.filter(it.color in ['#ffff0064', '#00ffff64', '#00800064', '#ff00ff64',
		'#ffff00', '#00ffff', '#008000', '#ff00ff', '#ffffe1', '#808080']
		|| (it.kind == 'draw_text' && it.text.contains('#target')))
	assert box_overlay.len == 11
	content := box_overlay.filter(it.kind == 'fill_rect' && it.color == '#ff00ff64')[0]
	assert content.x == target_box.x
	assert content.y == target_box.y
	assert content.width == target_box.width
	assert content.height == target_box.height
	assert box_overlay.all(!it.has_clip && it.clip_list == unsafe { nil }
		&& it.visual_layer_list == unsafe { nil })
	assert box_overlay.all(it.transform == [f64(1), 0, 0, 1, 11, 13]!)
	assert box_overlay.any(it.kind == 'draw_text' && it.text.contains('#target'))
	mut result := document_layout_result(document) or { panic('missing layout result') }
	assert !result.needs_repaint
	mutable_document.set_highlighted_node(target.as_node(), none)
	assert !result.needs_repaint

	text_node := target.as_node().first_child() or { panic('missing highlighted text') }
	mutable_document.set_highlighted_node(text_node, none)
	text_commands := display_list_commands(record_retained_display_list(mut mutable_document) or {
		panic('missing text inspector display list')
	})
	text_overlay := text_commands.filter((it.kind == 'stroke_rounded_rect' && it.color == '#008000')
		|| (it.kind == 'draw_line' && it.color == '#ff0000'))
	assert text_overlay.len == 2
	assert text_overlay.all(!it.has_clip && it.clip_list == unsafe { nil }
		&& it.visual_layer_list == unsafe { nil })
	assert text_overlay.all(it.transform == [f64(1), 0, 0, 1, 11, 13]!)
	assert text_overlay[1].points[1] == text_overlay[1].points[3]

	mutable_document.set_highlighted_node(none, none)
	cleared := display_list_commands(record_retained_display_list(mut mutable_document) or {
		panic('missing cleared inspector display list')
	})
	assert !cleared.any(it.color in ['#ffff0064', '#00ffff64', '#00800064', '#ff00ff64'])
	assert !cleared.any(it.kind == 'draw_line' && it.color == '#ff0000')
}

fn test_paintable_with_lines_text_cursor_hit_tests_empty_editing_host() {
	document := html.parse_document('<!doctype html><style>
		html, body, p { margin: 0 }
		p { width: 100px; height: 30px }
	</style><body><p id="target" contenteditable></p></body>')
	root := layout_document_typed_in_viewport(document, 240, 100)
	target := document.get_element_by_id('target') or { panic('missing empty hit-test target') }
	target_box := root.find_box(i64(target.as_node().unique_id())) or {
		panic('missing empty hit-test paint box')
	}
	viewport := document.paintable_box() or { panic('missing viewport paintable') }
	hit := viewport.hit_test(target_box.x + 10, target_box.y + 10, .text_cursor) or {
		panic('missing empty editable cursor hit')
	}
	assert hit.node == target.as_node()
	assert hit.element == target
	assert hit.index_in_node == 0
	assert (hit.vertical_distance or { panic('missing empty vertical distance') }) == 0
	assert (hit.horizontal_distance or { panic('missing empty horizontal distance') }) == 0
}

fn test_paintable_with_lines_text_cursor_skips_user_select_none_fragment_edges() {
	document := html.parse_document('<!doctype html><style>
		html, body, p { margin: 0 }
		p { width: 220px; line-height: 20px }
		span { user-select: none }
	</style><body><p id="target" contenteditable><span>hello</span></p></body>')
	root := layout_document_typed_in_viewport(document, 240, 100)
	target := document.get_element_by_id('target') or { panic('missing unselectable target') }
	span := document.query_selector('span') or { panic('missing unselectable span') }
	text_node := span.as_node().first_child() or { panic('missing unselectable text') }
	target_box := root.find_box(i64(target.as_node().unique_id())) or {
		panic('missing unselectable paint box')
	}
	assert target_box.lines.len == 1
	assert target_box.lines[0].fragments.len == 1
	fragment_rect := target_box.lines[0].fragments[0].paintable_fragment.absolute_rect()
	mut selection := document.get_selection() or { panic('missing unselectable selection') }
	selection.collapse(text_node, 2) or { panic(err) }
	viewport := document.paintable_box() or { panic('missing viewport paintable') }
	hit := viewport.hit_test(fragment_rect.right() + 12, fragment_rect.y + fragment_rect.height / 2, .text_cursor) or {
		panic('missing box fallback hit')
	}
	assert hit.node != text_node
	assert hit.vertical_distance == none
	assert hit.horizontal_distance == none
}

fn test_paintable_with_lines_hit_test_preserves_global_candidate_callback_order() {
	mut hit_test_state := CompatibilityHitTestState{
		result: dom.HitTestResult{
			vertical_distance: f64(5)
			horizontal_distance: f64(5)
		}
	}
	first_fragment := dom.HitTestResult{
		vertical_distance: f64(4)
		horizontal_distance: f64(100)
	}
	second_fragment := dom.HitTestResult{
		vertical_distance: f64(100)
		horizontal_distance: f64(99)
	}
	assert !hit_test_state.consider_hit_test_result(first_fragment, .text_cursor)
	after_first := hit_test_state.result or { panic('missing first cursor candidate') }
	assert (after_first.vertical_distance or { panic('missing first vertical distance') }) == 4
	assert !hit_test_state.consider_hit_test_result(second_fragment, .text_cursor)
	after_second := hit_test_state.result or { panic('missing second cursor candidate') }
	assert (after_second.vertical_distance or { panic('missing second vertical distance') }) == 100
	assert (after_second.horizontal_distance or { panic('missing second horizontal distance') }) == 99
}

// Upstream hit_testing/pointer-events: an interrupting block with
// `pointer-events: none` is transparent. Its inline parent has no box on the
// block's line, so the hit reaches the block container behind it.
fn test_interrupting_block_without_pointer_events_hits_the_enclosing_block() {
	document := html.parse_document('<!doctype html><style>
		html, body { margin: 0 }
		#under { position: absolute; z-index: -1; width: 100px; height: 100px }
		#child { width: 100px; height: 100px; pointer-events: none }
	</style><body><div id="under"></div><b id="outer"><div id="child"></div></b></body>')
	_ = layout_document_typed_in_viewport(document, 320, 200)
	body := document.body() or { panic('missing body') }
	mut mutable_document := unsafe { &dom.Document(document) }
	hit := mutable_document.element_from_point(10, 10) or { panic('missing hit') }
	assert hit.as_node().unique_id() == body.as_node().unique_id()
}

// Upstream HTML/HTMLElement-offsetFoo-for-split-inline-element: the inline
// has one layout node and one box per line. The empty box on the line hosting
// the interrupting block does not contribute to the united border box.
fn test_inline_with_interrupting_block_offsets_unite_its_line_boxes() {
	document := html.parse_document('<!doctype html><b>foo<div>bar</div>baz</b>')
	_ = layout_document_typed_in_viewport(document, 800, 600)
	bold := document.query_selector('b') or { panic('missing inline element') }
	html_bold := unsafe { &dom.HTMLElement(bold) }
	foo_width, line_height := single_line_inline_offset_size('foo')
	baz_width, _ := single_line_inline_offset_size('baz')
	assert foo_width > 0 && baz_width > 0
	assert html.html_element_offset_top(html_bold) == 8
	assert html.html_element_offset_left(html_bold) == 8
	// The interrupting block's 784px line belongs to the block, not the inline.
	assert html.html_element_offset_width(html_bold) == if foo_width > baz_width {
		foo_width
	} else {
		baz_width
	}
	assert html.html_element_offset_height(html_bold) == 3 * line_height
}

fn single_line_inline_offset_size(text string) (int, int) {
	document := html.parse_document('<!doctype html><b>${text}</b>')
	_ = layout_document_typed_in_viewport(document, 800, 600)
	bold := document.query_selector('b') or { panic('missing single-line inline element') }
	html_bold := unsafe { &dom.HTMLElement(bold) }
	return html.html_element_offset_width(html_bold), html.html_element_offset_height(html_bold)
}

fn test_paintable_box_chrome_predicates_follow_layout_type_and_writing_mode() {
	document := dom.Document.create(dom.url_about_blank())
	block_style := computed_paint_test_style('display: block; overflow: auto; resize: both')
	block := BlockContainer.new(document, none, block_style)
	block_node := unsafe { &Node(block) }
	assert paintable_box_overflow_property_applies(block_node, block_style)
	assert paintable_box_physical_resize_axes(block_node, block_style) == painting.PhysicalResizeAxes{
		horizontal: true
		vertical: true
	}
	assert paintable_box_has_resizer(block_node, block_style)

	inline_resize := computed_paint_test_style('display: block; overflow: auto; resize: inline')
	assert paintable_box_physical_resize_axes(block_node, inline_resize) == painting.PhysicalResizeAxes{
		horizontal: true
	}
	vertical_inline_resize := computed_paint_test_style('display: block; overflow: auto; resize: inline; writing-mode: vertical-rl')
	assert paintable_box_physical_resize_axes(block_node, vertical_inline_resize) == painting.PhysicalResizeAxes{
		vertical: true
	}
	clipped_axes := computed_paint_test_style('display: block; overflow: clip; resize: both')
	assert paintable_box_physical_resize_axes(block_node, clipped_axes) == painting.PhysicalResizeAxes{}

	inline_style := computed_paint_test_style('display: inline; overflow: auto; resize: both')
	inline_node := InlineNode.new(document, none, inline_style)
	assert !paintable_box_overflow_property_applies(unsafe { &Node(inline_node) }, inline_style)
	assert !paintable_box_has_resizer(unsafe { &Node(inline_node) }, inline_style)

	table_row_style := computed_paint_test_style('display: table-row; overflow: hidden')
	assert !paintable_box_overflow_property_applies(block_node, table_row_style)
	table_cell_style := computed_paint_test_style('display: table-cell; overflow: hidden')
	assert paintable_box_overflow_property_applies(block_node, table_cell_style)
	table_caption_style := computed_paint_test_style('display: table-caption; overflow: hidden')
	assert paintable_box_overflow_property_applies(block_node, table_caption_style)

	mut svg_element := document.create_element_ns('http://www.w3.org/2000/svg', 'g') or {
		panic(err)
	}
	svg_box := SVGBox.new(document, svg_element, block_style)
	assert !paintable_box_overflow_property_applies(unsafe { &Node(svg_box) }, block_style)

	viewport := Viewport.new(document, block_style)
	assert !paintable_box_has_resizer(unsafe { &Node(viewport) }, block_style)
	generated := BlockContainer.new(document, none, block_style)
	mut generated_node := unsafe { &Node(generated) }
	generated_node.generated_for_ = .before
	assert !paintable_box_has_resizer(generated_node, block_style)

	rtl_style := computed_paint_test_style('direction: rtl; writing-mode: horizontal-tb')
	assert paintable_box_is_chrome_mirrored(rtl_style)
	vertical_lr_style := computed_paint_test_style('writing-mode: vertical-lr')
	assert !paintable_box_is_chrome_mirrored(vertical_lr_style)
	vertical_rl_style := computed_paint_test_style('writing-mode: vertical-rl')
	assert paintable_box_is_chrome_mirrored(vertical_rl_style)
}

fn test_paintable_box_overflow_clip_edge_uses_padding_or_replaced_content_box() {
	document := dom.Document.create(dom.url_about_blank())
	computed := computed_paint_test_style('display: block; overflow: clip; overflow-clip-margin-top: 1px; overflow-clip-margin-right: 2px; overflow-clip-margin-bottom: 3px; overflow-clip-margin-left: 4px')
	normal := BlockContainer.new(document, none, computed)
	replaced := BlockContainer.new(document, none, computed)
	mut replaced_node := unsafe { &Node(replaced) }
	replaced_node.is_replaced_box_ = true
	mut used := UsedValues{
		padding_left: CSSPixels.new(4)
		padding_right: CSSPixels.new(6)
		padding_top: CSSPixels.new(5)
		padding_bottom: CSSPixels.new(7)
	}
	used.set_content_width(CSSPixels.new(100))
	used.set_content_height(CSSPixels.new(50))
	position := css.CSSPixelPoint.from_values(20, 30)
	assert paintable_box_overflow_clip_edge_rect(unsafe { &Node(normal) }, computed, used, position) == LayoutRect{12, 24, 116, 66}
	assert paintable_box_overflow_clip_edge_rect(replaced_node, computed, used, position) == LayoutRect{16, 29, 106, 54}
}

fn test_typed_paint_adapter_transports_custom_scrollbar_and_resizer_overlay() {
	document := html.parse_document('<!doctype html><style>html, body { margin: 0 } #scroller { width: 100px; height: 50px; overflow: auto; resize: both; direction: rtl; scrollbar-color: rgb(1 2 3) rgb(4 5 6) } #content { height: 200px }</style><body><div id="scroller"><div id="content"></div></div></body>')
	root := layout_document_typed_in_viewport(document, 320, 200)
	scroller := document.get_element_by_id('scroller') or { panic('missing scroller') }
	box := root.find_box(i64(scroller.as_node().unique_id())) or { panic('missing scroller box') }
	overlay := box.overlay or { panic('missing overlay transport') }
	assert !overlay.can_scroll_horizontally
	assert overlay.can_scroll_vertically
	assert overlay.has_resizer
	assert overlay.chrome_mirrored
	assert !overlay.default_scrollbar_colors
	assert overlay.scrollbar_thumb_color == css.Color{1, 2, 3, 255}
	assert overlay.scrollbar_track_color == css.Color{4, 5, 6, 255}

	commands := root.paint_commands()
	thumbs := commands.filter(it.kind == 'fill_rounded_rect' && it.color == css.Color{1, 2, 3, 255}.serialize())
	assert thumbs.len == 1
	assert math.abs(thumbs[0].x - 2.0) < 0.001
	assert commands.filter(it.kind == 'draw_line').len == 8

	mut paintable := scroller.paintable_box() or { panic('missing scroller paintable') }
	paintable.set_scroll_offset(dom.CSSPixelPoint_{
		y_: 30
	})
	moved_thumbs := root.paint_commands().filter(it.kind == 'fill_rounded_rect' && it.color == css.Color{1, 2, 3, 255}.serialize())
	assert moved_thumbs.len == 1
	assert moved_thumbs[0].y > thumbs[0].y
}

fn test_typed_paint_adapter_adapts_automatic_scrollbar_colors_to_backgrounds() {
	document := html.parse_document('<!doctype html><style>html,body{margin:0;background:white}.scroller{width:96px;height:140px;overflow:scroll}.content{width:180px;height:300px}.light{background:rgb(244 241 232)}.dark{background:rgb(74 88 98)}</style><body><div id="light" class="scroller light"><div class="content"></div></div><div id="dark" class="scroller dark"><div class="content"></div></div></body>')
	root := layout_document_typed_in_viewport(document, 320, 400)
	light := document.get_element_by_id('light') or { panic('missing light scroller') }
	dark := document.get_element_by_id('dark') or { panic('missing dark scroller') }
	light_overlay := root.find_box(i64(light.as_node().unique_id())) or { panic('missing light box') }.overlay or { panic('missing light overlay') }
	dark_overlay := root.find_box(i64(dark.as_node().unique_id())) or { panic('missing dark box') }.overlay or { panic('missing dark overlay') }
	assert light_overlay.default_scrollbar_colors
	assert light_overlay.scrollbar_thumb_color == css.Color{0, 0, 0, 128}
	assert light_overlay.scrollbar_track_color == css.Color{0, 0, 0, 25}
	assert dark_overlay.default_scrollbar_colors
	assert dark_overlay.scrollbar_thumb_color == css.Color{255, 255, 255, 128}
	assert dark_overlay.scrollbar_track_color == css.Color{255, 255, 255, 25}
}

fn test_typed_paint_adapter_transports_viewport_scrollbars_with_viewport_geometry() {
	document := html.parse_document('<!doctype html><style>html, body { margin: 0 } #content { width: 804px; height: 1221px }</style><body><div id="content"></div></body>')
	root := layout_document_typed_in_viewport(document, 800, 600)
	assert root.is_viewport_scroller
	assert root.compatibility_absolute_padding_rect() == painting.Rect{0, 0, 800, 600}
	overlay := root.overlay or { panic('missing viewport overlay transport') }
	assert overlay.can_scroll_horizontally
	assert overlay.can_scroll_vertically
	assert overlay.scrollable_overflow.width == 804
	assert overlay.scrollable_overflow.height == 1221

	thumbs := root.paint_commands().filter(it.kind == 'fill_rounded_rect'
		&& it.scrollbar_axis != '')
	assert thumbs.len == 2
	vertical := thumbs.filter(it.scrollbar_axis == 'vertical')[0]
	assert vertical.x == 792
	assert vertical.y == 2
	assert vertical.width == 6
	assert vertical.height == 293
	horizontal := thumbs.filter(it.scrollbar_axis == 'horizontal')[0]
	assert horizontal.x == 2
	assert horizontal.y == 592
	assert horizontal.height == 6
}

fn test_paintable_box_hit_test_chrome_uses_scrollbar_and_inflated_resizer_geometry() {
	document := html.parse_document('<!doctype html><style>
		html, body { margin: 0 }
		#scroller { width: 100px; height: 50px; overflow: auto; resize: both; border: 4px solid }
		#content { width: 200px; height: 200px }
	</style><body><div id="scroller"><div id="content"></div></div></body>')
	root := layout_document_typed_in_viewport(document, 320, 200)
	scroller := document.get_element_by_id('scroller') or { panic('missing chrome scroller') }
	box := root.find_box(i64(scroller.as_node().unique_id())) or {
		panic('missing chrome scroller box')
	}
	overlay := box.overlay or { panic('missing chrome overlay') }
	assert overlay.can_scroll_horizontally
	assert overlay.can_scroll_vertically
	assert overlay.has_resizer
	metrics := painting.new_chrome_metrics(1) or { panic(err) }
	viewport := document.paintable_box() or { panic('missing chrome viewport') }

	vertical_input := box.compatibility_scrollbar_geometry_input(overlay, .vertical, metrics, false)
	vertical_rect := painting.paintable_box_absolute_scrollbar_rect(vertical_input)
	vertical_hit := viewport.hit_test(vertical_rect.x + vertical_rect.width / 2, vertical_rect.y + 1, .exact) or { panic('missing vertical scrollbar hit') }
	assert vertical_hit.element.as_node().unique_id() == scroller.as_node().unique_id()
	assert vertical_hit.node.unique_id() == scroller.as_node().unique_id()
	assert vertical_hit.chrome_widget_id.starts_with('scrollbar-vertical:')
	mut mutable_document := unsafe { &dom.Document(document) }
	all_vertical_hits := mutable_document.elements_from_point(vertical_rect.x + vertical_rect.width / 2, vertical_rect.y + 1)
	assert all_vertical_hits.len > 0
	assert all_vertical_hits[0].as_node().unique_id() == scroller.as_node().unique_id()

	horizontal_input := box.compatibility_scrollbar_geometry_input(overlay, .horizontal, metrics, false)
	horizontal_rect := painting.paintable_box_absolute_scrollbar_rect(horizontal_input)
	horizontal_hit := viewport.hit_test(horizontal_rect.x + 1, horizontal_rect.y + horizontal_rect.height / 2, .exact) or {
		panic('missing horizontal scrollbar hit')
	}
	assert horizontal_hit.chrome_widget_id.starts_with('scrollbar-horizontal:')

	resizer_rect := painting.paintable_box_absolute_resizer_rect(box.compatibility_absolute_padding_rect(), true, false, metrics) or { panic('missing resize handle rect') }
	// PaintableBox::resizer_contains() inflates through the right and bottom
	// borders, beyond the 12px grip that is painted inside the padding box.
	resize_hit := viewport.hit_test(resizer_rect.right() + 2, resizer_rect.bottom() + 2, .exact) or { panic('missing inflated resize handle hit') }
	assert resize_hit.chrome_widget_id.starts_with('resize-handle:')

	result := document_layout_result(document) or { panic('missing chrome layout result') }
	snapshot := result.scroll_state.snapshot(1)
	mut pointerless_box := box
	pointerless_box.pointer_events_enabled = false
	resize_position := painting.Point{resizer_rect.right() + 2, resizer_rect.bottom() + 2}
	assert compatibility_hit_test_chrome(&pointerless_box, resize_position.x, resize_position.y, result.visual_context_tree, snapshot, metrics) == none

	// PaintableWithLines::hit_test() intentionally checks visible chrome without
	// the PaintableBox pointer-events gate; preserve that source distinction.
	inline_document := html.parse_document('<!doctype html><style>
		html, body, p { margin: 0 }
		p { width: 100px; height: 20px; overflow: auto; resize: both; pointer-events: none; white-space: nowrap }
	</style><body><p id="inline">overflowing inline text</p></body>')
	inline_root := layout_document_typed_in_viewport(inline_document, 320, 200)
	inline_element := inline_document.get_element_by_id('inline') or {
		panic('missing pointerless inline scroller')
	}
	inline_box := inline_root.find_box(i64(inline_element.as_node().unique_id())) or {
		panic('missing pointerless inline box')
	}
	inline_overlay := inline_box.overlay or { panic('missing pointerless inline overlay') }
	inline_resizer := painting.paintable_box_absolute_resizer_rect(inline_box.compatibility_absolute_padding_rect(), inline_overlay.has_resizer, inline_overlay.chrome_mirrored, metrics) or {
		panic('missing pointerless inline resizer')
	}
	inline_viewport := inline_document.paintable_box() or { panic('missing inline viewport') }
	inline_chrome := inline_viewport.hit_test(inline_resizer.x + 1, inline_resizer.y + 1, .exact) or { panic('missing pointerless inline chrome hit') }
	assert inline_chrome.chrome_widget_id.starts_with('resize-handle:')
}

fn test_active_scrollbar_hover_jump_drag_and_release_follow_source_state() {
	document := html.parse_document('<!doctype html><style>
		html, body { margin: 0 }
		#scroller { width: 100px; height: 50px; overflow: auto }
		#content { height: 200px }
	</style><body><div id="scroller"><div id="content"></div></div></body>')
	root := layout_document_typed_in_viewport(document, 320, 200)
	scroller := document.get_element_by_id('scroller') or { panic('missing active scroller') }
	box := root.find_box(i64(scroller.as_node().unique_id())) or {
		panic('missing active scroller box')
	}
	overlay := box.overlay or { panic('missing active scrollbar overlay') }
	metrics := painting.new_chrome_metrics(1) or { panic(err) }
	thin_input := box.compatibility_scrollbar_geometry_input(overlay, .vertical, metrics, false)
	thin_rect := painting.paintable_box_absolute_scrollbar_rect(thin_input)
	viewport := document.paintable_box() or { panic('missing active viewport') }
	initial_hit := viewport.hit_test(thin_rect.x + thin_rect.width / 2, 10, .exact) or {
		panic('missing active scrollbar hit')
	}
	assert initial_hit.chrome_widget_id.starts_with('scrollbar-vertical:')

	mut result := document_layout_result(document) or { panic('missing active layout result') }
	scrollbar_identity := initial_hit.chrome_widget_id.split(':')[1].u64()
	assert result.chrome_widget_boxes[scrollbar_identity] != unsafe { nil }
	result.chrome_widget_mouse_enter(initial_hit.chrome_widget_id)
	mut mutable_document := unsafe { &dom.Document(document) }
	hovered_commands := display_list_commands(record_retained_display_list(mut mutable_document) or {
		panic('missing hovered scrollbar display list')
	})
	gutter_input := box.compatibility_scrollbar_geometry_input(overlay, .vertical, metrics, true)
	gutter_rect := painting.paintable_box_absolute_scrollbar_rect(gutter_input)
	assert hovered_commands.any(it.kind == 'fill_rect' && it.x == gutter_rect.x
		&& it.y == gutter_rect.y && it.width == gutter_rect.width
		&& it.height == gutter_rect.height)
	// Hover enlargement exposes the full 12px gutter rather than only the thin
	// 8px overlay thumb hit area.
	hovered_hit := viewport.hit_test(gutter_rect.x + 1, 10, .exact) or {
		panic('missing enlarged scrollbar hit')
	}
	assert hovered_hit.chrome_widget_id == initial_hit.chrome_widget_id

	// Clicking the track below the thumb jumps to the constrained bottom, then
	// capture keeps routing a drag at a different point to the same scrollbar.
	assert result.handle_scrollbar_pointer_event(initial_hit.chrome_widget_id, 'pointerdown', 0, gutter_rect.x + gutter_rect.width / 2, gutter_rect.bottom() - 1) == .capture_input
	mut paintable := scroller.paintable_box() or { panic('missing active scroller paintable') }
	assert paintable.scroll_offset().y() == 150
	assert result.handle_scrollbar_pointer_event(initial_hit.chrome_widget_id, 'pointermove', 9, gutter_rect.x + gutter_rect.width / 2, 25) == .capture_input
	assert paintable.scroll_offset().y() == 11.53125
	assert result.handle_scrollbar_pointer_event(initial_hit.chrome_widget_id, 'pointerup', 0, gutter_rect.x + gutter_rect.width / 2, 25) == .none
	result.chrome_widget_mouse_leave(initial_hit.chrome_widget_id)
	assert mutable_document.document_pending_scroll_events().len == 1
}

fn test_active_resize_handle_updates_inline_size_and_survives_relayout() {
	document := html.parse_document('<!doctype html><style>
		html, body { margin: 0 }
		#resizable { width: 100px; height: 50px; padding: 5px; border: 2px solid; overflow: auto; resize: both; min-width: 120px; max-height: 100px }
	</style><body><div id="resizable"></div></body>')
	root := layout_document_typed_in_viewport(document, 320, 200)
	element := document.get_element_by_id('resizable') or { panic('missing resizable element') }
	node_id := element.as_node().unique_id().value()
	box := root.find_box(node_id) or { panic('missing resizable box') }
	overlay := box.overlay or { panic('missing resize overlay') }
	metrics := painting.new_chrome_metrics(1) or { panic(err) }
	resizer_rect := painting.paintable_box_absolute_resizer_rect(box.compatibility_absolute_padding_rect(), overlay.has_resizer, overlay.chrome_mirrored, metrics) or {
		panic('missing resize handle rect')
	}
	start_x := resizer_rect.right() - 1
	start_y := resizer_rect.bottom() - 1
	viewport := document.paintable_box() or { panic('missing resize viewport') }
	hit := viewport.hit_test(start_x, start_y, .exact) or { panic('missing resize handle hit') }
	assert hit.chrome_widget_id == 'resize-handle:${node_id}'

	mut result := document_layout_result(document) or { panic('missing resize layout result') }
	assert result.chrome_widget_cursor(hit.chrome_widget_id) or {
		panic('missing resize cursor')
	} == .se_resize
	assert result.handle_scrollbar_pointer_event(hit.chrome_widget_id, 'pointermove', 9, start_x + 1, start_y + 1) == .none
	assert result.handle_scrollbar_pointer_event(hit.chrome_widget_id, 'pointerdown', 1, start_x, start_y) == .none
	assert result.handle_scrollbar_pointer_event(hit.chrome_widget_id, 'pointerdown', 0, start_x, start_y) == .capture_input
	assert result.handle_scrollbar_pointer_event(hit.chrome_widget_id, 'pointermove', 9, start_x + 30, start_y + 40) == .capture_input
	style := css.inline_style(element)
	// The drag works in border-box dimensions, honors max-height, then converts
	// back to content-box width/height before updating the inline declaration.
	assert style.get_property_value('width') == '150px'
	assert style.get_property_value('height') == '86px'
	assert result.handle_scrollbar_pointer_event(hit.chrome_widget_id, 'pointerdown', 1, start_x + 100, start_y + 100) == .none
	assert style.get_property_value('width') == '150px'
	assert style.get_property_value('height') == '86px'
	active_state := result.resize_handle_states[node_id] or {
		panic('missing active resize state')
	}
	assert active_state.handle.is_resizing
	assert active_state.action != none

	// Applying the inline declaration schedules layout. The next frame replaces
	// every compatibility BlockBox, but capture keeps its stable DOM-node ID and
	// the original pointer-down border size.
	mut mutable_document := unsafe { &dom.Document(document) }
	mutable_document.update_layout(.debugging)
	mut updated_result := document_layout_result(document) or {
		panic('missing updated resize layout result')
	}
	updated_box := updated_result.paint_tree.find_box(node_id) or {
		panic('missing updated resizable box')
	}
	updated_overlay := updated_box.overlay or { panic('missing updated resize overlay') }
	updated_resizer_rect := painting.paintable_box_absolute_resizer_rect(updated_box.compatibility_absolute_padding_rect(), updated_overlay.has_resizer, updated_overlay.chrome_mirrored, metrics) or {
		panic('missing updated resize handle rect')
	}
	updated_viewport := document.paintable_box() or { panic('missing updated resize viewport') }
	updated_hit := updated_viewport.hit_test(updated_resizer_rect.right() - 1, updated_resizer_rect.bottom() - 1, .exact) or {
		panic('missing updated resize handle hit')
	}
	assert updated_hit.chrome_widget_id == hit.chrome_widget_id
	assert updated_result.handle_scrollbar_pointer_event(hit.chrome_widget_id, 'pointermove', 9, start_x + 50, start_y + 50) == .capture_input
	assert style.get_property_value('width') == '170px'
	assert style.get_property_value('height') == '86px'
	assert updated_result.handle_scrollbar_pointer_event(hit.chrome_widget_id, 'pointerup', 0, start_x + 50, start_y + 50) == .none
	assert node_id !in updated_result.resize_handle_states
}

fn test_element_scroll_replays_retained_commands_through_live_visual_context() {
	document := html.parse_document('<!doctype html><style>html, body { margin: 0 } #scroller { width: 100px; height: 50px; overflow: auto; background: rgb(9 8 7) } #spacer { height: 80px } #target { height: 20px; background: rgb(1 2 3) }</style><body><div id="scroller"><div id="spacer"></div><div id="target"></div></div></body>')
	_ = layout_document_typed_in_viewport(document, 320, 200)
	mut mutable_document := unsafe { &dom.Document(document) }
	initial_display_list := record_retained_display_list(mut mutable_document) or {
		panic('missing initial display list')
	}
	initial_commands := display_list_commands(initial_display_list)
	target_color := css.Color{1, 2, 3, 255}.serialize()
	initial_target_commands := initial_commands.filter(it.kind == 'fill_rect'
		&& it.color == target_color)
	assert initial_target_commands.len == 1
	assert initial_target_commands[0].transform[5] == 0
	assert initial_target_commands[0].has_clip
	assert initial_target_commands[0].clip_width == 100
	assert initial_target_commands[0].clip_height == 50

	target := document.get_element_by_id('target') or { panic('missing target') }
	initial_hit := mutable_document.element_from_point(10, 85) or { panic('missing initial hit') }
	assert initial_hit.as_node().unique_id() != target.as_node().unique_id()

	scroller := document.get_element_by_id('scroller') or { panic('missing scroller') }
	mut paintable := scroller.paintable_box() or { panic('missing scroller paintable') }
	result := document_layout_result(document) or { panic('missing layout result') }
	retained_command_count := result.paint_phase_command_count
	assert paintable.could_be_scrolled_by_wheel_event()
	assert !paintable.could_be_scrolled_horizontally_by_wheel_event()
	assert paintable.could_be_scrolled_vertically_by_wheel_event()
	assert paintable.handle_mousewheel(0, 70)
	// Once clamped at the edge this scroller declines the wheel delta, allowing
	// the containing-block walk to offer it to an ancestor.
	assert !paintable.handle_mousewheel(0, 70)
	assert paintable.scroll_offset().y() == 50
	assert scroller.el_scroll_offset().y() == 50
	assert document.document_pending_scroll_events().len == 1
	assert mutable_document.cached_display_list() == none
	assert result.paint_phase_cache_valid

	scrolled_display_list := record_retained_display_list(mut mutable_document) or {
		panic('missing scrolled display list')
	}
	scrolled_commands := display_list_commands(scrolled_display_list)
	scrolled_target_commands := scrolled_commands.filter(it.kind == 'fill_rect'
		&& it.color == target_color)
	assert scrolled_target_commands.len == 1
	assert scrolled_target_commands[0].transform[5] == -50
	assert result.paint_phase_command_count == retained_command_count
	scrolled_hit := mutable_document.element_from_point(10, 35) or { panic('missing scrolled hit') }
	assert scrolled_hit.as_node().unique_id() == target.as_node().unique_id()
}

fn test_overflow_hidden_allows_programmatic_scroll_but_declines_wheel_scroll() {
	document := html.parse_document('<!doctype html><style>html, body { margin: 0 } #scroller { width: 100px; height: 50px; overflow: hidden } #content { height: 100px }</style><body><div id="scroller"><div id="content"></div></div></body>')
	_ = layout_document_typed_in_viewport(document, 320, 200)
	scroller := document.get_element_by_id('scroller') or { panic('missing scroller') }
	mut paintable := scroller.paintable_box() or { panic('missing scroller paintable') }
	assert !paintable.could_be_scrolled_by_wheel_event()
	assert !paintable.handle_mousewheel(0, 20)
	assert paintable.set_scroll_offset(dom.CSSPixelPoint_{ y_: 20 })
	assert paintable.scroll_offset().y() == 20
}

fn test_retained_commands_preserve_nested_rounded_overflow_clip_nodes() {
	document := html.parse_document('<!doctype html><style>html, body { margin: 0 } #outer { width: 100px; height: 80px; overflow: hidden; border-radius: 30px / 20px } #inner { width: 80px; height: 60px; overflow: hidden; border-radius: 10px / 6px; transform: translate(5px, 7px); transform-origin: 0 0 } #target { width: 120px; height: 120px; background: rgb(71 72 73) }</style><body><div id="outer"><div id="inner"><div id="target"></div></div></div></body>')
	_ = layout_document_typed_in_viewport(document, 320, 200)
	mut mutable_document := unsafe { &dom.Document(document) }
	display_list := record_retained_display_list(mut mutable_document) or { panic('missing display list') }
	target_color := css.Color{71, 72, 73, 255}.serialize()
	target_commands := display_list_commands(display_list).filter(it.kind == 'fill_rect'
		&& it.color == target_color)
	assert target_commands.len == 1
	command := target_commands[0]
	assert command.has_clip
	assert command.clip_list != unsafe { nil }
	assert command.clip_list.items.len == 2
	assert command.clip_list.items[0].rect.width == 100
	assert command.clip_list.items[0].rect.height == 80
	assert command.clip_list.items[0].corner_radii.top_left == CornerRadius{30, 20}
	assert command.clip_list.items[1].rect.width == 80
	assert command.clip_list.items[1].rect.height == 60
	assert command.clip_list.items[1].corner_radii.top_left == CornerRadius{10, 6}
	assert command.clip_list.items[1].transform == [f64(1), 0, 0, 1, 5, 7]!

	target := document.get_element_by_id('target') or { panic('missing target') }
	clipped_corner_hit := mutable_document.element_from_point(1, 1) or {
		panic('missing corner fallback hit')
	}
	assert clipped_corner_hit.as_node().unique_id() != target.as_node().unique_id()
	inside_hit := mutable_document.element_from_point(50, 40) or { panic('missing inside hit') }
	assert inside_hit.as_node().unique_id() == target.as_node().unique_id()
}

fn test_css_clip_rect_clips_absolute_box_descendants_and_hit_testing() {
	document := html.parse_document('<!doctype html><style>html, body { margin: 0 } #target { position: absolute; width: 100px; height: 100px; background: rgb(61 62 63); clip: rect(10px, 80px, 60px, 20px) } #child { width: 100px; height: 100px; background: rgb(64 65 66) }</style><body><div id="target"><div id="child"></div></div></body>')
	_ = layout_document_typed_in_viewport(document, 320, 200)
	mut mutable_document := unsafe { &dom.Document(document) }
	display_list := record_retained_display_list(mut mutable_document) or { panic('missing display list') }
	commands := display_list_commands(display_list)
	for color in [css.Color{61, 62, 63, 255}.serialize(), css.Color{64, 65, 66, 255}.serialize()] {
		matching := commands.filter(it.kind == 'fill_rect' && it.color == color)
		assert matching.len == 1
		assert matching[0].has_clip
		assert matching[0].clip_list != unsafe { nil }
		assert matching[0].clip_list.items.len == 1
		clip := matching[0].clip_list.items[0]
		assert clip.rect == LayoutRect{20, 10, 60, 50}
		assert clip.corner_radii == BoxRadii{}
	}

	target := document.get_element_by_id('target') or { panic('missing target') }
	child := document.get_element_by_id('child') or { panic('missing child') }
	outside_hit := mutable_document.element_from_point(5, 5) or { panic('missing outside hit') }
	assert outside_hit.as_node().unique_id() != target.as_node().unique_id()
	assert outside_hit.as_node().unique_id() != child.as_node().unique_id()
	inside_hit := mutable_document.element_from_point(30, 30) or { panic('missing inside hit') }
	assert inside_hit.as_node().unique_id() == child.as_node().unique_id()
}

fn test_css_clip_rect_is_ignored_for_non_positioned_boxes_and_negative_extents_are_empty() {
	document := html.parse_document('<!doctype html><style>html, body { margin: 0 } #static { width: 100px; height: 30px; background: rgb(67 68 69); clip: rect(0, 0, 0, 0) } #negative { position: absolute; top: 40px; width: 100px; height: 100px; background: rgb(70 71 72); clip: rect(80px, 20px, 10px, 90px) }</style><body><div id="static"></div><div id="negative"></div></body>')
	_ = layout_document_typed_in_viewport(document, 320, 200)
	mut mutable_document := unsafe { &dom.Document(document) }
	display_list := record_retained_display_list(mut mutable_document) or { panic('missing display list') }
	commands := display_list_commands(display_list)
	static_commands := commands.filter(it.kind == 'fill_rect'
		&& it.color == css.Color{67, 68, 69, 255}.serialize())
	assert static_commands.len == 1
	assert !static_commands[0].has_clip
	negative_commands := commands.filter(it.kind == 'fill_rect'
		&& it.color == css.Color{70, 71, 72, 255}.serialize())
	assert negative_commands.len == 1
	assert negative_commands[0].has_clip
	assert negative_commands[0].clip_list.items.len == 1
	assert negative_commands[0].clip_list.items[0].rect == LayoutRect{}
}

fn test_basic_shape_clip_path_retains_curves_fill_rule_and_hit_testing() {
	document := html.parse_document('<!doctype html><style>html, body { margin: 0 } #target { width: 100px; height: 100px; background: rgb(81 82 83); clip-path: path(evenodd, "M 0 0 H 100 V 100 H 0 Z M 25 25 H 75 V 75 H 25 Z") }</style><body><div id="target"></div></body>')
	_ = layout_document_typed_in_viewport(document, 320, 200)
	mut mutable_document := unsafe { &dom.Document(document) }
	display_list := record_retained_display_list(mut mutable_document) or { panic('missing display list') }
	target_color := css.Color{81, 82, 83, 255}.serialize()
	target_commands := display_list_commands(display_list).filter(it.kind == 'fill_rect'
		&& it.color == target_color)
	assert target_commands.len == 1
	command := target_commands[0]
	assert command.has_clip
	assert command.clip_list != unsafe { nil }
	assert command.clip_list.items.len == 1
	clip := command.clip_list.items[0]
	assert clip.is_path
	assert clip.path_even_odd
	assert clip.path_data.len == 10 * compatibility_clip_path_segment_stride
	assert clip.path_data[0] == 0 // move_to
	assert clip.path_data[compatibility_clip_path_segment_stride] == 1 // line_to

	target := document.get_element_by_id('target') or { panic('missing target') }
	outer_hit := mutable_document.element_from_point(10, 10) or { panic('missing outer hit') }
	assert outer_hit.as_node().unique_id() == target.as_node().unique_id()
	hole_hit := mutable_document.element_from_point(50, 50) or {
		panic('missing hole fallback hit')
	}
	assert hole_hit.as_node().unique_id() != target.as_node().unique_id()
}

fn test_circle_clip_path_retains_endpoint_arcs() {
	document := html.parse_document('<!doctype html><style>html, body { margin: 0 } #target { width: 100px; height: 100px; background: rgb(91 92 93); clip-path: circle(40px at 50px 50px) }</style><body><div id="target"></div></body>')
	_ = layout_document_typed_in_viewport(document, 320, 200)
	mut mutable_document := unsafe { &dom.Document(document) }
	display_list := record_retained_display_list(mut mutable_document) or { panic('missing display list') }
	target_color := css.Color{91, 92, 93, 255}.serialize()
	commands := display_list_commands(display_list).filter(it.kind == 'fill_rect'
		&& it.color == target_color)
	assert commands.len == 1
	clip := commands[0].clip_list.items[0]
	assert clip.is_path
	assert clip.path_data.len == 3 * compatibility_clip_path_segment_stride
	assert clip.path_data[compatibility_clip_path_segment_stride] == 4 // elliptical_arc_to
	assert clip.path_data[compatibility_clip_path_segment_stride * 2] == 4
}

fn test_svg_paths_retain_exact_geometry_and_stroke_style_for_native_replay() {
	document := html.parse_document('<!doctype html><style>html, body { margin: 0 }</style><svg width="200" height="100" viewBox="0 0 100 50"><path d="M 5 25 C 20 0 35 50 50 25 A 10 6 30 0 1 75 25" fill="red" fill-rule="evenodd" stroke="blue" stroke-width="3" stroke-linecap="round" stroke-linejoin="bevel" stroke-miterlimit="7"/></svg>')
	root := layout_document_typed_in_viewport(document, 320, 200)
	paths := root.paint_commands().filter(it.kind == 'draw_svg_path')
	assert paths.len == 1
	command := paths[0]
	assert command.svg().path_data.len == 3 * compatibility_clip_path_segment_stride
	assert command.svg().path_data[0] == 0 // move_to
	assert command.svg().path_data[compatibility_clip_path_segment_stride] == 3 // cubic curve
	assert command.svg().path_data[compatibility_clip_path_segment_stride * 2] == 4 // arc
	assert command.svg().fill_even_odd
	assert command.svg().stroke_linecap == 1
	assert command.svg().stroke_linejoin == 2
	assert command.svg().stroke_miterlimit == 7
}

fn test_svg_path_hit_testing_rejects_stroke_inflation_outside_transformed_path_bounds() {
	document := html.parse_document('<!doctype html><style>html, body { margin: 0 } svg { display: block }</style><svg width="200" height="100" viewBox="0 0 100 50"><path id="target" transform="translate(10 5)" d="M 10 10 H 20 V 20 H 10 Z" fill="none" stroke="blue" stroke-width="10"/></svg>')
	root := layout_document_typed_in_viewport(document, 240, 140)
	target := document.get_element_by_id('target') or { panic('missing SVG path') }
	target_box := root.find_box(i64(target.as_node().unique_id())) or {
		panic('missing SVG path paint box')
	}
	assert target_box.has_svg_path
	assert target_box.svg_path_bounding_box == painting.Rect{10, 10, 10, 10}
	assert target_box.svg_transform == [f64(2), 0, 0, 2, 20, 10]!

	mut mutable_document := unsafe { &dom.Document(document) }
	inside_bounds_hit := mutable_document.element_from_point(45, 35) or {
		panic('missing hit inside transformed path bounds')
	}
	assert inside_bounds_hit.as_node().unique_id() == target.as_node().unique_id()
	stroke_margin_hit := mutable_document.element_from_point(45, 25) or {
		panic('missing fallback hit outside path bounds')
	}
	assert stroke_margin_hit.as_node().unique_id() != target.as_node().unique_id()
	assert mutable_document.elements_from_point(45, 25).all(it.as_node().unique_id() != target.as_node().unique_id())
}

fn test_author_css_replaces_an_svg_transform_presentation_attribute_once() {
	document := html.parse_document('<!doctype html><style>html,body,svg{margin:0;display:block}#target{transform:translate(7px, 8px)}</style><svg width="100" height="100"><rect id="target" transform="translate(40 50)" width="10" height="10" fill="red"/></svg>')
	root := layout_document_typed_in_viewport(document, 120, 120)
	target := document.get_element_by_id('target') or { panic('missing SVG transform target') }
	target_box := root.find_box(i64(target.as_node().unique_id())) or {
		panic('missing SVG transform paint box')
	}
	assert target_box.svg_transform == [f64(1), 0, 0, 1, 7, 8]!
	assert target_box.own_paint_transform == [6]f64{}
}

fn test_nested_svg_viewport_and_element_transforms_are_interleaved_at_paint_time() {
	document := html.parse_document('<!doctype html><style>html, body { margin: 0 }</style><svg width="200" height="200" viewBox="0 0 10 10"><g transform="translate(1 0)"><svg x="2" width="4" height="4" viewBox="0 0 2 2"><rect id="target" x=".5" y=".5" width="1" height="1"/></svg></g></svg>')
	result := run_document_layout(document, 240, 240) or { panic('layout failed') }
	target_node := typed_paint_node_with_id(result.root, 'target') or {
		panic('missing SVG target layout node')
	}
	target_styled := target_node.as_node_with_style() or { panic('SVG target has no style') }
	target_used := result.state.try_get(target_styled) or { panic('SVG target has no used values') }
	assert target_used.offset.x().to_double() == 0.5
	assert target_used.offset.y().to_double() == 0.5
	root := block_box_from_typed_layout(result.root, result.state)
	element := document.get_element_by_id('target') or { panic('missing SVG target') }
	target_box := root.find_box(i64(element.as_node().unique_id())) or {
		panic('missing SVG target paint box')
	}
	assert target_box.svg_transform == [f64(40), 0, 0, 40, 60, 0]!
}

fn test_typed_paint_adapter_builds_deep_box_trees_without_stack_recursion() {
	depth := 160
	document := html.parse_document('<!doctype html><style>html,body,div{margin:0}</style>${'<div>'.repeat(depth)}<div id="deepest">deep</div>${'</div>'.repeat(depth)}')
	root := layout_document_typed_in_viewport(document, 320, 240)
	deepest := document.get_element_by_id('deepest') or { panic('missing deepest element') }
	deepest_box := root.find_box(i64(deepest.as_node().unique_id())) or {
		panic('deepest layout box was not retained by the paint adapter')
	}
	assert deepest_box.tag_name == 'div'
}

fn test_svg_stroke_dashes_remain_in_user_units_until_paint() {
	document := html.parse_document('<!doctype html><style>html, body { margin: 0 }</style><svg width="200" height="100" viewBox="0 0 100 50"><path d="M 0 10 H 100" fill="none" stroke="green" stroke-width="2" stroke-dasharray="3" stroke-dashoffset="1"/></svg>')
	root := layout_document_typed_in_viewport(document, 220, 120)
	paths := root.paint_commands().filter(it.kind == 'draw_svg_path')
	assert paths.len == 1
	assert paths[0].svg().stroke_dasharray == [f64(3), 3]
	assert paths[0].svg().stroke_dashoffset == 1
	serialized := root.render_svg(220, 120)
	assert serialized.contains('stroke-dasharray="3 3"')
	assert serialized.contains('stroke-dashoffset="1"')
}

fn test_svg_stroke_percentages_and_stylesheets_use_scaled_viewport_basis() {
	document := html.parse_document('<!doctype html><style>html, body { margin: 0 } #target { stroke-width: 10%; stroke-dasharray: 20% 2; stroke-dashoffset: 30% }</style><svg width="200" height="100" viewBox="0 0 40 20"><path id="target" d="M 0 10 H 40" fill="none" stroke="green" stroke-width="1" stroke-dasharray="1" stroke-dashoffset="1"/></svg>')
	root := layout_document_typed_in_viewport(document, 220, 120)
	paths := root.paint_commands().filter(it.kind == 'draw_svg_path')
	assert paths.len == 1
	// The scaled viewport basis is (40 + 20) / 2 = 30 user units.
	assert paths[0].stroke_width == 3
	assert paths[0].svg().stroke_dasharray == [f64(6), 2]
	assert paths[0].svg().stroke_dashoffset == 9
}

fn test_svg_vector_effect_uses_the_css_cascade() {
	document := html.parse_document('<!doctype html><style>html, body { margin: 0 } #from-style { vector-effect: non-scaling-stroke } #overridden { vector-effect: none }</style><svg width="100" height="100"><path id="from-style" d="M0 10H100" stroke="green"/><path id="overridden" d="M0 20H100" stroke="green" vector-effect="non-scaling-stroke"/></svg>')
	root := layout_document_typed_in_viewport(document, 120, 120)
	paths := root.paint_commands().filter(it.kind == 'draw_svg_path')
	assert paths.len == 2
	assert paths[0].svg().non_scaling_stroke
	assert !paths[1].svg().non_scaling_stroke
}

fn test_svg_linear_gradient_paints_retain_linked_resource_algorithms() {
	document := html.parse_document('<!doctype html><style>html, body { margin: 0 }</style><svg width="200" height="100" viewBox="0 0 100 50"><defs><linearGradient id="wrong"><stop stop-color="black"/></linearGradient><linearGradient id="base" gradientUnits="userSpaceOnUse" x1="10%" y1="20%" x2="90%" y2="80%" spreadMethod="reflect" gradientTransform="translate(3 4)" color-interpolation="linearRGB"><stop offset="70%" stop-color="rgb(10 20 30)" stop-opacity=".5"/><stop offset="20%" stop-color="rgb(40 50 60)"/></linearGradient><linearGradient id="derived" href="#base" xlink:href="#wrong" x2="50%" color-interpolation="linearRGB"/></defs><rect x="10" y="5" width="80" height="40" fill="url(#derived) magenta" stroke="url(#base) cyan" stroke-width="3" paint-order="stroke fill"/></svg>')
	root := layout_document_typed_in_viewport(document, 240, 140)
	paths := root.paint_commands().filter(it.kind == 'draw_svg_path')
	assert paths.len == 1
	command := paths[0]
	assert command.color == ''
	assert command.stroke_color == ''
	assert command.svg().stroke_first
	fill := command.fill_linear_gradient() or { panic('missing retained fill gradient') }
	stroke := command.stroke_linear_gradient() or { panic('missing retained stroke gradient') }
	assert math.abs(fill.start_point.x - 10.0) < 0.001
	assert math.abs(fill.start_point.y - 10.0) < 0.001
	assert math.abs(fill.end_point.x - 50.0) < 0.001
	assert math.abs(fill.end_point.y - 40.0) < 0.001
	assert math.abs(stroke.end_point.x - 90.0) < 0.001
	assert fill.gradient.spread_method == .reflect
	assert fill.gradient.color_space == .linear_srgb
	transform := fill.gradient.gradient_transform or { panic('missing gradient transform') }
	assert transform == painting.Affine{ e: 3, f: 4 }
	assert fill.gradient.color_stops.len == 2
	assert fill.gradient.color_stops[0].color == painting.Color{10, 20, 30, 128}
	assert math.abs(fill.gradient.color_stops[0].position - 0.7) < 0.001
	// SVGGradientElement clamps every later offset to the preceding offset.
	assert math.abs(fill.gradient.color_stops[1].position - 0.7) < 0.001
	serialized := root.render_svg(240, 140)
	assert serialized.contains('gradientUnits="userSpaceOnUse"')
	assert serialized.contains('spreadMethod="reflect"')
	assert serialized.contains('color-interpolation="linearRGB"')
	assert serialized.contains('paint-order="stroke fill"')
}

fn test_svg_paint_servers_resolve_inside_use_shadow_trees() {
	document := html.parse_document('<!doctype html><style>html, body { margin: 0 }</style><svg width="100" height="100"><use id="host" width="100" height="100"/></svg>')
	mut host := document.get_element_by_id('host') or { panic('missing use host') }
	shadow_root := host.shadow_root() or { panic('missing use shadow root') }
	mut symbol := document.create_element_ns('http://www.w3.org/2000/svg', 'symbol') or {
		panic('${err}')
	}
	mut gradient := document.create_element_ns('http://www.w3.org/2000/svg', 'linearGradient') or {
		panic('${err}')
	}
	gradient.set_attribute_value('id', 'shadow paint')
	mut red := document.create_element_ns('http://www.w3.org/2000/svg', 'stop') or {
		panic('${err}')
	}
	red.set_attribute_value('stop-color', 'red')
	mut blue := document.create_element_ns('http://www.w3.org/2000/svg', 'stop') or {
		panic('${err}')
	}
	blue.set_attribute_value('offset', '1')
	blue.set_attribute_value('stop-color', 'blue')
	mut gradient_node := gradient.as_node()
	gradient_node.append_child(red.as_node()) or { panic('${err}') }
	gradient_node.append_child(blue.as_node()) or { panic('${err}') }
	mut rect := document.create_element_ns('http://www.w3.org/2000/svg', 'rect') or {
		panic('${err}')
	}
	rect.set_attribute_value('width', '100')
	rect.set_attribute_value('height', '100')
	rect.set_attribute_value('fill', 'url(#shadow%20paint)')
	mut symbol_node := symbol.as_node()
	symbol_node.append_child(gradient.as_node()) or { panic('${err}') }
	symbol_node.append_child(rect.as_node()) or { panic('${err}') }
	mut shadow_node := unsafe { &dom.Node(shadow_root) }
	shadow_node.append_child(symbol.as_node()) or { panic('${err}') }

	root := layout_document_typed_in_viewport(document, 100, 100)
	paths := root.paint_commands().filter(it.kind == 'draw_svg_path')
	assert paths.len == 1
	paint := paths[0].fill_linear_gradient() or { panic('missing shadow-tree gradient') }
	assert paint.gradient.color_stops.map(it.color) == [
		painting.Color{255, 0, 0, 255},
		painting.Color{0, 0, 255, 255},
	]
}

fn test_svg_paint_resource_mutation_invalidates_the_retained_display_list() {
	document := html.parse_document('<!doctype html><style>html, body { margin: 0 }</style><svg width="100" height="100"><defs><linearGradient id="paint"><stop id="stop" stop-color="red"/><stop offset="1" stop-color="blue"/></linearGradient></defs><rect id="painted" width="100" height="100" fill="url(#paint)"/></svg>')
	root := layout_document_typed_in_viewport(document, 100, 100)
	mut mutable_document := unsafe { &dom.Document(document) }
	initial_display_list := record_retained_display_list(mut mutable_document) or {
		panic('missing initial display list')
	}
	initial_path := display_list_commands(initial_display_list).filter(it.kind == 'draw_svg_path')[0]
	initial_gradient := initial_path.fill_linear_gradient() or { panic('missing initial gradient') }
	assert initial_gradient.gradient.color_stops[0].color == painting.Color{255, 0, 0, 255}
	assert mutable_document.cached_display_list() != none

	mut stop := document.get_element_by_id('stop') or { panic('missing gradient stop') }
	stop.set_attribute_value('stop-color', 'green')
	assert mutable_document.cached_display_list() == none
	painted_dom_element := document.get_element_by_id('painted') or { panic('missing painted element') }
	painted_element := root.find_box(i64(painted_dom_element.as_node().unique_id())) or {
		panic('missing painted box')
	}
	result := document_layout_result(document) or { panic('missing layout result') }
	mut painted_entry_is_valid := true
	for index, entry in result.paint_order {
		if entry.box.layout_handle == painted_element.layout_handle {
			painted_entry_is_valid = result.paint_phase_entry_valid[index]
			break
		}
	}
	assert !painted_entry_is_valid
	mutable_document.update_layout(.dump_display_list)
	updated_display_list := record_retained_display_list(mut mutable_document) or {
		panic('missing updated display list')
	}
	updated_path := display_list_commands(updated_display_list).filter(it.kind == 'draw_svg_path')[0]
	updated_gradient := updated_path.fill_linear_gradient() or { panic('missing updated gradient') }
	assert updated_gradient.gradient.color_stops[0].color == painting.Color{0, 128, 0, 255}
}

fn test_svg_paint_resource_lookup_is_rebuilt_after_an_id_collision_changes() {
	document := html.parse_document('<!doctype html><style>html, body { margin: 0 }</style><div id="paint" style="display:none"></div><svg width="100" height="100"><defs><linearGradient id="paint"><stop stop-color="green"/></linearGradient></defs><rect width="100" height="100" fill="url(#paint) red"/></svg>')
	layout_document_typed_in_viewport(document, 100, 100)
	mut mutable_document := unsafe { &dom.Document(document) }
	initial_display_list := record_retained_display_list(mut mutable_document) or {
		panic('missing initial display list')
	}
	initial_path := display_list_commands(initial_display_list).filter(it.kind == 'draw_svg_path')[0]
	assert initial_path.fill_linear_gradient() == none
	assert initial_path.color == 'rgb(255 0 0)'
	assert mutable_document.cached_display_list() != none

	mut collision := document.get_element_by_id('paint') or { panic('missing colliding element') }
	collision.set_attribute_value('id', 'other')
	assert mutable_document.cached_display_list() == none
	mutable_document.update_layout(.dump_display_list)
	updated_display_list := record_retained_display_list(mut mutable_document) or {
		panic('missing updated display list')
	}
	updated_path := display_list_commands(updated_display_list).filter(it.kind == 'draw_svg_path')[0]
	updated_gradient := updated_path.fill_linear_gradient() or { panic('missing updated gradient') }
	assert updated_gradient.gradient.color_stops[0].color == painting.Color{0, 128, 0, 255}
}

fn test_svg_radial_gradient_paints_retain_two_circle_linked_resource_algorithms() {
	document := html.parse_document('<!doctype html><style>html, body { margin: 0 }</style><svg width="200" height="100" viewBox="0 0 200 100"><defs><radialGradient id="base" gradientUnits="userSpaceOnUse" cx="25%" cy="40%" r="30%" fx="10%" fr="5%" spreadMethod="reflect" gradientTransform="translate(3 4)"><stop offset="20%" stop-color="rgb(10 20 30)"/><stop offset="100%" stop-color="rgb(40 50 60)" stop-opacity=".5"/></radialGradient><radialGradient id="derived" href="#base" cx="60%" r="-3" fr="-10%" color-interpolation="linearRGB"/></defs><rect x="10" y="5" width="80" height="40" fill="url(#derived) magenta" stroke="url(#base) cyan" stroke-width="3" paint-order="stroke fill"/></svg>')
	root := layout_document_typed_in_viewport(document, 240, 140)
	paths := root.paint_commands().filter(it.kind == 'draw_svg_path')
	assert paths.len == 1
	command := paths[0]
	assert command.color == ''
	assert command.stroke_color == ''
	assert command.svg().stroke_first
	fill := command.fill_radial_gradient() or { panic('missing retained radial fill') }
	stroke := command.stroke_radial_gradient() or { panic('missing retained radial stroke') }
	assert command.fill_linear_gradient() == none
	assert command.stroke_linear_gradient() == none
	assert math.abs(fill.start_center.x - 20.0) < 0.001
	assert math.abs(fill.start_center.y - 40.0) < 0.001
	assert math.abs(fill.start_radius - 10.0) < 0.001
	assert math.abs(fill.end_center.x - 120.0) < 0.001
	assert math.abs(fill.end_center.y - 40.0) < 0.001
	// Negative derived radii are absent for inheritance in the C++ implementation.
	assert math.abs(fill.end_radius - 60.0) < 0.001
	assert math.abs(stroke.end_center.x - 50.0) < 0.001
	assert fill.gradient.spread_method == .reflect
	assert fill.gradient.color_space == .linear_srgb
	transform := fill.gradient.gradient_transform or { panic('missing radial transform') }
	assert transform == painting.Affine{ e: 3, f: 4 }
	assert fill.gradient.color_stops.len == 2
	assert fill.gradient.color_stops[1].color == painting.Color{40, 50, 60, 128}
	serialized := root.render_svg(240, 140)
	assert serialized.contains('<radialGradient')
	assert serialized.contains('fx="20" fy="40" fr="10" cx="120" cy="40" r="60"')
	assert serialized.contains('spreadMethod="reflect"')
	assert serialized.contains('paint-order="stroke fill"')
}

fn test_svg_radial_gradient_object_bounding_box_defaults_match_cpp_width_resolution() {
	document := html.parse_document('<!doctype html><style>html, body { margin: 0 }</style><svg width="100" height="100"><defs><radialGradient id="spot"><stop stop-color="white"/><stop offset="100%" stop-color="black"/></radialGradient></defs><rect x="10" y="5" width="80" height="40" fill="url(#spot) red"/></svg>')
	root := layout_document_typed_in_viewport(document, 120, 120)
	paths := root.paint_commands().filter(it.kind == 'draw_svg_path')
	assert paths.len == 1
	gradient := paths[0].fill_radial_gradient() or { panic('missing default radial gradient') }
	assert gradient.start_center == painting.Point{50, 25}
	assert gradient.end_center == painting.Point{50, 25}
	assert gradient.start_radius == 0
	// SVGRadialGradientElement.cpp resolves object-box radii against width.
	assert gradient.end_radius == 40
}

fn test_svg_pattern_paints_retain_linked_tile_display_list() {
	document := html.parse_document('<!doctype html><style>html, body { margin: 0 } svg { display:block }</style><svg width="200" height="100" viewBox="0 0 200 100"><defs><linearGradient id="shade"><stop stop-color="red"/><stop offset="1" stop-color="blue"/></linearGradient><pattern id="base" patternUnits="userSpaceOnUse" patternContentUnits="userSpaceOnUse" x="10" y="5" width="20" height="10" patternTransform="translate(3 4)"><rect width="10" height="10" fill="rgb(10 20 30)"/><circle cx="15" cy="5" r="4" fill="rgb(40 50 60)"/><path d="M0 0H20V2H0Z" fill="url(#shade)" fill-opacity=".6"/></pattern><pattern id="derived" href="#base" width="25"/></defs><rect x="20" y="10" width="100" height="60" fill="url(#derived) magenta" stroke="url(#base) cyan" stroke-width="3" paint-order="stroke fill"/></svg>')
	root := layout_document_typed_in_viewport(document, 220, 120)
	paths := root.paint_commands().filter(it.kind == 'draw_svg_path')
	assert paths.len == 1
	command := paths[0]
	assert command.color == ''
	assert command.stroke_color == ''
	assert command.svg().stroke_first
	fill := command.svg().fill_pattern or { panic('missing retained pattern fill') }
	stroke := command.svg().stroke_pattern or { panic('missing retained pattern stroke') }
	assert fill.tile_rect == painting.Rect{10, 5, 25, 10}
	assert stroke.tile_rect == painting.Rect{10, 5, 20, 10}
	assert fill.pattern_transform or { painting.Affine{} } == painting.Affine{ e: 3, f: 4 }
	display_list := fill.tile_display_list or { panic('missing pattern display list') }
	operations := display_list.operations.filter(it.kind == .path)
	assert operations.len == 3
	assert operations.all(it.has_fill)
	assert operations[0].fill_color == painting.Color{10, 20, 30, 255}
	assert operations[1].fill_color == painting.Color{40, 50, 60, 255}
	assert operations[2].fill_linear_gradient != none
	assert fill.cache_key != 0
	serialized := root.render_svg(220, 120)
	assert serialized.contains('<pattern')
	assert serialized.contains('patternUnits="userSpaceOnUse"')
	assert serialized.contains('patternTransform="matrix(1 0 0 1 3 4)"')
	assert serialized.contains('fill="url(#svg-paint')
	assert serialized.contains('fill-opacity="0.600000')
}

fn test_svg_pattern_tile_retains_nested_decoded_image_filter() {
	image_url := 'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAQAAAAECAIAAAAmkwkpAAAAD0lEQVR4nGNgaGBAIOI4ANA0CAF5jtVRAAAAAElFTkSuQmCC'
	document := html.parse_document('<!doctype html><style>html, body { margin: 0 } svg { display:block }</style><svg width="100" height="100"><defs><filter id="image-filter" x="0" y="0" width="100%" height="100%"><feImage href="${image_url}"/></filter><pattern id="tile" width="100" height="100" patternUnits="userSpaceOnUse"><rect width="100" height="100" fill="red" filter="url(#image-filter)"/></pattern></defs><rect width="100" height="100" fill="url(#tile)"/></svg>')
	root := layout_document_typed_in_viewport(document, 100, 100)
	paths := root.paint_commands().filter(it.kind == 'draw_svg_path')
	assert paths.len == 1
	pattern := paths[0].svg().fill_pattern or { panic('missing retained pattern fill') }
	operations := (pattern.tile_display_list or {
		panic('missing pattern display list')
	}).operations
	assert operations.len == 3
	assert operations[0].kind == .begin_filter
	assert operations[1].kind == .path
	assert operations[2].kind == .end_filter
	filter := operations[0].filter or { panic('missing retained tile filter') }
	assert filter.bounds or { painting.Rect{} } == painting.Rect{0, 0, 100, 100}
	root_id := filter.root_id or { panic('missing retained filter root') }
	assert filter.nodes[root_id].kind == 'image'
	assert filter.nodes[root_id].image_url == image_url
	assert pattern.cache_key != 0
}

fn test_svg_pattern_resolves_vector_image_after_recording() {
	image_url := "data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 1 1'%3E%3Crect width='1' height='1' fill='green'/%3E%3C/svg%3E"
	document := html.parse_document('<!doctype html><style>html, body { margin: 0 } svg { display:block }</style><svg width="100" height="100"><defs><pattern id="tile" width="10" height="10" patternUnits="userSpaceOnUse"><image href="${image_url}" width="10" height="10"/></pattern></defs><rect width="100" height="100" fill="url(#tile)"/></svg>')
	root := layout_document_typed_in_viewport(document, 100, 100)
	paths := root.paint_commands().filter(it.kind == 'draw_svg_path')
	assert paths.len == 1
	pattern := paths[0].svg().fill_pattern or { panic('missing retained pattern fill') }
	operations := (pattern.tile_display_list or {
		panic('missing vector-image pattern display list')
	}).operations
	assert operations.all(it.kind != .image)
	vector_paths := operations.filter(it.kind == .path)
	assert vector_paths.len == 1
	assert vector_paths[0].fill_color == painting.Color{0, 128, 0, 255}
	assert math.abs(vector_paths[0].transform.a - 10.0) < 0.001
	assert math.abs(vector_paths[0].transform.d - 10.0) < 0.001
}

fn test_svg_pattern_normalizes_raster_image_coordinates_once() {
	image_url := 'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAQAAAAECAIAAAAmkwkpAAAAD0lEQVR4nGNgaGBAIOI4ANA0CAF5jtVRAAAAAElFTkSuQmCC'
	document := html.parse_document('<!doctype html><svg width="100" height="100"><defs><pattern id="tile" width="100" height="100" patternUnits="userSpaceOnUse"><image href="${image_url}" width="100" height="100"/></pattern></defs><rect width="100" height="100" fill="url(#tile)"/></svg>')
	root := layout_document_typed_in_viewport(document, 120, 120)
	paths := root.paint_commands().filter(it.kind == 'draw_svg_path')
	assert paths.len == 1
	pattern := paths[0].svg().fill_pattern or { panic('missing retained pattern fill') }
	operations := (pattern.tile_display_list or {
		panic('missing raster-image pattern display list')
	}).operations.filter(it.kind == .image)
	assert operations.len == 1
	assert operations[0].transform.map_rect(operations[0].image_rect) == painting.Rect{0, 0, 100, 100}
}

fn test_svg_pattern_viewbox_overrides_object_bounding_box_content_units() {
	document := html.parse_document('<!doctype html><style>html, body { margin: 0 } svg { display:block }</style><svg width="200" height="100"><defs><pattern id="scaled" patternUnits="userSpaceOnUse" patternContentUnits="objectBoundingBox" width="40" height="20" viewBox="0 0 10 10" preserveAspectRatio="none"><rect width="5" height="10" fill="red"/><rect x="5" width="5" height="10" fill="blue"/></pattern></defs><rect x="20" y="10" width="100" height="60" fill="url(#scaled)"/></svg>')
	root := layout_document_typed_in_viewport(document, 220, 120)
	paths := root.paint_commands().filter(it.kind == 'draw_svg_path')
	assert paths.len == 1
	pattern := paths[0].svg().fill_pattern or { panic('missing viewBox pattern fill') }
	assert pattern.tile_rect == painting.Rect{0, 0, 40, 20}
	operations := (pattern.tile_display_list or { panic('missing viewBox tile display list') }).operations.filter(it.kind == .path)
	assert operations.len == 2
	// The pattern viewBox maps 10x10 user units into the 40x20 tile. It takes
	// precedence over patternContentUnits="objectBoundingBox", as in C++.
	assert operations.all(math.abs(it.transform.a - 4.0) < 0.001)
	assert operations.all(math.abs(it.transform.d - 2.0) < 0.001)
}

fn test_svg_pattern_object_bounding_box_geometry_is_target_relative() {
	document := html.parse_document('<!doctype html><style>html, body { margin: 0 } svg { display:block }</style><svg width="560" height="330"><defs><pattern id="bbox" width="25%" height="50%" patternContentUnits="objectBoundingBox"><rect width=".5" height="1" fill="orange"/><rect x=".5" width=".5" height="1" fill="purple"/></pattern></defs><rect x="10" y="145" width="160" height="100" fill="url(#bbox)"/></svg>')
	root := layout_document_typed_in_viewport(document, 560, 330)
	paths := root.paint_commands().filter(it.kind == 'draw_svg_path')
	assert paths.len == 1
	pattern := paths[0].svg().fill_pattern or { panic('missing object-box pattern fill') }
	assert pattern.tile_rect == painting.Rect{10, 145, 40, 50}
	operations := (pattern.tile_display_list or { panic('missing object-box display list') }).operations.filter(it.kind == .path)
	assert operations.len == 2
	assert operations.all(math.abs(it.transform.e) < 0.001)
	assert operations.all(math.abs(it.transform.f) < 0.001)
	assert operations.all(math.abs(it.transform.a - 160.0) < 0.001)
	assert operations.all(math.abs(it.transform.d - 100.0) < 0.001)
}

fn test_svg_mask_path_retains_pattern_instead_of_url_fallback() {
	document := html.parse_document('<!doctype html><style>html, body { margin: 0 } svg { display:block }</style><svg width="100" height="100"><defs><pattern id="checks" width="20%" height="20%"><rect width=".5" height="1" fill="white"/></pattern><mask id="mask"><rect width="100" height="100" fill="url(#checks) red"/></mask></defs><rect width="100" height="100" fill="blue" mask="url(#mask)"/></svg>')
	_ = layout_document_typed_in_viewport(document, 120, 120)
	mut mutable_document := unsafe { &dom.Document(document) }
	display_list := record_retained_display_list(mut mutable_document) or { panic('missing display list') }
	mask_commands := display_list_commands(display_list).filter(it.kind == 'begin_svg_mask_layer')
	assert mask_commands.len == 1
	paths := mask_commands[0].mask_clip().mask_operations.filter(it.kind == .path)
	assert paths.len == 1
	operation := paths[0]
	assert operation.has_fill
	assert operation.fill_color == css.Color{ a: 0 }.serialize()
	pattern := operation.fill_pattern or { panic('missing mask fill pattern') }
	assert pattern.tile_rect == painting.Rect{0, 0, 20, 20}
	assert (pattern.tile_display_list or { panic('missing mask pattern display list') }).operations.len == 1
}

fn test_css_mask_image_url_wraps_the_complete_box_paint_as_an_alpha_mask() {
	document := html.parse_document('<!doctype html><style>html, body { margin: 0 } #target { width: 160px; height: 160px; background: red; mask-image: linear-gradient(transparent, transparent), url("https://example.test/mask.gif"); mask-size: 160px 160px; mask-repeat: no-repeat; }</style><div id="target"></div>')
	_ = layout_document_typed_in_viewport(document, 200, 200)
	mut mutable_document := unsafe { &dom.Document(document) }
	display_list := record_retained_display_list(mut mutable_document) or { panic('missing display list') }
	mask_commands := display_list_commands(display_list).filter(it.kind == 'begin_svg_mask_layer')
	assert mask_commands.len == 1
	mask := mask_commands[0].mask_clip()
	assert !mask.mask_luminance
	assert mask.rect == LayoutRect{0, 0, 160, 160}
	images := mask.mask_operations.filter(it.kind == .image)
	assert images.len == 1
	assert images[0].image_url == 'https://example.test/mask.gif'
	paintable := images[0].image_paintable or { panic('missing CSS mask ImagePaintable') }
	assert paintable.object_fit == .fill
	assert paintable.image_rect == painting.Rect{0, 0, 160, 160}
}

fn test_svg_mask_path_retains_linear_gradient_instead_of_url_fallback() {
	document := html.parse_document('<!doctype html><style>html, body { margin: 0 } svg { display:block }</style><svg width="100" height="100"><defs><linearGradient id="fade"><stop stop-color="black"/><stop offset="100%" stop-color="white"/></linearGradient><mask id="mask"><rect width="100" height="100" fill="url(#fade) red"/></mask></defs><rect width="100" height="100" fill="blue" mask="url(#mask)"/></svg>')
	_ = layout_document_typed_in_viewport(document, 120, 120)
	mut mutable_document := unsafe { &dom.Document(document) }
	display_list := record_retained_display_list(mut mutable_document) or { panic('missing display list') }
	mask_commands := display_list_commands(display_list).filter(it.kind == 'begin_svg_mask_layer')
	assert mask_commands.len == 1
	paths := mask_commands[0].mask_clip().mask_operations.filter(it.kind == .path)
	assert paths.len == 1
	operation := paths[0]
	assert operation.has_fill
	assert operation.fill_color == css.Color{ a: 0 }.serialize()
	gradient := operation.fill_linear_gradient or { panic('missing mask fill gradient') }
	assert gradient.gradient.color_stops.len == 2
	assert gradient.start_point == painting.Point{0, 0}
	assert gradient.end_point == painting.Point{100, 0}
}

fn test_svg_mask_path_retains_radial_gradient_instead_of_url_fallback() {
	document := html.parse_document('<!doctype html><style>html, body { margin: 0 } svg { display:block }</style><svg width="100" height="100"><defs><radialGradient id="fade" fx="25%" fy="30%" fr="10%"><stop stop-color="black"/><stop offset="100%" stop-color="white"/></radialGradient><mask id="mask"><rect width="100" height="100" fill="url(#fade) red"/></mask></defs><rect width="100" height="100" fill="blue" mask="url(#mask)"/></svg>')
	_ = layout_document_typed_in_viewport(document, 120, 120)
	mut mutable_document := unsafe { &dom.Document(document) }
	display_list := record_retained_display_list(mut mutable_document) or { panic('missing display list') }
	mask_commands := display_list_commands(display_list).filter(it.kind == 'begin_svg_mask_layer')
	assert mask_commands.len == 1
	paths := mask_commands[0].mask_clip().mask_operations.filter(it.kind == .path)
	assert paths.len == 1
	operation := paths[0]
	assert operation.has_fill
	assert operation.fill_color == css.Color{ a: 0 }.serialize()
	gradient := operation.fill_radial_gradient or { panic('missing radial mask fill') }
	assert gradient.gradient.color_stops.len == 2
	assert gradient.start_center == painting.Point{25, 30}
	assert gradient.start_radius == 10
	assert gradient.end_center == painting.Point{50, 50}
	assert gradient.end_radius == 50
}

fn test_svg_text_reuses_svg_path_painting_instead_of_generic_text_commands() {
	document := html.parse_document('<!doctype html><style>html, body { margin: 0 }</style><svg width="200" height="100"><text x="20" y="45" font-size="24" fill="rgb(10 20 30)" stroke="rgb(40 50 60)" stroke-width="2">O</text></svg>')
	root := layout_document_typed_in_viewport(document, 240, 140)
	commands := root.paint_commands()
	assert commands.all(it.kind != 'draw_text')
	paths := commands.filter(it.kind == 'draw_svg_path')
	assert paths.len == 1
	assert paths[0].svg().path_data.len > 6 * compatibility_clip_path_segment_stride
	assert paths[0].color == css.Color{10, 20, 30, 255}.serialize()
	assert paths[0].stroke_color == css.Color{40, 50, 60, 255}.serialize()
	assert paths[0].stroke_width == 2
}

fn test_broken_image_shadow_text_tracks_alt_and_source_changes() {
	document := html.parse_document('<!doctype html><style>html,body{margin:0}img{display:block;width:100px;height:30px;color:rgb(10 20 30);font:700 19px monospace}</style><img id="target" src="missing.png" alt="fallback">')
	mut target := document.get_element_by_id('target') or { panic('missing image') }
	image := unsafe { &dom.HTMLImageElement(target) }
	mut image_model := html.html_image_element_model_for_dom_element(image)
	mut image_request := image_model.current_request()
	image_request.set_state(.broken)
	image_model.update_alt_text_shadow_tree()
	mut root := layout_document_typed_in_viewport(document, 240, 140)
	mut commands := root.paint_commands()
	mut text_commands := commands.filter(it.kind == 'draw_text' && it.text == 'fallback')
	assert text_commands.len == 1
	assert text_commands[0].color == css.Color{10, 20, 30, 255}.serialize()
	assert text_commands[0].font_size == 19
	assert text_commands[0].bold
	assert text_commands[0].mono
	assert text_commands[0].glyph_run != none
	// The fallback participates in ordinary inline layout instead of being
	// centered by ImagePaintable's deleted bespoke paint branch.
	assert text_commands[0].glyph_translation_x == 0
	assert text_commands[0].glyph_translation_y > 0
	assert commands.all(it.kind != 'stroke_rounded_rect')
	assert commands.all(it.kind != 'draw_replaced_image')

	target.set_attribute_value('alt', 'updated fallback')
	html.html_image_element_form_associated_element_attribute_changed(image, 'alt', 'fallback', 'updated fallback', none)
	root = layout_document_typed_in_viewport(document, 240, 140)
	commands = root.paint_commands()
	updated_text := commands.filter(it.kind == 'draw_text').map(it.text)
	assert updated_text.join(' ') == 'updated fallback'
	assert updated_text.len == 2

	valid_png := 'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M/wHwAF/gL+X9HkWQAAAABJRU5ErkJggg=='
	target.set_attribute_value('src', valid_png)
	image_model.set_src(valid_png)
	image_request.set_current_url(valid_png)
	image_request.set_state(.partially_available)
	image_model.update_alt_text_shadow_tree()
	assert image_model.is_image_available()
	assert target.shadow_root() == none
	assert document.needs_full_layout_tree_update()
	mut target_node := unsafe { &dom.Node(target.as_node()) }
	target_node.set_needs_layout_update(.html_image_element_update_the_image_data)
	root = layout_document_typed_in_viewport(document, 240, 140)
	result := document_layout_result(document) or { panic('missing image layout') }
	layout_image := typed_paint_node_with_id(result.root, 'target') or { panic('missing image box') }
	assert layout_image.is_image_box()
	commands = root.paint_commands()
	assert commands.all(it.kind != 'draw_text')
	images := commands.filter(it.kind == 'draw_replaced_image')
	assert images.len == 1
	assert images[0].image().image_url == valid_png
}

fn test_svg_html_image_paints_its_isolated_document_as_a_nested_display_list() {
	source := 'data:image/svg+xml,%3Csvg%20xmlns%3D%22http%3A%2F%2Fwww.w3.org%2F2000%2Fsvg%22%20width%3D%2218%22%20height%3D%2218%22%20viewBox%3D%220%200%2018%2018%22%3E%3Cpath%20d%3D%22M0%200H18V18H0Z%22%20fill%3D%22%23ff6600%22%2F%3E%3C%2Fsvg%3E'
	document := html.parse_document('<!doctype html><style>html,body{margin:0}img{display:block;width:18px;height:18px;border:1px solid white}</style><img src="${source}">')
	root := layout_document_typed_in_viewport(document, 80, 60)
	commands := root.paint_commands()
	assert commands.all(it.kind != 'draw_replaced_image')
	nested := commands.filter(it.kind == 'paint_nested_display_list')
	assert nested.len == 1
	assert nested[0].x == 1
	assert nested[0].y == 1
	assert nested[0].width == 18
	assert nested[0].height == 18
	assert nested[0].nested_viewport_commands.any(it.kind == 'draw_svg_path'
		&& it.color == css.Color{255, 102, 0, 255}.serialize())
	assert commands.any(it.kind == 'draw_svg_path'
		&& it.color == css.Color{255, 255, 255, 255}.serialize())
}

fn test_svg_image_uses_image_paintable_contain_sizing_and_resolved_href() {
	document := html.parse_document('<!doctype html><style>html, body { margin: 0 } svg { display:block }</style><svg width="200" height="100" viewBox="0 0 100 50"><image x="10" y="5" width="60" height="30" transform="translate(3 4)" href="https://example.test/picture.png" style="object-position:25% 75%;image-rendering:pixelated"/></svg>')
	root := layout_document_typed_in_viewport(document, 240, 140)
	commands := root.paint_commands()
	images := commands.filter(it.kind == 'draw_replaced_image')
	assert images.len == 1
	image := images[0]
	// SVGFormattingContext maps the image bounding box through viewBox and the
	// element transform before ImagePaintable receives its absolute rectangle.
	assert image.x == 26
	assert image.y == 18
	assert image.width == 120
	assert image.height == 60
	assert image.image().image_url == 'https://example.test/picture.png'
	assert image.image().image_size == 'contain'
	assert image.image().image_position_x == '25%'
	assert image.image().image_position_y == '75%'
	assert image.image().image_rendering == .pixelated
	paintable := image.image_paintable or { panic('missing retained ImagePaintable') }
	assert paintable.is_svg_image
	assert paintable.image_rect == painting.Rect{26, 18, 120, 60}
	assert commands.all(it.kind != 'draw_background_image' || it.image().image_url != image.image().image_url)
}

fn test_svg_image_bounding_box_uses_intrinsic_ratio_for_a_missing_dimension() {
	document := html.parse_document('<!doctype html><style>html, body { margin: 0 } svg { display:block }</style><svg width="200" height="100"><image x="7" y="9" width="80" href="data:image/svg+xml,%3Csvg%20width%3D%2240%22%20height%3D%2220%22%3E%3C/svg%3E"/></svg>')
	root := layout_document_typed_in_viewport(document, 240, 140)
	images := root.paint_commands().filter(it.kind == 'draw_replaced_image')
	assert images.len == 1
	assert images[0].x == 7
	assert images[0].y == 9
	assert images[0].width == 80
	assert images[0].height == 40
}

fn test_svg_image_legacy_xlink_href_is_used_only_when_href_is_absent() {
	document := html.parse_document('<!doctype html><style>html, body { margin: 0 } svg { display:block }</style><svg width="100" height="50"><image width="40" height="20" xlink:href="https://example.test/legacy.png"/><image y="25" width="40" height="20" href="" xlink:href="https://example.test/ignored.png"/></svg>')
	root := layout_document_typed_in_viewport(document, 120, 70)
	images := root.paint_commands().filter(it.kind == 'draw_replaced_image')
	assert images.len == 1
	assert images[0].image().image_url == 'https://example.test/legacy.png'
}

fn test_canvas_uses_canvas_paintable_only_after_a_surface_exists() {
	document := html.parse_document('<!doctype html><style>html,body{margin:0}canvas{display:block;width:100px;height:50px;border:4px solid red;border-radius:12px;image-rendering:pixelated}</style><canvas id="painted" width="20" height="10"></canvas><canvas id="blank"></canvas>')
	painted_element := document.get_element_by_id('painted') or { panic('missing canvas') }
	canvas := unsafe { &dom.HTMLCanvasElement(painted_element) }
	mut context := html.html_canvas_element_get_context(canvas, '2d', none) or { panic(err) }
	context.fill_rect(0, 0, 10, 10)

	root := layout_document_typed_in_viewport(document, 240, 140)
	commands := root.paint_commands().filter(it.kind == 'draw_canvas')
	assert commands.len == 1
	command := commands[0]
	bitmap := command.canvas_bitmap or { panic('canvas surface was not retained') }
	assert bitmap.width == 20
	assert bitmap.height == 10
	paintable := command.canvas_paintable or { panic('CanvasPaintable was not retained') }
	assert paintable.canvas_rect.width == 100
	assert paintable.canvas_rect.height == 50
	assert paintable.border_widths == painting.PixelBox{4, 4, 4, 4}
	resolved := paintable.paint('canvas', painting.IntSize{bitmap.width, bitmap.height}, painting.new_device_pixel_converter(1) or { panic(err) }) or {
		panic('canvas surface did not produce a paint command')
	}
	assert resolved.content.destination.width == 100
	assert resolved.content.destination.height == 50
	assert resolved.content.scaling == .nearest_neighbor
	assert resolved.clip_radii.top_left == painting.CornerRadius{8, 8}
}

fn test_video_uses_the_paintable_representation_switch() {
	mut document := html.parse_document('<!doctype html><style>html,body{margin:0}video{display:block;width:100px;height:50px;border:4px solid red;border-radius:12px;image-rendering:pixelated}</style><video id="frame"></video><video id="poster"></video><video id="blank"></video>')
	document.set_browsing_context(&dom.BrowsingContext{})
	mut navigable := &dom.Navigable{
		active_document_: document
		is_top_level_traversable_: true
	}
	navigable.traversable_navigable_ = navigable
	document.set_cached_navigable(navigable)
	frame_element := document.get_element_by_id('frame') or { panic('missing frame video') }
	frame_video := unsafe { &dom.HTMLVideoElement(frame_element) }
	mut frame_model := html.html_video_element_model_for_dom_element(frame_video)
	mut frame_media := frame_model.media
	frame_media.set_fetch_hook(typed_video_paint_fetch)
	frame_media.set_source('https://example.test/movie.mp4')
	frame_media.load() or { panic(err) }
	assert frame_media.ready_state() != .have_nothing
	assert frame_media.video_tracks().length() == 1
	frame_media.set_current_playback_position(1)
	mut media_loop := html.main_thread_event_loop()
	media_loop.process()
	frame_model.set_current_frame(&dom.Bitmap_{
		width: 20
		height: 10
		pitch: 80
		data: []u8{len: 20 * 10 * 4}
	})
	assert frame_model.current_representation() == .video_frame
	assert frame_model.natural_media_size()? == html.VideoDimensions{20, 10}

	poster_element := document.get_element_by_id('poster') or { panic('missing poster video') }
	poster_video := unsafe { &dom.HTMLVideoElement(poster_element) }
	mut poster_model := html.html_video_element_model_for_dom_element(poster_video)
	poster_model.set_poster_fetch_hook(typed_video_poster_fetch)
	poster_model.set_poster('https://example.test/poster.png')

	root := layout_document_typed_in_viewport(document, 240, 190)
	commands := root.paint_commands().filter(it.kind == 'draw_video')
	assert commands.len == 3
	assert commands.any(it.video_representation == .video_frame)
	assert commands.any(it.video_representation == .poster_frame)
	assert commands.any(it.video_representation == .transparent_black)
	frame_command := commands.filter(it.video_representation == .video_frame)[0]
	assert frame_command.video_bitmap == none
	frame_source := frame_command.video_frame_source or { panic('missing video frame source') }
	frame_result := (frame_command.video_paintable or { panic('missing VideoPaintable') }).paint(frame_command.video_representation, 'video', none, frame_source, painting.new_device_pixel_converter(1) or { panic(err) }) or {
		panic('missing video frame paint result')
	}
	assert frame_result.content is painting.DrawVideoFrameSource
	assert (frame_result.content as painting.DrawVideoFrameSource).scaling == .nearest_neighbor
	assert frame_result.clip_radii.top_left == painting.CornerRadius{8, 8}
	frame_model.set_current_frame(&dom.Bitmap_{
		width: 40
		height: 20
		pitch: 160
		data: []u8{len: 40 * 20 * 4}
	})
	assert frame_source.current_frame()?.width == 40

	poster_command := commands.filter(it.video_representation == .poster_frame)[0]
	poster_bitmap := poster_command.video_bitmap or { panic('missing poster frame') }
	poster_result := (poster_command.video_paintable or { panic('missing poster VideoPaintable') }).paint(poster_command.video_representation, 'poster', painting.IntSize{poster_bitmap.width, poster_bitmap.height}, none, painting.new_device_pixel_converter(1) or { panic(err) }) or {
		panic('missing poster paint result')
	}
	assert poster_result.content is painting.DrawScaledDecodedImageFrame

	blank_command := commands.filter(it.video_representation == .transparent_black)[0]
	assert blank_command.video_bitmap == none
	blank_result := (blank_command.video_paintable or { panic('missing blank VideoPaintable') }).paint(blank_command.video_representation, '', none, none, painting.new_device_pixel_converter(1) or { panic(err) }) or {
		panic('missing transparent paint result')
	}
	assert blank_result.content is painting.FillRect
}

fn test_iframe_replays_the_hosted_document_as_a_nested_display_list() {
	mut document := html.parse_document('<!doctype html><style>html,body{margin:0}iframe{display:block;width:120px;height:60px;border:4px solid red;border-radius:12px}</style><iframe id="frame" srcdoc="<style>html,body{margin:0}body{background:rgb(12 34 56)}</style><p>nested</p>"></iframe>')
	root := layout_document_typed_in_viewport(document, 240, 140)
	iframe_element := document.get_element_by_id('frame') or { panic('missing iframe') }
	iframe_box := root.find_box(i64(iframe_element.as_node().unique_id())) or {
		panic('missing iframe paint box')
	}
	mut hosted_document := iframe_box.nested_viewport_document or {
		panic('missing hosted document')
	}
	blocker := hosted_document.create_element('style') or { panic(err) }
	hosted_document.add_render_blocking_element(blocker)
	assert root.paint_commands().all(it.kind != 'paint_nested_display_list')
	hosted_document.remove_render_blocking_element(blocker)

	commands := root.paint_commands().filter(it.kind == 'paint_nested_display_list')
	assert commands.len == 1
	command := commands[0]
	assert command.x == 4
	assert command.y == 4
	assert command.width == 120
	assert command.height == 60
	assert command.nested_viewport_commands.any(it.kind == 'fill_rect'
		&& it.color == 'rgb(12 34 56)')
	assert command.nested_viewport_commands.any(it.kind == 'draw_text' && it.text == 'nested')
	paintable := command.nested_viewport_paintable or { panic('missing nested viewport paintable') }
	result := paintable.paint(painting.new_device_pixel_converter(1) or { panic(err) }) or {
		panic('missing nested viewport paint result')
	}
	assert result.clip_rect == painting.IntRect{4, 4, 120, 60}
	assert result.nested_rect == result.clip_rect
	assert result.clip_radii.top_left == painting.CornerRadius{8, 8}
}

fn test_url_svg_clip_path_is_a_retained_alpha_mask_not_a_painted_child_or_hit_test_clip() {
	document := html.parse_document('<!doctype html><style>html, body { margin: 0 } svg { display:block }</style><svg width="140" height="120" viewBox="0 0 140 120"><defs><clipPath id="cut"><circle cx="60" cy="50" r="35" clip-rule="evenodd"/></clipPath></defs><rect id="target" x="10" y="0" width="100" height="100" fill="rgb(101 102 103)" clip-path="url(#cut)"/></svg>')
	_ = layout_document_typed_in_viewport(document, 320, 200)
	mut mutable_document := unsafe { &dom.Document(document) }
	display_list := record_retained_display_list(mut mutable_document) or { panic('missing display list') }
	paths := display_list_commands(display_list).filter(it.kind == 'draw_svg_path')
	// SVGMaskable paints the attached clip resource into a separate mask display
	// list; the resource geometry must not leak into the target display list.
	assert paths.len == 1
	command := paths[0]
	assert command.has_clip
	commands := display_list_commands(display_list)
	mask_begins := commands.filter(it.kind == 'begin_svg_mask_layer')
	mask_ends := commands.filter(it.kind == 'end_svg_mask_layer')
	assert mask_begins.len == 1
	assert mask_ends.len == 1
	clip := mask_begins[0].mask_clip()
	assert clip.is_svg_mask
	assert clip.path_components.len == 1
	// SVGMaskable::get_svg_clip_area() derives this from the transformed
	// descendant geometry; the <clipPath> resource box itself has no bounds.
	assert clip.rect == LayoutRect{25, 15, 70, 70}
	component := clip.path_components[0]
	assert component.path_even_odd
	assert component.path_data.len == 5 * compatibility_clip_path_segment_stride
	assert component.path_data[compatibility_clip_path_segment_stride] == 4
	assert component.transform == [f64(1), 0, 0, 1, 0, 0]!

	// StackingContext::hit_test() does not consult SVG mask alpha.
	target := document.get_element_by_id('target') or { panic('missing target') }
	hit := mutable_document.element_from_point(12, 12) or { panic('missing target hit') }
	assert hit.as_node().unique_id() == target.as_node().unique_id()
}

fn test_url_svg_clip_path_prepends_target_and_resource_transforms() {
	document := html.parse_document('<!doctype html><style>html, body { margin: 0 } svg { display:block }</style><svg width="280" height="240" viewBox="0 0 140 120"><defs><clipPath id="cut" transform="translate(3 4)"><circle cx="60" cy="50" r="35"/></clipPath></defs><rect transform="translate(7 8)" x="10" y="5" width="100" height="80" fill="red" clip-path="url(#cut)"/></svg>')
	_ = layout_document_typed_in_viewport(document, 320, 260)
	mut mutable_document := unsafe { &dom.Document(document) }
	display_list := record_retained_display_list(mut mutable_document) or { panic('missing display list') }
	paths := display_list_commands(display_list).filter(it.kind == 'draw_svg_path')
	assert paths.len == 1
	mask_begins := display_list_commands(display_list).filter(it.kind == 'begin_svg_mask_layer')
	assert mask_begins.len == 1
	clip := mask_begins[0].mask_clip()
	assert clip.is_svg_mask
	assert clip.path_components.len == 1
	// root viewBox scale(2) * target translate(7,8) * clipPath translate(3,4)
	assert clip.path_components[0].transform == [f64(2), 0, 0, 2, 20, 24]!
}

fn test_object_bounding_box_svg_clip_retains_every_component_for_union_mask() {
	document := html.parse_document('<!doctype html><style>html, body { margin: 0 } svg { display:block }</style><svg width="280" height="240" viewBox="0 0 140 120"><defs><clipPath id="cut" clipPathUnits="objectBoundingBox"><circle cx=".3" cy=".5" r=".2"/><circle cx=".7" cy=".5" r=".2"/></clipPath></defs><rect x="10" y="5" width="100" height="80" fill="red" clip-path="url(#cut)"/></svg>')
	_ = layout_document_typed_in_viewport(document, 320, 260)
	mut mutable_document := unsafe { &dom.Document(document) }
	display_list := record_retained_display_list(mut mutable_document) or { panic('missing display list') }
	paths := display_list_commands(display_list).filter(it.kind == 'draw_svg_path')
	assert paths.len == 1
	mask_begins := display_list_commands(display_list).filter(it.kind == 'begin_svg_mask_layer')
	assert mask_begins.len == 1
	clip := mask_begins[0].mask_clip()
	assert clip.is_svg_mask
	assert clip.path_components.len == 2
	assert clip.path_components.all(it.transform == [f64(200), 0, 0, 160, 20, 10]!)
	assert clip.cache_key != 0
}

fn test_svg_clip_path_bounds_ignore_invisible_descendant_geometry() {
	document := html.parse_document('<!doctype html><style>html, body { margin: 0 } svg { display:block }</style><svg width="200" height="160"><defs><clipPath id="cut"><g visibility="hidden"><rect x="0" y="0" width="200" height="160"/></g><rect x="30" y="40" width="50" height="60"/></clipPath></defs><rect width="200" height="160" fill="red" clip-path="url(#cut)"/></svg>')
	_ = layout_document_typed_in_viewport(document, 220, 180)
	mut mutable_document := unsafe { &dom.Document(document) }
	display_list := record_retained_display_list(mut mutable_document) or { panic('missing display list') }
	mask_begins := display_list_commands(display_list).filter(it.kind == 'begin_svg_mask_layer')
	assert mask_begins.len == 1
	clip := mask_begins[0].mask_clip()
	assert clip.path_components.len == 1
	assert clip.rect == LayoutRect{30, 40, 50, 60}
}

fn test_empty_url_svg_clip_path_fully_clips_the_target() {
	document := html.parse_document('<!doctype html><style>html, body { margin: 0 } svg { display:block }</style><svg width="100" height="100"><defs><clipPath id="empty"/></defs><rect width="100" height="100" fill="red" clip-path="url(#empty)"/></svg>')
	_ = layout_document_typed_in_viewport(document, 120, 120)
	mut mutable_document := unsafe { &dom.Document(document) }
	display_list := record_retained_display_list(mut mutable_document) or { panic('missing display list') }
	paths := display_list_commands(display_list).filter(it.kind == 'draw_svg_path')
	assert paths.len == 1
	mask_begins := display_list_commands(display_list).filter(it.kind == 'begin_svg_mask_layer')
	assert mask_begins.len == 1
	assert mask_begins[0].mask_clip().path_components.len == 0
	assert paths[0].clip_width == 0
	assert paths[0].clip_height == 0
}

fn test_svg_clip_mask_wraps_the_complete_target_context_once() {
	document := html.parse_document('<!doctype html><style>html, body { margin: 0 } svg { display:block }</style><svg width="160" height="100"><defs><clipPath id="cut"><circle cx="60" cy="50" r="40"/></clipPath></defs><g clip-path="url(#cut)"><rect width="120" height="50" fill="red"/><rect y="50" width="120" height="50" fill="green"/></g></svg>')
	_ = layout_document_typed_in_viewport(document, 180, 120)
	mut mutable_document := unsafe { &dom.Document(document) }
	display_list := record_retained_display_list(mut mutable_document) or { panic('missing display list') }
	commands := display_list_commands(display_list)
	paths := commands.filter(it.kind == 'draw_svg_path')
	assert paths.len == 2
	mask_begins := commands.filter(it.kind == 'begin_svg_mask_layer')
	mask_ends := commands.filter(it.kind == 'end_svg_mask_layer')
	assert mask_begins.len == 1
	assert mask_ends.len == 1
	assert mask_begins[0].mask_clip().cache_key == mask_ends[0].mask_clip().cache_key
	assert mask_begins[0].mask_clip().path_components.len == 1
	mut inside_mask := false
	mut masked_paths := 0
	for command in commands {
		if command.kind == 'begin_svg_mask_layer' {
			inside_mask = true
		} else if command.kind == 'end_svg_mask_layer' {
			inside_mask = false
		} else if command.kind == 'draw_svg_path' {
			assert inside_mask
			masked_paths++
		}
	}
	assert masked_paths == 2
}

fn test_url_svg_mask_retains_luminance_paint_and_group_opacity_layers() {
	document := html.parse_document('<!doctype html><style>html, body { margin: 0 } svg { display:block }</style><svg width="280" height="240" viewBox="0 0 140 120"><defs><mask id="fade" mask-type="luminance" transform="translate(3 4)"><g opacity=".5"><path d="M 0 0 C 25 0 25 40 50 40 Z" fill="rgb(200 20 10)" fill-opacity=".4" stroke="rgb(10 20 200)" stroke-opacity=".6" stroke-width="3" stroke-linecap="round" stroke-linejoin="bevel" stroke-miterlimit="7" paint-order="stroke fill"/></g></mask></defs><rect transform="translate(7 8)" x="10" y="5" width="100" height="80" fill="red" mask="url(#fade)"/></svg>')
	_ = layout_document_typed_in_viewport(document, 320, 260)
	mut mutable_document := unsafe { &dom.Document(document) }
	display_list := record_retained_display_list(mut mutable_document) or { panic('missing display list') }
	commands := display_list_commands(display_list)
	paths := commands.filter(it.kind == 'draw_svg_path')
	mask_begins := commands.filter(it.kind == 'begin_svg_mask_layer')
	mask_ends := commands.filter(it.kind == 'end_svg_mask_layer')
	assert paths.len == 1
	assert mask_begins.len == 1
	assert mask_ends.len == 1
	mask := mask_begins[0].mask_clip()
	assert mask.is_svg_content_mask
	assert mask.mask_luminance
	assert mask.mask_operations.len == 3
	assert mask.mask_operations[0].kind == .begin_opacity
	assert math.abs(mask.mask_operations[0].opacity - 0.5) < 0.001
	operation := mask.mask_operations[1]
	assert operation.kind == .path
	assert operation.path_data.len == 3 * compatibility_clip_path_segment_stride
	assert operation.transform == [f64(2), 0, 0, 2, 20, 24]!
	assert operation.fill_color == css.Color{200, 20, 10, 255}.serialize()
	assert operation.stroke_color == css.Color{10, 20, 200, 255}.serialize()
	assert operation.has_fill
	assert operation.has_stroke
	assert operation.stroke_first
	assert math.abs(operation.fill_opacity - 0.4) < 0.001
	assert math.abs(operation.stroke_opacity - 0.6) < 0.001
	assert operation.stroke_width == 3
	assert operation.stroke_linecap == 1
	assert operation.stroke_linejoin == 2
	assert operation.stroke_miterlimit == 7
	assert mask.mask_operations[2].kind == .end_opacity
	mut inside_mask := false
	for command in commands {
		if command.kind == 'begin_svg_mask_layer' {
			inside_mask = true
		} else if command.kind == 'end_svg_mask_layer' {
			inside_mask = false
		} else if command.kind == 'draw_svg_path' {
			assert inside_mask
		}
	}
}

fn test_svg_mask_text_is_the_same_retained_glyph_path_as_normal_svg_painting() {
	document := html.parse_document('<!doctype html><style>html, body { margin: 0 } svg { display:block }</style><svg width="180" height="100"><defs><mask id="letters" mask-type="alpha"><text x="10" y="60" font-size="48" fill="white" stroke="rgb(20 30 40)" stroke-width="2">O</text></mask></defs><rect width="180" height="100" fill="red" mask="url(#letters)"/></svg>')
	_ = layout_document_typed_in_viewport(document, 200, 120)
	mut mutable_document := unsafe { &dom.Document(document) }
	display_list := record_retained_display_list(mut mutable_document) or { panic('missing display list') }
	commands := display_list_commands(display_list)
	assert commands.all(it.kind != 'draw_text')
	mask_begins := commands.filter(it.kind == 'begin_svg_mask_layer')
	assert mask_begins.len == 1
	operations := mask_begins[0].mask_clip().mask_operations.filter(it.kind == .path)
	assert operations.len == 1
	assert operations[0].path_data.len > 6 * compatibility_clip_path_segment_stride
	assert operations[0].fill_color == css.Color{255, 255, 255, 255}.serialize()
	assert operations[0].stroke_color == css.Color{20, 30, 40, 255}.serialize()
	assert operations[0].stroke_width == 2
}

fn test_svg_mask_text_path_reuses_rotated_glyph_geometry_without_text_fallback() {
	document := html.parse_document('<!doctype html><style>html, body { margin: 0 } svg { display:block }</style><svg width="180" height="120"><defs><path id="guide" d="M 20 10 L 20 110"/><mask id="letters" mask-type="alpha"><text fill="white"><textPath href="#guide" font-size="28">OO</textPath></text></mask></defs><rect width="180" height="120" fill="red" mask="url(#letters)"/></svg>')
	_ = layout_document_typed_in_viewport(document, 200, 140)
	mut mutable_document := unsafe { &dom.Document(document) }
	display_list := record_retained_display_list(mut mutable_document) or { panic('missing display list') }
	commands := display_list_commands(display_list)
	assert commands.all(it.kind != 'draw_text')
	mask_begins := commands.filter(it.kind == 'begin_svg_mask_layer')
	assert mask_begins.len == 1
	operations := mask_begins[0].mask_clip().mask_operations.filter(it.kind == .path)
	assert operations.len == 1
	assert operations[0].path_data.len > 12 * compatibility_clip_path_segment_stride
	assert operations[0].fill_color == css.Color{255, 255, 255, 255}.serialize()
}

fn test_svg_mask_retains_image_paintable_between_group_opacity_boundaries() {
	document := html.parse_document('<!doctype html><style>html, body { margin: 0 } svg { display:block }</style><svg width="200" height="100"><defs><mask id="picture" mask-type="luminance"><g opacity=".4"><image x="10" y="12" width="80" height="40" href="https://example.test/mask.png" style="object-position:25% 75%;image-rendering:crisp-edges"/></g></mask></defs><rect width="180" height="90" fill="red" mask="url(#picture)"/></svg>')
	_ = layout_document_typed_in_viewport(document, 240, 140)
	mut mutable_document := unsafe { &dom.Document(document) }
	display_list := record_retained_display_list(mut mutable_document) or { panic('missing display list') }
	commands := display_list_commands(display_list)
	assert commands.all(it.kind != 'draw_svg_image')
	mask_begins := commands.filter(it.kind == 'begin_svg_mask_layer')
	assert mask_begins.len == 1
	mask := mask_begins[0].mask_clip()
	assert mask.mask_luminance
	assert mask.mask_operations.len == 3
	assert mask.mask_operations[0].kind == .begin_opacity
	assert math.abs(mask.mask_operations[0].opacity - 0.4) < 0.001
	image := mask.mask_operations[1]
	assert image.kind == .image
	assert image.image_url == 'https://example.test/mask.png'
	assert image.image_rect == LayoutRect{10, 12, 80, 40}
	assert image.image_position_x == '25%'
	assert image.image_position_y == '75%'
	assert image.image_rendering == .crisp_edges
	image_paintable := image.image_paintable or { panic('mask image lost its ImagePaintable') }
	assert image_paintable.is_svg_image
	assert image_paintable.image_rect == painting.Rect{10, 12, 80, 40}
	assert image_paintable.object_position.offset_x.to_px(image_paintable.resolution_context, css.CSSPixels.new(100)).to_double() == 25
	assert image_paintable.object_position.offset_y.to_px(image_paintable.resolution_context, css.CSSPixels.new(100)).to_double() == 75
	assert image.transform == [f64(1), 0, 0, 1, 0, 0]!
	assert mask.mask_operations[2].kind == .end_opacity
	assert mask.cache_key != 0
}

fn test_alpha_svg_mask_and_empty_svg_mask_keep_upstream_mask_semantics() {
	document := html.parse_document('<!doctype html><style>html, body { margin: 0 } svg { display:block }</style><svg width="220" height="100"><defs><mask id="alpha" mask-type="alpha"><rect x="10" y="10" width="50" height="50" fill="rgb(1 2 3)"/></mask><mask id="empty" mask-type="alpha"/></defs><rect width="100" height="100" fill="red" mask="url(#alpha)"/><rect x="110" width="100" height="100" fill="blue" mask="url(#empty)"/></svg>')
	_ = layout_document_typed_in_viewport(document, 240, 120)
	mut mutable_document := unsafe { &dom.Document(document) }
	display_list := record_retained_display_list(mut mutable_document) or { panic('missing display list') }
	commands := display_list_commands(display_list)
	masks := commands.filter(it.kind == 'begin_svg_mask_layer').map(it.mask_clip())
	assert masks.len == 2
	assert masks.all(!it.mask_luminance)
	mut painted_masks := []PaintClip{}
	mut empty_masks := []PaintClip{}
	for mask in masks {
		if mask.mask_operations.any(it.kind == .path) {
			painted_masks << mask
		} else {
			empty_masks << mask
		}
	}
	assert painted_masks.len == 1
	assert empty_masks.len == 1
	empty_mask := empty_masks[0]
	// A non-empty resolved mask area with an empty nested display list still
	// clears the target through DestinationIn.
	assert empty_mask.rect.width > 0
	assert empty_mask.mask_operations.all(it.kind != .path)
}

fn test_svg_mask_and_clip_layers_are_nested_in_upstream_order() {
	document := html.parse_document('<!doctype html><style>html, body { margin: 0 } svg { display:block }</style><svg width="120" height="100"><defs><mask id="fade" mask-type="alpha"><rect width="120" height="100" fill="white" fill-opacity=".5"/></mask><clipPath id="cut"><circle cx="60" cy="50" r="40"/></clipPath></defs><g mask="url(#fade)" clip-path="url(#cut)"><rect width="80" height="100" fill="blue"/><rect x="40" width="80" height="100" fill="blue"/></g></svg>')
	_ = layout_document_typed_in_viewport(document, 140, 120)
	mut mutable_document := unsafe { &dom.Document(document) }
	display_list := record_retained_display_list(mut mutable_document) or { panic('missing display list') }
	commands := display_list_commands(display_list)
	mut significant := []string{}
	for command in commands {
		if command.kind in ['begin_svg_mask_layer', 'draw_svg_path', 'end_svg_mask_layer'] {
			significant << if command.kind == 'begin_svg_mask_layer' {
				if command.mask_clip().is_svg_content_mask { 'begin-mask' } else { 'begin-clip' }
			} else if command.kind == 'end_svg_mask_layer' {
				if command.mask_clip().is_svg_content_mask { 'end-mask' } else { 'end-clip' }
			} else {
				'path'
			}
		}
	}
	assert significant == ['begin-mask', 'begin-clip', 'path', 'path', 'end-clip', 'end-mask']
}

fn test_object_bounding_box_svg_mask_content_uses_target_geometry() {
	document := html.parse_document('<!doctype html><style>html, body { margin: 0 } svg { display:block }</style><svg width="280" height="240" viewBox="0 0 140 120"><defs><mask id="fade" mask-type="alpha" maskContentUnits="objectBoundingBox"><circle cx=".5" cy=".5" r=".4" fill="white"/></mask></defs><rect x="10" y="5" width="100" height="80" fill="red" mask="url(#fade)"/></svg>')
	_ = layout_document_typed_in_viewport(document, 320, 260)
	mut mutable_document := unsafe { &dom.Document(document) }
	display_list := record_retained_display_list(mut mutable_document) or { panic('missing display list') }
	mask_begins := display_list_commands(display_list).filter(it.kind == 'begin_svg_mask_layer')
	assert mask_begins.len == 1
	mask := mask_begins[0].mask_clip()
	assert mask.is_svg_content_mask
	paths := mask.mask_operations.filter(it.kind == .path)
	assert paths.len == 1
	// root viewBox scale(2) * target object bounding box(100x80 at 10,5)
	assert paths[0].transform == [f64(200), 0, 0, 160, 20, 10]!
	assert mask.rect == LayoutRect{-1, -6, 241, 192}
}

fn test_svg_mask_areas_resolve_in_target_user_space() {
	document := html.parse_document('<!doctype html><style>html, body { margin: 0 } svg { display:block }</style><svg width="200" viewBox="0 0 100 100"><defs><mask id="user"><circle cx="50" cy="50" r="35"/></mask><mask id="object" maskContentUnits="objectBoundingBox"><circle cx=".5" cy=".5" r=".35"/></mask></defs><rect id="lower" y="55" width="45" height="45"/><rect id="right" x="55" width="45" height="45"/><use mask="url(#user)" href="#lower"/><use mask="url(#object)" href="#right"/></svg>')
	_ = layout_document_typed_in_viewport(document, 240, 240)
	mut mutable_document := unsafe { &dom.Document(document) }
	display_list := record_retained_display_list(mut mutable_document) or { panic('missing display list') }
	masks := display_list_commands(display_list).filter(it.kind == 'begin_svg_mask_layer').map(it.mask_clip())
	assert masks.len == 2
	assert masks[0].rect == LayoutRect{-9, 101, 108, 108}
	assert masks[1].rect == LayoutRect{101, -9, 108, 108}
}

fn test_sticky_element_uses_live_scroll_frame_without_rebuilding_phase_commands() {
	document := html.parse_document('<!doctype html><style>html, body { margin: 0 } #scroller { width: 100px; height: 50px; overflow: auto } #before { height: 30px } #sticky { position: sticky; top: 0; height: 10px; background: rgb(21 22 23) } #after { height: 100px; background: rgb(31 32 33) }</style><body><div id="scroller"><div id="before"></div><div id="sticky"></div><div id="after"></div></div></body>')
	_ = layout_document_typed_in_viewport(document, 320, 200)
	mut mutable_document := unsafe { &dom.Document(document) }
	initial_display_list := record_retained_display_list(mut mutable_document) or {
		panic('missing initial display list')
	}
	sticky_color := css.Color{21, 22, 23, 255}.serialize()
	initial_sticky_commands := display_list_commands(initial_display_list).filter(it.kind == 'fill_rect'
		&& it.color == sticky_color)
	assert initial_sticky_commands.len == 1
	assert initial_sticky_commands[0].transform[5] == 0

	mut result := document_layout_result(document) or { panic('missing layout result') }
	// ViewportPaintable always owns the root scrolling frame; the overflow box
	// contributes the second ordinary frame.
	mut scrolling_frame_indices := []int{}
	mut sticky_frame_indices := []int{}
	scrolling_frame_indices_pointer := &scrolling_frame_indices
	sticky_frame_indices_pointer := &sticky_frame_indices
	result.scroll_state.for_each_scroll_frame(fn [scrolling_frame_indices_pointer] (index int, mut _ painting.ScrollFrame) {
		append_typed_scroll_frame_index(scrolling_frame_indices_pointer, index)
	})
	result.scroll_state.for_each_sticky_frame(fn [sticky_frame_indices_pointer] (index int, mut _ painting.ScrollFrame) {
		append_typed_scroll_frame_index(sticky_frame_indices_pointer, index)
	})
	assert scrolling_frame_indices.len == 2
	assert sticky_frame_indices.len == 1
	assert !result.scroll_state.needs_refresh()
	retained_command_count := result.paint_phase_command_count

	scroller := document.get_element_by_id('scroller') or { panic('missing scroller') }
	mut scroller_paintable := scroller.paintable_box() or { panic('missing scroller paintable') }
	assert scroller_paintable.set_scroll_offset(dom.CSSPixelPoint_{ y_: 40 })
	assert result.scroll_state.needs_refresh()
	scrolled_display_list := record_retained_display_list(mut mutable_document) or {
		panic('missing scrolled display list')
	}
	scrolled_sticky_commands := display_list_commands(scrolled_display_list).filter(it.kind == 'fill_rect'
		&& it.color == sticky_color)
	assert scrolled_sticky_commands.len == 1
	// The ancestor contributes -40 and the sticky constraint contributes +10,
	// keeping the box whose layout y is 30 at the top of the scrollport.
	assert scrolled_sticky_commands[0].transform[5] == -30
	assert result.paint_phase_command_count == retained_command_count
	assert !result.scroll_state.needs_refresh()

	sticky := document.get_element_by_id('sticky') or { panic('missing sticky') }
	snapshot_storage := result.scroll_state_snapshot.device_offsets.data
	hit := mutable_document.element_from_point(10, 5) or { panic('missing sticky hit') }
	assert hit.as_node().unique_id() == sticky.as_node().unique_id()
	// ViewportPaintable retains the snapshot until scroll state is dirtied;
	// hit testing must not allocate and copy the frame vector on every query.
	assert result.scroll_state_snapshot.device_offsets.data == snapshot_storage
	second_hit := mutable_document.element_from_point(10, 5) or { panic('missing repeated sticky hit') }
	assert second_hit.as_node().unique_id() == sticky.as_node().unique_id()
	assert result.scroll_state_snapshot.device_offsets.data == snapshot_storage

	// Element::set_scroll_offset() owns invalidation next to the stored value,
	// including callers which do not go through PaintableBox.
	mut mutable_scroller := unsafe { &dom.Element(scroller) }
	mutable_scroller.set_scroll_offset(none, dom.CSSPixelPoint_{ y_: 45 })
	assert result.scroll_state.needs_refresh()
	mutable_document.update_paint_and_hit_testing_properties_if_needed()
	assert !result.scroll_state.needs_refresh()
	assert result.scroll_state_snapshot.device_offset_for_index(scrolling_frame_indices[1]) == painting.Point{0, -45}
	mutable_scroller.set_scroll_offset(none, dom.CSSPixelPoint_{ y_: 45 })
	assert !result.scroll_state.needs_refresh()
}

fn test_sticky_element_uses_the_viewport_scroll_frame() {
	document := html.parse_document('<!doctype html><style>html, body { margin: 0 } #before { height: 30px } #sticky { position: sticky; top: 0; height: 10px; background: rgb(61 62 63) } #after { height: 150px }</style><body><div id="before"></div><div id="sticky"></div><div id="after"></div></body>')
	_ = layout_document_typed_in_viewport(document, 320, 100)
	mut mutable_document := unsafe { &dom.Document(document) }
	initial_display_list := record_retained_display_list(mut mutable_document) or {
		panic('missing initial display list')
	}
	sticky_color := css.Color{61, 62, 63, 255}.serialize()
	initial_sticky_commands := display_list_commands(initial_display_list).filter(it.kind == 'fill_rect'
		&& it.color == sticky_color)
	assert initial_sticky_commands.len == 1
	assert initial_sticky_commands[0].transform[5] == 0

	mut result := document_layout_result(document) or { panic('missing layout result') }
	mut scrolling_frame_indices := []int{}
	mut sticky_frame_indices := []int{}
	scrolling_frame_indices_pointer := &scrolling_frame_indices
	sticky_frame_indices_pointer := &sticky_frame_indices
	result.scroll_state.for_each_scroll_frame(fn [scrolling_frame_indices_pointer] (index int, mut _ painting.ScrollFrame) {
		append_typed_scroll_frame_index(scrolling_frame_indices_pointer, index)
	})
	result.scroll_state.for_each_sticky_frame(fn [sticky_frame_indices_pointer] (index int, mut _ painting.ScrollFrame) {
		append_typed_scroll_frame_index(sticky_frame_indices_pointer, index)
	})
	assert scrolling_frame_indices.len == 1
	assert sticky_frame_indices.len == 1
	retained_command_count := result.paint_phase_command_count

	viewport := mutable_document.viewport_rect()
	mutable_document.set_viewport_rect(dom.Rect{0, 40, viewport.width, viewport.height})
	assert mutable_document.cached_display_list() == none
	scrolled_display_list := record_retained_display_list(mut mutable_document) or {
		panic('missing scrolled display list')
	}
	scrolled_sticky_commands := display_list_commands(scrolled_display_list).filter(it.kind == 'fill_rect'
		&& it.color == sticky_color)
	assert scrolled_sticky_commands.len == 1
	// The viewport contributes -40 while the sticky constraint contributes +10.
	assert scrolled_sticky_commands[0].transform[5] == -30
	assert result.paint_phase_command_count == retained_command_count

	sticky := document.get_element_by_id('sticky') or { panic('missing sticky') }
	hit := mutable_document.element_from_point(10, 5) or { panic('missing sticky hit') }
	assert hit.as_node().unique_id() == sticky.as_node().unique_id()
}

fn test_fixed_visual_context_bypasses_viewport_scroll_for_paint_and_hit_testing() {
	document := html.parse_document('<!doctype html><style>html, body { margin: 0 } #spacer { height: 100px } #target { height: 20px; background: rgb(41 42 43) } #fixed { position: fixed; top: 5px; left: 0; width: 20px; height: 20px; background: rgb(51 52 53) }</style><body><div id="spacer"></div><div id="target"></div><div id="fixed"></div></body>')
	_ = layout_document_typed_in_viewport(document, 320, 100)
	mut mutable_document := unsafe { &dom.Document(document) }
	display_list := record_retained_display_list(mut mutable_document) or { panic('missing display list') }
	commands := display_list_commands(display_list)
	fixed_color := css.Color{51, 52, 53, 255}.serialize()
	target_color := css.Color{41, 42, 43, 255}.serialize()
	fixed_commands := commands.filter(it.kind == 'fill_rect' && it.color == fixed_color)
	target_commands := commands.filter(it.kind == 'fill_rect' && it.color == target_color)
	assert fixed_commands.len == 1 && fixed_commands[0].fixed_to_viewport
	assert target_commands.len == 1 && !target_commands[0].fixed_to_viewport

	viewport := mutable_document.viewport_rect()
	mutable_document.set_viewport_rect(dom.Rect{0, 100, viewport.width, viewport.height})
	scrolled_display_list := record_retained_display_list(mut mutable_document) or {
		panic('missing scrolled display list')
	}
	scrolled_commands := display_list_commands(scrolled_display_list)
	scrolled_fixed := scrolled_commands.filter(it.kind == 'fill_rect' && it.color == fixed_color)
	scrolled_target := scrolled_commands.filter(it.kind == 'fill_rect' && it.color == target_color)
	assert scrolled_fixed.len == 1 && scrolled_fixed[0].transform[5] == 0
	assert scrolled_target.len == 1 && scrolled_target[0].transform[5] == -100
	fixed := document.get_element_by_id('fixed') or { panic('missing fixed') }
	fixed_hit := mutable_document.element_from_point(5, 10) or { panic('missing fixed hit') }
	assert fixed_hit.as_node().unique_id() == fixed.as_node().unique_id()
	target := document.get_element_by_id('target') or { panic('missing target') }
	target_hit := mutable_document.element_from_point(50, 5) or { panic('missing target hit') }
	assert target_hit.as_node().unique_id() == target.as_node().unique_id()
}

fn test_scroll_frame_parentage_stops_at_fixed_ancestors_except_for_sticky_boxes() {
	document := html.parse_document('<!doctype html><style>html, body { margin: 0 } #fixed { position: fixed; width: 20px; height: 20px; overflow: auto } #content { height: 40px }</style><body><div id="fixed"><div id="content"></div></div></body>')
	root := layout_document_typed_in_viewport(document, 320, 200)
	result := document_layout_result(document) or { panic('missing layout result') }
	fixed_element := document.get_element_by_id('fixed') or { panic('missing fixed scroller') }
	fixed_box := root.find_box(i64(fixed_element.as_node().unique_id())) or {
		panic('missing fixed scroller box')
	}
	assert fixed_box.own_scroll_frame_index > 0
	assert result.scroll_state.frame_at(fixed_box.own_scroll_frame_index).parent_index() == 0

	// Construct the containing-block relationship explicitly for the boundary
	// cases that do not arise from the compact HTML layout fixture above.
	synthetic_document := dom.Document.create(dom.url_about_blank())
	viewport_style := computed_paint_test_style('display: block')
	fixed_style := computed_paint_test_style('display: block; position: fixed')
	normal_style := computed_paint_test_style('display: block')
	sticky_style := computed_paint_test_style('display: block; position: sticky')
	viewport := Viewport.new(synthetic_document, viewport_style)
	fixed := BlockContainer.new(synthetic_document, none, fixed_style)
	normal := BlockContainer.new(synthetic_document, none, normal_style)
	sticky := BlockContainer.new(synthetic_document, none, sticky_style)
	mut fixed_node := unsafe { &Node(fixed) }
	mut normal_node := unsafe { &Node(normal) }
	mut sticky_node := unsafe { &Node(sticky) }
	fixed_node.containing_block_ = unsafe { &Box(viewport) }
	normal_node.containing_block_ = unsafe { &Box(fixed) }
	sticky_node.containing_block_ = unsafe { &Box(fixed) }

	mut viewport_box := &BlockBox{
		layout_handle: voidptr(unsafe { &Node(viewport) })
	}
	viewport_box.own_scroll_frame_index = 7
	fixed_transport := &BlockBox{
		layout_handle: voidptr(fixed_node)
	}
	normal_transport := &BlockBox{
		layout_handle: voidptr(normal_node)
	}
	sticky_transport := &BlockBox{
		layout_handle: voidptr(sticky_node)
	}
	boxes_by_layout := {
		u64(voidptr(unsafe { &Node(viewport) })): viewport_box
		u64(voidptr(fixed_node)):                 fixed_transport
	}
	assert paintable_box_nearest_scroll_frame_index(fixed_transport, boxes_by_layout) == 0
	assert paintable_box_nearest_scroll_frame_index(normal_transport, boxes_by_layout) == 0
	assert paintable_box_nearest_scroll_frame_index(sticky_transport, boxes_by_layout) == 7
}

fn test_percentage_sticky_insets_skip_overflow_hidden_ancestors() {
	document := html.parse_document('<!doctype html><style>
		html, body { margin: 0 }
		#outer { width: 200px; height: 100px; overflow: auto }
		#hidden { width: 100px; height: 40px; overflow: hidden }
		#sticky { position: sticky; top: 50%; height: 10px }
		#hidden-spacer { height: 100px }
		#outer-spacer { height: 200px }
	</style><body><div id="outer"><div id="hidden"><div id="sticky"></div><div id="hidden-spacer"></div></div><div id="outer-spacer"></div></div></body>')
	root := layout_document_typed_in_viewport(document, 320, 240)
	result := document_layout_result(document) or { panic('missing layout result') }
	sticky_element := document.get_element_by_id('sticky') or { panic('missing sticky') }
	sticky_box := root.find_box(i64(sticky_element.as_node().unique_id())) or {
		panic('missing sticky box')
	}
	assert sticky_box.sticky_scroll_frame_index > 0
	sticky_frame := result.scroll_state.frame_at(sticky_box.sticky_scroll_frame_index)
	assert sticky_frame.has_sticky_constraints()
	constraints := sticky_frame.sticky_constraints()
	// PaintableBox::nearest_scrollable_ancestor() skips the 40px-tall
	// overflow:hidden box. The 50% inset therefore resolves against the
	// 100px-tall outer scroll container.
	assert constraints.insets.top or { -1 } == 50
}

fn test_checkbox_paint_reads_live_checkedness_and_invalidates_retained_commands() {
	document := html.parse_document('<!doctype html><style>html, body { margin: 0 } #control { accent-color: rgb(255, 0, 0) }</style><body><input id="control" type="checkbox"></body>')
	root := layout_document_typed_in_viewport(document, 320, 200)
	mut mutable_document := unsafe { &dom.Document(document) }
	initial_display_list := record_retained_display_list(mut mutable_document) or {
		panic('missing initial display list')
	}
	assert !display_list_commands(initial_display_list).any(it.kind == 'draw_svg_path')

	control := document.get_element_by_id('control') or { panic('missing checkbox') }
	mut model := html.HTMLInputElementModel.create(unsafe { &dom.HTMLInputElement(control) })
	model.set_checked(true)
	assert control.matches_checked_pseudo_class()
	assert mutable_document.cached_display_list() == none
	checked_display_list := record_retained_display_list(mut mutable_document) or {
		panic('missing checked display list')
	}
	checked_commands := display_list_commands(checked_display_list)
	assert checked_commands.any(it.kind == 'fill_rounded_rect' && it.color == 'rgb(255 0 0)')
	assert checked_commands.any(it.kind == 'draw_svg_path' && it.color == 'rgb(255 255 255)')

	model.set_indeterminate(true)
	indeterminate_commands := root.paint_commands()
	assert !indeterminate_commands.any(it.kind == 'draw_svg_path')
	assert indeterminate_commands.any(it.kind == 'fill_rounded_rect'
		&& it.color == 'rgb(76 76 76)')
}

fn test_checkbox_paint_reacts_to_direct_and_fieldset_disabled_changes() {
	document := html.parse_document('<!doctype html><style>html, body { margin: 0 } #control { accent-color: rgb(255, 0, 0) }</style><body><fieldset id="group"><input id="control" type="checkbox" checked></fieldset></body>')
	_ := layout_document_typed_in_viewport(document, 320, 200)
	mut mutable_document := unsafe { &dom.Document(document) }
	initial_display_list := record_retained_display_list(mut mutable_document) or {
		panic('missing initial display list')
	}
	assert display_list_commands(initial_display_list).any(it.kind == 'fill_rounded_rect'
		&& it.color == 'rgb(255 0 0)')

	control := document.get_element_by_id('control') or { panic('missing checkbox') }
	control_paintable := control.paintable_box() or { panic('missing checkbox paintable') }
	result := document_layout_result(document) or { panic('missing layout result') }
	mut control_entry_index := -1
	for index, entry in result.paint_order {
		if entry.box.layout_handle == control_paintable.layout_handle {
			control_entry_index = index
			break
		}
	}
	assert control_entry_index >= 0

	mut group := document.get_element_by_id('group') or { panic('missing fieldset') }
	group.set_attribute_value('disabled', '')
	assert mutable_document.cached_display_list() == none
	assert !result.paint_phase_entry_valid[control_entry_index]
	disabled_by_fieldset := record_retained_display_list(mut mutable_document) or {
		panic('missing fieldset-disabled display list')
	}
	assert !display_list_commands(disabled_by_fieldset).any(it.kind == 'fill_rounded_rect'
		&& it.color == 'rgb(255 0 0)')

	group.remove_attribute('disabled')
	assert !result.paint_phase_entry_valid[control_entry_index]
	_ = record_retained_display_list(mut mutable_document) or { panic('missing re-enabled display list') }

	mut mutable_control := unsafe { &dom.Element(control) }
	mutable_control.set_attribute_value('disabled', '')
	assert mutable_document.cached_display_list() == none
	assert !result.paint_phase_entry_valid[control_entry_index]
	directly_disabled := record_retained_display_list(mut mutable_document) or {
		panic('missing directly-disabled display list')
	}
	assert !display_list_commands(directly_disabled).any(it.kind == 'fill_rounded_rect'
		&& it.color == 'rgb(255 0 0)')
}

fn test_fieldset_paint_shifts_background_and_splits_top_border_around_legend() {
	document := html.parse_document('<!doctype html><style>
		html, body { margin: 0 }
		fieldset { margin: 10px; width: 180px; height: 60px; padding: 8px;
			border: 6px solid rgb(220, 0, 0); background: rgb(180, 220, 255) }
		legend { padding: 2px 12px; border: 2px solid rgb(0, 80, 0) }
	</style><fieldset><legend>Legend</legend><div>content</div></fieldset>')
	_ := layout_document_typed_in_viewport(document, 240, 120)
	mut mutable_document := unsafe { &dom.Document(document) }
	display_list := record_retained_display_list(mut mutable_document) or { panic('missing fieldset display list') }
	commands := display_list_commands(display_list)
	background := commands.filter(it.color == 'rgb(180 220 255)')
	assert background.len == 1
	background_clip := background[0].recording_clip or { panic('fieldset background is not clipped') }
	assert background_clip == LayoutRect{10, 20, 208, 78}
	assert background[0].clip_list != unsafe { nil }
	assert background[0].clip_list.items.last().rect == background_clip

	red_borders := commands.filter(it.color == 'rgb(220 0 0)')
	clipped_top_borders := red_borders.filter(it.recording_clip != none)
	assert clipped_top_borders.len == 0
	top_border_runs := red_borders.filter(it.kind == 'fill_rect' && it.y == 20 && it.height == 6)
	assert top_border_runs.len == 2
	assert top_border_runs[0].x + top_border_runs[0].width <= top_border_runs[1].x
	assert red_borders.any(it.recording_clip == none)
}

fn test_list_markers_paint_as_generated_text() {
	document := html.parse_document('<!doctype html><style>
		html, body { margin: 0 }
		ul { margin: 0 0 0 32px; padding: 0; color: rgb(20, 60, 180) }
		li { width: 20px; height: 16px; font-size: 17px }
		#a { list-style-type: square } #b { list-style-type: circle }
		#c { list-style-type: disc } #d { list-style-type: disclosure-closed }
		#e { list-style-type: disclosure-open }
	</style><ul><li id="a"></li><li id="b"></li><li id="c"></li>
		<li id="d"></li><li id="e"></li></ul>')
	_ := layout_document_typed_in_viewport(document, 140, 120)
	mut mutable_document := unsafe { &dom.Document(document) }
	display_list := record_retained_display_list(mut mutable_document) or { panic('missing marker display list') }
	commands := display_list_commands(display_list)
	markers := commands.filter(it.color == 'rgb(20 60 180)')
	text_markers := markers.filter(it.kind == 'draw_text')
	assert text_markers.len == 5
	assert text_markers.all(it.text.len > 0)
	assert !markers.any(it.kind in ['fill_rect', 'stroke_ellipse', 'fill_ellipse', 'draw_svg_path'])
}

fn test_document_viewport_paintable_recomputes_text_selection_states() {
	document := html.parse_document('<!doctype html><body><span id="start">hello</span><span id="end">world</span></body>')
	_ = layout_document_typed_in_viewport(document, 320, 200)
	start_element := document.get_element_by_id('start') or { panic('missing start element') }
	end_element := document.get_element_by_id('end') or { panic('missing end element') }
	start_text := start_element.as_node().first_child() or { panic('missing start text') }
	end_text := end_element.as_node().first_child() or { panic('missing end text') }
	viewport := document.paintable() or { panic('missing viewport paintable') }
	assert viewport.is_viewport_paintable()
	assert viewport.selection() == document.get_selection()

	range := dom.Range.create_from_boundary_points(start_text, 1, end_text, 2)
	viewport.recompute_selection_states(range)
	start_paintable := start_text.paintable() or { panic('missing start text paintable') }
	end_paintable := end_text.paintable() or { panic('missing end text paintable') }
	assert start_paintable.selection_state == .start
	assert end_paintable.selection_state == .end

	same_text_range := dom.Range.create_from_boundary_points(start_text, 1, start_text, 4)
	viewport.recompute_selection_states(same_text_range)
	assert start_paintable.selection_state == .start_and_end
	assert end_paintable.selection_state == .none

	collapsed_range := dom.Range.create_from_boundary_points(start_text, 2, start_text, 2)
	viewport.recompute_selection_states(collapsed_range)
	assert start_paintable.selection_state == .none
	assert end_paintable.selection_state == .none
}

fn test_range_client_rects_apply_visual_transforms_and_live_scroll_offsets() {
	document := html.parse_document('<!doctype html><style>
		html, body { margin: 0 }
		#scroller { width: 200px; height: 50px; overflow: scroll }
		#content { height: 200px }
		#transformed { display: inline-block; transform: translate(20px, 10px) scale(2);
			transform-origin: 0 0 }
	</style><body><div id="scroller"><div id="content"><span id="transformed">hello</span></div></div></body>')
	_ = layout_document_typed_in_viewport(document, 320, 200)
	transformed := document.get_element_by_id('transformed') or { panic('missing transformed element') }
	text := transformed.as_node().first_child() or { panic('missing transformed text') }
	range := dom.Range.create_from_boundary_points(text, 0, text, text.length())

	initial := range.get_client_rects()
	assert initial.length() == 1
	initial_rect := initial.item(0) or { panic('missing initial range rect') }
	initial_element_rect := transformed.get_bounding_client_rect()
	assert math.abs(initial_rect.x - initial_element_rect.x) < 0.01
	assert math.abs(initial_rect.width - initial_element_rect.width) < 0.01
	// Range geometry includes the selected face's ascent/descent overflow. That
	// can extend beyond the inline-block's line-height box after transformation.
	initial_top_overflow := initial_element_rect.y - initial_rect.y
	initial_bottom_overflow := initial_rect.y + initial_rect.height - (initial_element_rect.y +
		initial_element_rect.height)
	assert initial_top_overflow > 0
	assert initial_bottom_overflow > 0

	scroller := document.get_element_by_id('scroller') or { panic('missing scroller') }
	mut scroller_paintable := scroller.paintable_box() or { panic('missing scroller paintable') }
	assert scroller_paintable.set_scroll_offset(dom.CSSPixelPoint_{ y_: 50 })
	scrolled := range.get_client_rects()
	assert scrolled.length() == 1
	scrolled_rect := scrolled.item(0) or { panic('missing scrolled range rect') }
	scrolled_element_rect := transformed.get_bounding_client_rect()
	assert math.abs(scrolled_rect.x - initial_rect.x) < 0.01
	assert math.abs(scrolled_rect.y - (initial_rect.y - 50)) < 0.01
	assert math.abs(scrolled_rect.width - initial_rect.width) < 0.01
	assert math.abs(scrolled_rect.height - initial_rect.height) < 0.01
	assert math.abs(scrolled_rect.x - scrolled_element_rect.x) < 0.01
	assert math.abs(scrolled_rect.width - scrolled_element_rect.width) < 0.01
	assert math.abs((scrolled_element_rect.y - scrolled_rect.y) - initial_top_overflow) < 0.01
	scrolled_bottom_overflow := scrolled_rect.y + scrolled_rect.height - (scrolled_element_rect.y +
		scrolled_element_rect.height)
	assert math.abs(scrolled_bottom_overflow - initial_bottom_overflow) < 0.01
}

fn test_paintable_with_lines_translates_selection_render_spans_and_cache_invalidation() {
	document := html.parse_document('<!doctype html><style>
		html, body, p { margin: 0 }
		p { color: rgb(200 0 0); -webkit-text-fill-color: rgb(5 6 7);
			text-shadow: rgb(1 2 3) 1px 0 2px }
		p::selection { background-color: rgb(20 30 40); color: rgb(50 60 70);
			text-shadow: rgb(80 90 100) 2px 3px 4px;
			text-decoration-line: underline; text-decoration-style: wavy;
			text-decoration-color: rgb(110 120 130) }
	</style><body><p id="target">hello</p></body>')
	root := layout_document_typed_in_viewport(document, 240, 100)
	mut mutable_document := unsafe { &dom.Document(document) }
	initial := display_list_commands(record_retained_display_list(mut mutable_document) or {
		panic('missing initial display list')
	})
	initial_text := initial.filter(it.kind == 'draw_text' && it.text == 'hello')
	assert initial_text.len == 1
	initial_run := initial_text[0].glyph_run or { panic('missing retained glyph run') }
	assert initial_run.glyphs().len == 5
	assert initial_text[0].glyph_translation_x == initial_text[0].x
	assert initial_text[0].glyph_translation_y > initial_text[0].y
	// compute_render_spans() uses -webkit-text-fill-color, not color.
	assert initial_text[0].color == 'rgb(5 6 7)'
	assert initial.any(it.kind == 'draw_text_shadow' && it.text == 'hello'
		&& it.color == 'rgb(1 2 3)' && it.blur == 2)

	target := document.get_element_by_id('target') or { panic('missing target') }
	text_node := target.as_node().first_child() or { panic('missing text node') }
	range := dom.Range.create_from_boundary_points(text_node, 1, text_node, 4)
	mut selection := document.get_selection() or { panic('missing document selection') }
	selection.add_range(range)
	paintable := text_node.paintable() or { panic('missing text paintable') }
	assert paintable.selection_state == .start_and_end
	assert paintable.needs_repaint

	commands := display_list_commands(record_retained_display_list(mut mutable_document) or {
		panic('missing selected display list')
	})
	mut background_index := -1
	mut selection_shadow_index := -1
	mut selected_text_index := -1
	for index, command in commands {
		if command.kind == 'fill_rect' && command.color == 'rgb(20 30 40)' {
			background_index = index
		} else if command.kind == 'draw_text_shadow' && command.text == 'ell'
			&& command.color == 'rgb(80 90 100)' && command.blur == 4 {
			selection_shadow_index = index
		} else if command.kind == 'draw_text' && command.text == 'hello'
			&& command.color == 'rgb(50 60 70)' && command.recording_clip != none {
			selected_text_index = index
		}
	}
	assert background_index >= 0
	assert selection_shadow_index > background_index
	assert selected_text_index > selection_shadow_index
	selection_shadow_run := commands[selection_shadow_index].glyph_run or {
		panic('missing selected shadow glyph run')
	}
	assert selection_shadow_run.glyphs().len == 3
	assert selection_shadow_run.glyphs()[0].position.x == initial_run.glyphs()[1].position.x
	selected_run := commands[selected_text_index].glyph_run or {
		panic('missing selected foreground glyph run')
	}
	assert voidptr(selected_run) == voidptr(initial_run)
	// An explicitly specified ::selection text-shadow replaces the ordinary
	// shadow for the selected span; it is not appended to it.
	assert !commands.any(it.kind == 'draw_text_shadow' && it.text == 'ell'
		&& it.color == 'rgb(1 2 3)')
	selected_text := commands[selected_text_index]
	selection_rect := selected_text.recording_clip or { panic('missing selection clip') }
	selection_background := commands[background_index]
	assert selection_background.x == selection_rect.x
	assert selection_background.y == selection_rect.y
	assert selection_background.width == selection_rect.width
	assert selection_background.height == selection_rect.height
	assert commands.any(it.stroke_color == 'rgb(110 120 130)'
		&& it.kind == 'draw_svg_path')

	target_box := root.find_box(i64(target.as_node().unique_id())) or {
		panic('missing target paint box')
	}
	assert selection_rect.x > target_box.x
	assert selection_rect.x + selection_rect.width < target_box.x + target_box.width
}

fn test_paintable_with_lines_translates_fragment_caret_and_rebuilds_its_phase_cache() {
	document := html.parse_document('<!doctype html><style>
		html, body, p { margin: 0 }
		p { caret-color: rgb(13 14 15) }
		#other { caret-color: rgb(21 22 23) }
	</style><body><p id="target" contenteditable>hello</p><p id="other" contenteditable>world</p></body>')
	mut mutable_document := unsafe { &dom.Document(document) }
	host := &dom.Navigable{
		active_document_: document
	}
	mut navigable := html.NavigableModel.create(host, none) or { panic(err) }
	navigable.set_focused(true)
	mutable_document.set_cached_navigable(host)
	_ = layout_document_typed_in_viewport(document, 240, 100)

	target := document.get_element_by_id('target') or { panic('missing target') }
	text_node := target.as_node().first_child() or { panic('missing text node') }
	mutable_document.set_focused_area(target.as_node())
	mut selection := document.get_selection() or { panic('missing document selection') }
	selection.collapse(text_node, 2) or { panic(err) }
	first_commands := display_list_commands(record_retained_display_list(mut mutable_document) or {
		panic('missing first caret display list')
	})
	first_carets := first_commands.filter(it.kind == 'fill_rect'
		&& it.color == 'rgb(13 14 15)')
	assert first_carets.len == 1
	assert first_carets[0].width == 1
	mut first_text_index := -1
	mut first_caret_index := -1
	for index, command in first_commands {
		if command.kind == 'draw_text' && command.text == 'hello' {
			first_text_index = index
		} else if command.kind == 'fill_rect' && command.color == 'rgb(13 14 15)' {
			first_caret_index = index
		}
	}
	assert first_caret_index > first_text_index

	selection.collapse(text_node, 4) or { panic(err) }
	assert mutable_document.cached_display_list() == none
	second_commands := display_list_commands(record_retained_display_list(mut mutable_document) or {
		panic('missing moved caret display list')
	})
	second_carets := second_commands.filter(it.kind == 'fill_rect'
		&& it.color == 'rgb(13 14 15)')
	assert second_carets.len == 1
	assert second_carets[0].x > first_carets[0].x

	// Moving between retained foreground buckets must evict the old caret as
	// well as recording the new one.
	other := document.get_element_by_id('other') or { panic('missing other target') }
	other_text_node := other.as_node().first_child() or { panic('missing other text node') }
	mutable_document.set_focused_area(other.as_node())
	selection.collapse(other_text_node, 3) or { panic(err) }
	third_commands := display_list_commands(record_retained_display_list(mut mutable_document) or {
		panic('missing cross-box caret display list')
	})
	assert !third_commands.any(it.kind == 'fill_rect' && it.color == 'rgb(13 14 15)')
	third_carets := third_commands.filter(it.kind == 'fill_rect'
		&& it.color == 'rgb(21 22 23)')
	assert third_carets.len == 1
	assert third_carets[0].y > second_carets[0].y

	// Losing the editable focus invalidates the last bucket and removes its
	// already-recorded caret command.
	mutable_document.set_focused_area(none)
	last_commands := display_list_commands(record_retained_display_list(mut mutable_document) or {
		panic('missing unfocused display list')
	})
	assert !last_commands.any(it.kind == 'fill_rect' && (it.color == 'rgb(13 14 15)'
		|| it.color == 'rgb(21 22 23)'))
}

fn test_paintable_with_lines_centers_empty_editable_caret_at_font_height() {
	document := html.parse_document('<!doctype html><style>
		html, body, p { margin: 0 }
		p { padding: 3px 5px; min-height: 40px; font: 20px/40px monospace; caret-color: rgb(31 32 33) }
	</style><body><p id="target" contenteditable></p></body>')
	mut mutable_document := unsafe { &dom.Document(document) }
	host := &dom.Navigable{
		active_document_: document
	}
	mut navigable := html.NavigableModel.create(host, none) or { panic(err) }
	navigable.set_focused(true)
	mutable_document.set_cached_navigable(host)
	root := layout_document_typed_in_viewport(document, 240, 100)
	target := document.get_element_by_id('target') or { panic('missing empty target') }
	mutable_document.set_focused_area(target.as_node())
	mut selection := document.get_selection() or { panic('missing document selection') }
	selection.collapse(target.as_node(), 0) or { panic(err) }
	commands := display_list_commands(record_retained_display_list(mut mutable_document) or {
		panic('missing empty caret display list')
	})
	carets := commands.filter(it.kind == 'fill_rect' && it.color == 'rgb(31 32 33)')
	assert carets.len == 1
	target_box := root.find_box(i64(target.as_node().unique_id())) or {
		panic('missing empty target paint box')
	}
	assert carets[0].x == target_box.x - target_box.padding.left
	assert carets[0].width == 1
	target_layout := unsafe { &Node(target_box.layout_handle) }
	expected := rounded_text_span_rect(caret_rect_for_empty_line(target_layout, target_box.x - target_box.padding.left, target_box.y - target_box.padding.top))
	assert carets[0].y == expected.y
	assert carets[0].height == expected.height
	assert carets[0].height < 40
}

fn test_paintable_with_lines_sizes_empty_paragraph_caret_from_its_font() {
	document := html.parse_document('<!doctype html><style>html,body,p{margin:0}div{font:20px/40px monospace}p{caret-color:rgb(41 42 43)}</style><div contenteditable><p id="target"><br></p></div>')
	mut mutable_document := unsafe { &dom.Document(document) }
	host := &dom.Navigable{ active_document_: document }
	mut navigable := html.NavigableModel.create(host, none) or { panic(err) }
	navigable.set_focused(true)
	mutable_document.set_cached_navigable(host)
	root := layout_document_typed_in_viewport(document, 240, 100)
	target := document.get_element_by_id('target') or { panic('missing target') }
	mutable_document.set_focused_area(target.as_node())
	mut selection := document.get_selection() or { panic('missing selection') }
	selection.collapse(target.as_node(), 0) or { panic(err) }
	commands := display_list_commands(record_retained_display_list(mut mutable_document) or { panic('missing display list') })
	carets := commands.filter(it.kind == 'fill_rect' && it.color == 'rgb(41 42 43)')
	assert carets.len == 1
	target_box := root.find_box(i64(target.as_node().unique_id())) or { panic('missing target box') }
	target_layout := unsafe { &Node(target_box.layout_handle) }
	expected := rounded_text_span_rect(caret_rect_for_empty_line(target_layout, target_box.x - target_box.padding.left, target_box.y - target_box.padding.top))
	assert carets[0].y == expected.y
	assert carets[0].height == expected.height
}

fn test_paintable_with_lines_sizes_empty_inline_caret_from_its_font() {
	document := html.parse_document('<!doctype html><style>html,body,div{margin:0}div{font:20px/40px monospace}span{caret-color:rgb(51 52 53)}</style><div contenteditable><span id="target"></span></div>')
	mut mutable_document := unsafe { &dom.Document(document) }
	host := &dom.Navigable{ active_document_: document }
	mut navigable := html.NavigableModel.create(host, none) or { panic(err) }
	navigable.set_focused(true)
	mutable_document.set_cached_navigable(host)
	_ = layout_document_typed_in_viewport(document, 240, 100)
	target := document.get_element_by_id('target') or { panic('missing target') }
	mutable_document.set_focused_area(target.as_node())
	mut selection := document.get_selection() or { panic('missing selection') }
	selection.collapse(target.as_node(), 0) or { panic(err) }
	commands := display_list_commands(record_retained_display_list(mut mutable_document) or { panic('missing display list') })
	carets := commands.filter(it.kind == 'fill_rect' && it.color == 'rgb(51 52 53)')
	assert carets.len == 1
	paintable := target.as_node().unsafe_paintable() or { panic('missing inline paintable') }
	target_layout := unsafe { &Node(paintable.layout_handle) }
	position := paintable.box_type_agnostic_position()
	expected := rounded_text_span_rect(caret_rect_for_empty_line(target_layout, position.x(), position.y()))
	assert carets[0].x == expected.x
	assert carets[0].y == expected.y
	assert carets[0].height == expected.height
}

fn collapsed_caret_command(document &dom.Document, node &dom.Node, offset int,
	color string) PaintCommand {
	mut selection := document.get_selection() or { panic('missing selection') }
	selection.collapse(node, offset) or { panic(err) }
	mut mutable_document := unsafe { &dom.Document(document) }
	commands := display_list_commands(record_retained_display_list(mut mutable_document) or {
		panic('missing caret display list')
	})
	carets := commands.filter(it.kind == 'fill_rect' && it.color == color)
	assert carets.len == 1
	return carets[0]
}

fn assert_text_child_boundary_caret_geometry(style string, first_text string,
	second_text string) {
	document := html.parse_document('<!doctype html><style>html,body{margin:0}#editor{font:20px/40px monospace;caret-color:rgb(61 62 63);${style}}</style><div id="editor" contenteditable></div>')
	editor := document.get_element_by_id('editor') or { panic('missing editor') }
	first := document.create_text_node(first_text)
	second := document.create_text_node(second_text)
	mut editor_node := unsafe { &dom.Node(editor) }
	editor_node.append_child(first.as_node()) or { panic(err) }
	editor_node.append_child(second.as_node()) or { panic(err) }
	mut mutable_document := unsafe { &dom.Document(document) }
	host := &dom.Navigable{ active_document_: document }
	mut navigable := html.NavigableModel.create(host, none) or { panic(err) }
	navigable.set_focused(true)
	mutable_document.set_cached_navigable(host)
	mutable_document.set_focused_area(editor.as_node())
	_ = layout_document_typed_in_viewport(document, 240, 120)

	before_parent := collapsed_caret_command(document, editor.as_node(), 0, 'rgb(61 62 63)')
	before_text := collapsed_caret_command(document, first.as_node(), 0, 'rgb(61 62 63)')
	assert LayoutRect{before_parent.x, before_parent.y, before_parent.width, before_parent.height} == LayoutRect{before_text.x, before_text.y, before_text.width, before_text.height}

	between_parent := collapsed_caret_command(document, editor.as_node(), 1, 'rgb(61 62 63)')
	between_text := collapsed_caret_command(document, first.as_node(), first.length(), 'rgb(61 62 63)')
	assert LayoutRect{between_parent.x, between_parent.y, between_parent.width, between_parent.height} == LayoutRect{between_text.x, between_text.y, between_text.width, between_text.height}

	after_parent := collapsed_caret_command(document, editor.as_node(), 2, 'rgb(61 62 63)')
	after_text := collapsed_caret_command(document, second.as_node(), second.length(), 'rgb(61 62 63)')
	assert LayoutRect{after_parent.x, after_parent.y, after_parent.width, after_parent.height} == LayoutRect{after_text.x, after_text.y, after_text.width, after_text.height}
}

fn test_paintable_with_lines_resolves_text_child_boundary_carets_from_fragments() {
	assert_text_child_boundary_caret_geometry('', 'a', 'b')
	assert_text_child_boundary_caret_geometry('direction:rtl', 'א', 'ב')
	assert_text_child_boundary_caret_geometry('writing-mode:vertical-rl', 'a', 'b')
}

fn test_typed_collapsed_table_borders_retain_winners_and_paint_shared_edges_once() {
	document := html.parse_document('<!doctype html><style>html, body { margin: 0 } table { border-collapse: collapse } td { width: 30px; height: 20px; padding: 0; border: 2px solid rgb(200 0 0); background: rgb(250 250 0) } #right { border-left: 6px dashed rgb(0 0 200) }</style><body><table id="table"><tr><td id="left"></td><td id="right"></td></tr></table></body>')
	root := layout_document_typed_in_viewport(document, 320, 200)
	table_element := document.get_element_by_id('table') or { panic('missing table') }
	left_element := document.get_element_by_id('left') or { panic('missing left cell') }
	right_element := document.get_element_by_id('right') or { panic('missing right cell') }
	table_box := root.find_box(i64(table_element.as_node().unique_id())) or {
		panic('missing table box')
	}
	left_box := root.find_box(i64(left_element.as_node().unique_id())) or {
		panic('missing left cell box')
	}
	right_box := root.find_box(i64(right_element.as_node().unique_id())) or {
		panic('missing right cell box')
	}

	assert table_box.table_inside
	assert table_box.uses_collapsed_borders
	assert left_box.table_cell && right_box.table_cell
	left_coordinates := left_box.table_cell_coordinates or { panic('missing left coordinates') }
	right_coordinates := right_box.table_cell_coordinates or { panic('missing right coordinates') }
	assert left_coordinates == painting.TableCellCoordinates{0, 0, 1, 1}
	assert right_coordinates == painting.TableCellCoordinates{0, 1, 1, 1}
	left_borders := left_box.table_cell_borders or { panic('missing winning borders') }
	right_borders := right_box.table_cell_borders or { panic('missing winning borders') }
	assert left_borders.right.border_data.width == 6
	assert right_borders.left.border_data.width == 6
	assert left_borders.right.border_data.line_style == .dashed
	assert left_borders.right.border_data.color == painting.Color{0, 0, 200, 255}
	// An even collapsed border splits equally on both sides of its grid line.
	assert left_box.border.right == 3
	assert right_box.border.left == 3

	commands := root.paint_commands()
	table_border_commands := commands.filter(it.paint_phase == .table_collapsed_border)
	// The two-cell row has six outside edges and one shared edge, rather than
	// eight independently painted cell sides.
	assert table_border_commands.len == 7
	blue_shared_edge := table_border_commands.filter(it.kind == 'draw_line' && it.color == 'rgb(0 0 200)')
	assert blue_shared_edge.len == 1
	assert blue_shared_edge[0].stroke_width == 6
	assert blue_shared_edge[0].line_style == 'dashed'
	assert blue_shared_edge[0].points[0] == blue_shared_edge[0].points[2]

	mut last_cell_background := -1
	mut first_table_border := commands.len
	for index, command in commands {
		if command.color == 'rgb(250 250 0)' {
			last_cell_background = index
		}
		if command.paint_phase == .table_collapsed_border && first_table_border == commands.len {
			first_table_border = index
		}
	}
	assert last_cell_background >= 0
	assert first_table_border > last_cell_background
}

fn test_typed_ordinary_borders_retain_cpp_line_style_dispatch() {
	document := html.parse_document('<!doctype html><style>html, body { margin: 0 } #double { width: 40px; height: 20px; border: 6px double rgb(200 0 0) } #dashed { width: 40px; height: 20px; border: 4px dashed rgb(0 100 0) } #inset { width: 40px; height: 20px; border: 6px inset rgb(102 102 102) } #rounded { width: 40px; height: 20px; border: 5px solid rgb(40 50 70); border-radius: 12px 7px 4px 9px }</style><body><div id="double"></div><div id="dashed"></div><div id="inset"></div><div id="rounded"></div></body>')
	root := layout_document_typed_in_viewport(document, 320, 240)
	double_element := document.get_element_by_id('double') or { panic('missing double border') }
	dashed_element := document.get_element_by_id('dashed') or { panic('missing dashed border') }
	inset_element := document.get_element_by_id('inset') or { panic('missing inset border') }
	double_box := root.find_box(i64(double_element.as_node().unique_id())) or {
		panic('missing double box')
	}
	dashed_box := root.find_box(i64(dashed_element.as_node().unique_id())) or {
		panic('missing dashed box')
	}
	inset_box := root.find_box(i64(inset_element.as_node().unique_id())) or {
		panic('missing inset box')
	}
	assert double_box.border_styles.top == .double
	assert dashed_box.border_styles.right == .dashed
	assert inset_box.border_styles.bottom == .inset

	border_commands := root.paint_commands().filter(it.paint_phase == .border)
	double_commands := border_commands.filter(it.color == 'rgb(200 0 0)')
	assert double_commands.len == 8
	assert double_commands.all(it.kind == 'draw_svg_path' && it.svg().path.len > 0
		&& it.svg().path_data.len > 0 && it.svg().fill_even_odd)
	dashed_commands := border_commands.filter(it.color == 'rgb(0 100 0)')
	assert dashed_commands.len == 4
	assert dashed_commands.all(it.kind == 'draw_line' && it.line_style == 'dashed'
		&& it.stroke_width == 4)
	dark_inset := border_commands.filter(it.color == 'rgb(17 17 17)')
	light_inset := border_commands.filter(it.color == 'rgb(102 102 102)')
	assert dark_inset.len == 1
	assert light_inset.len == 1
	assert dark_inset[0].kind == 'draw_svg_path'
	assert light_inset[0].kind == 'draw_svg_path'
	rounded_commands := border_commands.filter(it.color == 'rgb(40 50 70)')
	assert rounded_commands.len == 1
	assert rounded_commands[0].kind == 'draw_svg_path'
	assert rounded_commands[0].svg().path.contains('A ')
	assert rounded_commands[0].svg().path_data.len > 0
	assert rounded_commands[0].svg().path_polygons.len == 4
	assert rounded_commands[0].svg().fill_even_odd
}

fn test_typed_outlines_use_cpp_border_dispatch_and_auto_accent() {
	document := html.parse_document('<!doctype html><style>html, body { margin: 0 } #dashed { width: 80px; height: 30px; outline: 6px dashed rgb(10 90 40); outline-offset: 2px } #double { width: 80px; height: 30px; outline: 9px double rgb(120 20 30); border-radius: 12px 6px } #automatic { width: 40px; height: 20px; outline-style: auto; outline-width: 10px; outline-color: red }</style><body><div id="dashed"></div><div id="double"></div><div id="automatic"></div></body>')
	root := layout_document_typed_in_viewport(document, 320, 240)
	dashed_element := document.get_element_by_id('dashed') or { panic('missing dashed outline') }
	double_element := document.get_element_by_id('double') or { panic('missing double outline') }
	automatic_element := document.get_element_by_id('automatic') or {
		panic('missing automatic outline')
	}
	dashed_box := root.find_box(i64(dashed_element.as_node().unique_id())) or {
		panic('missing dashed outline box')
	}
	double_box := root.find_box(i64(double_element.as_node().unique_id())) or {
		panic('missing double outline box')
	}
	automatic_box := root.find_box(i64(automatic_element.as_node().unique_id())) or {
		panic('missing automatic outline box')
	}
	assert dashed_box.outline_style == .dashed
	assert double_box.outline_style == .double
	assert automatic_box.outline_style == .solid
	assert automatic_box.outline_width == 2

	outline_commands := root.paint_commands().filter(it.paint_phase == .outline)
	dashed_commands := outline_commands.filter(it.color == 'rgb(10 90 40)')
	assert dashed_commands.len == 4
	assert dashed_commands.all(it.kind == 'draw_line' && it.line_style == 'dashed'
		&& it.stroke_width == 6)
	double_commands := outline_commands.filter(it.color == 'rgb(120 20 30)')
	assert double_commands.len == 8
	assert double_commands.all(it.kind == 'draw_svg_path' && it.svg().path.contains('A ')
		&& it.svg().fill_even_odd)
	automatic_commands := outline_commands.filter(it.color == 'rgb(61 174 233)')
	assert automatic_commands.len == 1
	assert automatic_commands[0].kind == 'draw_svg_path'
}

fn test_borderless_collapsed_table_does_not_invent_medium_currentcolor_edges() {
	document := html.parse_document('<!doctype html><style>table { border-collapse: collapse } td { width: 20px; height: 10px }</style><body><table><tr><td></td><td></td></tr></table></body>')
	root := layout_document_typed_in_viewport(document, 200, 100)
	assert root.paint_commands().all(it.paint_phase != .table_collapsed_border)
}

fn test_separate_table_cell_borders_are_snapped_in_the_table_phase_and_empty_cells_hide() {
	document := html.parse_document('<!doctype html><style>html, body { margin: 0 } table { border-spacing: 0 } td { width: 20px; height: 10px; padding: 0; border: 2px solid rgb(10 20 30); background: rgb(40 50 60); empty-cells: hide }</style><body><table id="table"><tr><td id="empty"></td><td id="filled">x</td></tr></table></body>')
	root := layout_document_typed_in_viewport(document, 200, 100)
	table_element := document.get_element_by_id('table') or { panic('missing table') }
	empty_element := document.get_element_by_id('empty') or { panic('missing empty cell') }
	filled_element := document.get_element_by_id('filled') or { panic('missing filled cell') }
	table_box := root.find_box(i64(table_element.as_node().unique_id())) or {
		panic('missing table box')
	}
	empty_box := root.find_box(i64(empty_element.as_node().unique_id())) or {
		panic('missing empty cell box')
	}
	filled_box := root.find_box(i64(filled_element.as_node().unique_id())) or {
		panic('missing filled cell box')
	}
	assert table_box.table_inside && !table_box.uses_collapsed_borders
	assert empty_box.table_cell_coordinates != none
	assert filled_box.table_cell_coordinates != none
	assert empty_box.empty_cells_hide && !empty_box.has_layout_children
	assert filled_box.empty_cells_hide && filled_box.has_layout_children

	commands := root.paint_commands()
	table_border_commands := commands.filter(it.paint_phase == .table_collapsed_border)
	assert table_border_commands.len == 1
	assert table_border_commands[0].kind == 'draw_svg_path'
	assert table_border_commands[0].svg().fill_even_odd
	assert table_border_commands.all(it.color == 'rgb(10 20 30)')
	backgrounds := commands.filter(it.color == 'rgb(40 50 60)' && it.paint_phase == .background)
	assert backgrounds.len == 1
	assert backgrounds[0].x >= filled_box.border_box().x
	// Text in the filled cell remains in its block paintable. It must not
	// manufacture a second inline-fragment background from the td style.
	assert commands.filter(it.color == 'rgb(40 50 60)').len == 1
}

fn test_typed_text_box_decorations_only_come_from_inline_paintables() {
	document := html.parse_document('<!doctype html><style>html, body { margin: 0 } #block { width: 100px; background: rgb(11 22 33) } #inline { background: rgb(44 55 66) }</style><body><div id="block">block <span id="inline">inline</span></div></body>')
	root := layout_document_typed_in_viewport(document, 200, 100)
	commands := root.paint_commands()

	// PaintableWithLines for the block paints its own background once. Its
	// direct text fragments carry text styling only.
	assert commands.filter(it.color == 'rgb(11 22 33)').len == 1
	// LayoutState relocates the span fragment into an InlineNode paintable, so
	// its decorating box is still emitted before the text.
	inline_backgrounds := commands.filter(it.color == 'rgb(44 55 66)')
	assert inline_backgrounds.len == 1
	assert inline_backgrounds[0].paint_phase == .foreground
}

fn test_typed_wrapped_inline_marks_only_fragmented_horizontal_edges_away() {
	document := html.parse_document('<!doctype html><style>html,body,p{margin:0}p{width:100px}span{border:2px solid red}</style><body><p id="paragraph"><span id="inline">one two three four five six seven eight nine ten</span></p></body>')
	root := layout_document_typed_in_viewport(document, 200, 200)
	paragraph := document.get_element_by_id('paragraph') or { panic('missing paragraph') }
	inline := document.get_element_by_id('inline') or { panic('missing inline') }
	box := root.find_box(i64(paragraph.as_node().unique_id())) or { panic('missing paragraph box') }
	inline_id := i64(inline.as_node().unique_id())
	mut line_fragments := [][]TextFragment{}
	for line in box.lines {
		owned := line.fragments.filter(it.inline_node_id == inline_id)
		if owned.len > 0 {
			line_fragments << owned
		}
	}
	assert line_fragments.len > 1
	assert !line_fragments.first().first().fragment_left_edge_away
	assert line_fragments.first().last().fragment_right_edge_away
	for index := 1; index < line_fragments.len - 1; index++ {
		assert line_fragments[index].first().fragment_left_edge_away
		assert line_fragments[index].last().fragment_right_edge_away
	}
	assert line_fragments.last().first().fragment_left_edge_away
	assert !line_fragments.last().last().fragment_right_edge_away
}

fn test_typed_inline_background_image_uses_padding_box_origin() {
	document := html.parse_document('<!doctype html><style>
		html, body, p { margin:0 }
		#inline { padding:3px 5px 4px 17px; border:2px solid transparent;
			background-image:url("data:image/png;base64,AA=="); background-repeat:no-repeat }
	</style><body><p id="paragraph"><a id="inline">headline</a></p></body>')
	root := layout_document_typed_in_viewport(document, 240, 100)
	inline := document.get_element_by_id('inline') or { panic('missing inline') }
	paragraph := document.get_element_by_id('paragraph') or { panic('missing paragraph') }
	paragraph_box := root.find_box(i64(paragraph.as_node().unique_id())) or {
		panic('missing paragraph paint box')
	}
	inline_id := i64(inline.as_node().unique_id())
	fragment := paragraph_box.lines[0].fragments.filter(it.inline_node_id == inline_id)[0]
	commands := root.paint_commands().filter(it.kind == 'draw_background_image')
	assert commands.len == 1
	// The fragment starts at the content edge. background-origin defaults to
	// padding-box, while background-clip defaults to border-box.
	assert commands[0].x == fragment.x - 17
	assert commands[0].y == fragment.y - 3
	assert commands[0].image().image_clip_x == fragment.x - 19
	assert commands[0].image().image_clip_y == fragment.y - 5
}

fn test_typed_table_cell_radii_reach_the_active_table_border_phase() {
	document := html.parse_document('<!doctype html><style>html, body { margin: 0 } table { border-spacing: 0 } td { width: 30px; height: 20px; padding: 0; border: 3px solid rgb(70 80 90); border-radius: 8px 5px }</style><body><table><tr><td></td></tr></table></body>')
	root := layout_document_typed_in_viewport(document, 200, 100)
	commands := root.paint_commands().filter(it.paint_phase == .table_collapsed_border)
	assert commands.len == 1
	assert commands.all(it.kind == 'draw_svg_path')
	assert commands.all(it.color == 'rgb(70 80 90)')
	assert commands.all(it.svg().path.contains('A ') && it.svg().path_data.len > 0 && it.svg().fill_even_odd)
	assert commands.all(it.svg().path_polygons.len == 4)
}
