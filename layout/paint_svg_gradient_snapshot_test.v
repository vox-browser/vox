module layout

import html
import painting

$if gcboehm ? {
	fn C.GC_gcollect()
}

fn svg_gradient_snapshot_test_style(color painting.Color) painting.SVGGradientPaintStyle {
	return painting.SVGGradientPaintStyle{
		color_stops:        [painting.ColorStop{ color: color, position: 0.25 }]
		repeat_length:      0.5
		gradient_transform: painting.Affine{ e: 3, f: 4 }
		spread_method:      .reflect
		color_space:        .linear_srgb
	}
}

fn ephemeral_svg_gradient_commands() []PaintCommand {
	return BlockBox{
		width:    100
		height:   50
		svg_data: &BlockBoxSVGData{
			path: &PaintSVGPathData{
				path:              'M0 0L100 0L100 50Z'
				svg_gradient_data: &PaintSVGGradientData{
					fill_linear_gradient:   painting.SVGLinearGradientPaintStyle{
						gradient:  svg_gradient_snapshot_test_style(painting.Color{0, 0, 0, 255})
						end_point: painting.Point{100, 50}
					}
					stroke_linear_gradient: painting.SVGLinearGradientPaintStyle{
						gradient:  svg_gradient_snapshot_test_style(painting.Color{255, 0, 0, 255})
						end_point: painting.Point{50, 100}
					}
					fill_radial_gradient:   painting.SVGRadialGradientPaintStyle{
						gradient:   svg_gradient_snapshot_test_style(painting.Color{0, 128, 0, 255})
						end_radius: 40
					}
					stroke_radial_gradient: painting.SVGRadialGradientPaintStyle{
						gradient:     svg_gradient_snapshot_test_style(painting.Color{255, 255, 255, 255})
						start_radius: 2
						end_radius:   60
					}
				}
			}
		}
	}.paint_commands().filter(it.kind == 'draw_svg_path')
}

fn test_ordinary_commands_and_solid_svg_paths_have_no_gradient_snapshot() {
	assert sizeof(PaintCommand) < 3600
	assert (PaintCommand{ kind: 'draw_text' }).svg().svg_gradient_data == none
	assert (PaintCommand{ kind: 'fill_rect' }).svg().svg_gradient_data == none
	commands := BlockBox{
		svg_data: &BlockBoxSVGData{
			fill_color: 'red'
			path:       &PaintSVGPathData{
				path: 'M0 0L10 10'
			}
		}
	}.paint_commands()
	assert commands.any(it.kind == 'draw_svg_path')
	for command in commands {
		assert command.svg().svg_gradient_data == none
		assert command.fill_linear_gradient() == none
		assert command.stroke_radial_gradient() == none
	}
}

fn test_all_gradient_slots_retain_their_values_after_the_producer_and_collections() {
	commands := ephemeral_svg_gradient_commands()
	assert commands.len == 1
	for _ in 0 .. 3 {
		$if gcboehm ? {
			C.GC_gcollect()
		}
		fill := commands[0].fill_linear_gradient() or { panic('missing linear fill') }
		stroke := commands[0].stroke_linear_gradient() or { panic('missing linear stroke') }
		radial_fill := commands[0].fill_radial_gradient() or { panic('missing radial fill') }
		radial_stroke := commands[0].stroke_radial_gradient() or { panic('missing radial stroke') }
		assert fill.gradient.color_stops[0].color == painting.Color{0, 0, 0, 255}
		assert stroke.gradient.color_stops[0].color == painting.Color{255, 0, 0, 255}
		assert radial_fill.gradient.color_stops[0].color == painting.Color{0, 128, 0, 255}
		assert radial_stroke.gradient.color_stops[0].color == painting.Color{255, 255, 255, 255}
		assert fill.end_point == painting.Point{100, 50}
		assert stroke.end_point == painting.Point{50, 100}
		assert radial_fill.end_radius == 40
		assert radial_stroke.start_radius == 2
		assert radial_stroke.end_radius == 60
		assert fill.gradient.spread_method == .reflect
		assert fill.gradient.color_space == .linear_srgb
		repeat_length := fill.gradient.repeat_length or { panic('missing repeat length') }
		assert repeat_length == 0.5
		transform := fill.gradient.gradient_transform or { panic('missing transform') }
		assert transform == painting.Affine{ e: 3, f: 4 }
	}
}

