module layout

import painting

$if gcboehm ? {
	fn C.GC_gcollect()
}

fn grouped_box_test_snapshot() &PaintSVGGradientData {
	return &PaintSVGGradientData{
		fill_linear_gradient:   painting.SVGLinearGradientPaintStyle{
			gradient:  painting.SVGGradientPaintStyle{
				color_stops: [
					painting.ColorStop{
						color:    painting.Color{255, 0, 0, 255}
						position: 0.25
					},
				]
			}
			end_point: painting.Point{100, 50}
		}
		stroke_linear_gradient: painting.SVGLinearGradientPaintStyle{
			gradient:  painting.SVGGradientPaintStyle{
				color_stops: [
					painting.ColorStop{
						color:    painting.Color{0, 128, 0, 255}
						position: 0.5
					},
				]
			}
			end_point: painting.Point{50, 100}
		}
		fill_radial_gradient:   painting.SVGRadialGradientPaintStyle{
			gradient:   painting.SVGGradientPaintStyle{
				color_stops: [
					painting.ColorStop{
						color:    painting.Color{0, 0, 255, 255}
						position: 0.75
					},
				]
			}
			end_radius: 40
		}
		stroke_radial_gradient: painting.SVGRadialGradientPaintStyle{
			gradient:     painting.SVGGradientPaintStyle{
				color_stops: [
					painting.ColorStop{
						color:    painting.Color{255, 255, 0, 255}
						position: 1
					},
				]
			}
			start_radius: 2
			end_radius:   60
		}
	}
}

fn grouped_box_test_producer() BlockBox {
	return BlockBox{
		width:    100
		height:   50
		svg_data: &BlockBoxSVGData{
			path: &PaintSVGPathData{
				path:              'M0 0L100 0L100 50Z'
				svg_gradient_data: grouped_box_test_snapshot()
			}
		}
	}
}

fn test_block_box_groups_rare_svg_gradient_values_below_one_heap_block() {
	// Boehm adds its allocation sentinel. Keep the record below 4 KiB so a
	// one-child vector occupies one block rather than two.
	assert sizeof(BlockBox) < 4096
	box := BlockBox{}
	assert sizeof(box.svg_data) == sizeof(voidptr)
	assert box.svg_data == unsafe { nil }
	for candidate in [BlockBox{ width: 20 }, BlockBox{
		svg_data: &BlockBoxSVGData{
			fill_color: 'red'
			path:       &PaintSVGPathData{
				path: 'M0 0L10 10'
			}
		}
	}] {
		assert candidate.svg_path().svg_gradient_data == none
		for command in candidate.paint_commands() {
			assert command.svg().svg_gradient_data == none
		}
	}
	// Explicit all-absent data keeps the old all-four-Options-absent behavior.
	empty := BlockBox{
		svg_data: &BlockBoxSVGData{
			path: &PaintSVGPathData{
				path:              'M0 0L10 10'
				svg_gradient_data: &PaintSVGGradientData{}
			}
		}
	}
	for command in empty.paint_commands() {
		assert command.svg().svg_gradient_data == none
	}
}

fn test_block_box_commands_share_the_grouped_snapshot_after_producer_and_collections() {
	box := grouped_box_test_producer()
	assert box.svg_path().svg_gradient_data != none
	first := box.paint_commands().filter(it.kind == 'draw_svg_path')
	assert first.len == 1
	data := first[0].svg().svg_gradient_data or { panic('missing snapshot') }
	assert voidptr(data) == voidptr(box.svg_path().svg_gradient_data or { panic('missing box gradient') })
	for _ in 0 .. 3 {
		$if gcboehm ? {
			C.GC_gcollect()
		}
		next := box.paint_commands().filter(it.kind == 'draw_svg_path')
		assert next.len == 1
		next_data := next[0].svg().svg_gradient_data or { panic('missing shared snapshot') }
		assert next_data == data
		fill := next[0].fill_linear_gradient() or { panic('missing linear fill') }
		stroke := next[0].stroke_linear_gradient() or { panic('missing linear stroke') }
		radial_fill := next[0].fill_radial_gradient() or { panic('missing radial fill') }
		radial_stroke := next[0].stroke_radial_gradient() or { panic('missing radial stroke') }
		assert fill.gradient.color_stops[0].color == painting.Color{255, 0, 0, 255}
		assert stroke.gradient.color_stops[0].color == painting.Color{0, 128, 0, 255}
		assert radial_fill.gradient.color_stops[0].color == painting.Color{0, 0, 255, 255}
		assert radial_stroke.gradient.color_stops[0].color == painting.Color{255, 255, 0, 255}
		assert fill.end_point == painting.Point{100, 50}
		assert stroke.end_point == painting.Point{50, 100}
		assert radial_fill.end_radius == 40
		assert radial_stroke.start_radius == 2
		assert radial_stroke.end_radius == 60
	}
}