fn test_force_dark_replaces_shared_gradient_snapshots_without_changing_recordings() {
	command := ephemeral_svg_gradient_commands()[0]
	original := command.svg().svg_gradient_data or { panic('missing original snapshot') }
	settings := painting.ForceDarkSettings.default()
	resolved := resolve_force_dark_paint_commands([command, command], settings)
	first := resolved[0].svg().svg_gradient_data or { panic('missing first dark snapshot') }
	second := resolved[1].svg().svg_gradient_data or { panic('missing second dark snapshot') }
	assert voidptr(original) != voidptr(first)
	assert voidptr(first) != voidptr(second)
	$if gcboehm ? {
		C.GC_gcollect()
	}
	linear := resolved[0].fill_linear_gradient() or { panic('missing dark linear fill') }
	linear_stroke := resolved[0].stroke_linear_gradient() or { panic('missing dark linear stroke') }
	radial := resolved[0].fill_radial_gradient() or { panic('missing dark radial fill') }
	radial_stroke := resolved[0].stroke_radial_gradient() or { panic('missing dark radial stroke') }
	assert linear.gradient.color_stops[0].color == painting.force_dark_resolve(painting.Color{0, 0, 0, 255}, .svg, settings)
	assert linear_stroke.gradient.color_stops[0].color == painting.force_dark_resolve(painting.Color{255, 0, 0, 255}, .svg, settings)
	assert radial.gradient.color_stops[0].color == painting.force_dark_resolve(painting.Color{0, 128, 0, 255}, .svg, settings)
	assert radial_stroke.gradient.color_stops[0].color == painting.force_dark_resolve(painting.Color{255, 255, 255, 255}, .svg, settings)
	original_fill := command.fill_linear_gradient() or { panic('missing original linear fill') }
	assert original_fill.gradient.color_stops[0].color == painting.Color{0, 0, 0, 255}
	assert linear.gradient.gradient_transform == original_fill.gradient.gradient_transform
}

fn test_gradient_snapshot_is_shared_by_replays_and_replaced_after_resource_mutation() {
	mut document := html.parse_document('<!doctype html><svg width="100" height="50"><defs><linearGradient id="g"><stop id="s" stop-color="red"/></linearGradient></defs><rect width="100" height="50" fill="url(#g)"/></svg>')
	_ = layout_document_typed_in_viewport(document, 100, 50)
	first := display_list_commands(document.record_display_list() or { panic('missing first recording') }).filter(it.kind == 'draw_svg_path')[0]
	first_data := first.svg().svg_gradient_data or { panic('missing first snapshot') }
	document.set_needs_repaint_with_invalidation(.paint_commands)
	second := display_list_commands(document.record_display_list() or { panic('missing replay') }).filter(it.kind == 'draw_svg_path')[0]
	second_data := second.svg().svg_gradient_data or { panic('missing shared snapshot') }
	assert voidptr(first_data) == voidptr(second_data)
	mut stop := document.get_element_by_id('s') or { panic('missing stop') }
	stop.set_attribute_value('stop-color', 'green')
	document.update_layout(.dump_display_list)
	third := display_list_commands(document.record_display_list() or { panic('missing updated recording') }).filter(it.kind == 'draw_svg_path')[0]
	third_data := third.svg().svg_gradient_data or { panic('missing new snapshot') }
	assert voidptr(first_data) != voidptr(third_data)
	$if gcboehm ? {
		C.GC_gcollect()
	}
	old_gradient := first.fill_linear_gradient() or { panic('missing retained red gradient') }
	new_gradient := third.fill_linear_gradient() or { panic('missing current green gradient') }
	assert old_gradient.gradient.color_stops[0].color == painting.Color{255, 0, 0, 255}
	assert new_gradient.gradient.color_stops[0].color == painting.Color{0, 128, 0, 255}
}
