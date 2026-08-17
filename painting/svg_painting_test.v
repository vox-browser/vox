module painting

fn test_svg_gradient_stops_are_sorted_and_pattern_retains_transform() {
	mut gradient := SVGGradientPaintStyle{}
	gradient.add_color_stop(ColorStop{
		position: 0.8
		color:    Color{
			r: 8
		}
	}, true)
	gradient.add_color_stop(ColorStop{
		position: 0.2
		color:    Color{
			r: 2
		}
	}, true)
	assert gradient.color_stops.map(it.position) == [0.2, 0.8]
	pattern := SVGPatternPaintStyle{'tile-list', Rect{1, 2, 3, 4}, Affine{
		e: 5
	}}
	assert pattern.tile_display_list_id == 'tile-list'
	assert pattern.pattern_transform != none
}

fn test_svg_path_hit_test_handles_fill_stroke_and_noninvertible_transform() {
	square := [Point{0, 0}, Point{20, 0}, Point{20, 20}, Point{0, 20}]
	filled := SVGPaintable{
		id:   'filled'
		kind: .path
		path: square
	}
	assert filled.hit_test(Point{10, 10})
	assert !filled.hit_test(Point{30, 10})
	stroked := SVGPaintable{
		id:             'stroke'
		kind:           .path
		path:           [Point{0, 0}, Point{20, 0}]
		fill_enabled:   false
		stroke_enabled: true
		stroke_width:   4
	}
	assert stroked.hit_test(Point{10, 1})
	assert !stroked.hit_test(Point{10, 3})
	noninvertible := SVGPaintable{
		id:        'bad'
		kind:      .path
		path:      square
		transform: Affine{
			a: 0
			d: 0
		}
	}
	assert !noninvertible.hit_test(Point{10, 10})
}

fn test_svg_painting_masks_clips_and_descendant_order() {
	converter := new_device_pixel_converter(2) or { panic(err) }
	child := SVGPaintable{
		id:            'child'
		kind:          .path
		absolute_rect: Rect{1, 2, 3, 4}
		path:          [Point{0, 0}, Point{2, 0}, Point{1, 2}]
	}
	root := SVGPaintable{
		id:            'root'
		kind:          .path
		absolute_rect: Rect{0, 0, 10, 10}
		path:          [Point{0, 0}, Point{10, 0}, Point{0, 10}]
		children:      [child]
	}
	commands := paint_svg_descendants(root, .foreground, converter, Color{ r: 9 })
	assert commands.len == 2
	assert command_name(commands[0]) == 'FillPath'
	mask := calculate_svg_mask_display_list(SVGMaskDefinition{
		id:      'mask'
		area:    Rect{1, 2, 5, 5}
		content: [child]
	}, converter)
	assert mask.commands.len == 2
	assert mask.commands[0].command is Translate
	assert (mask.commands[0].command as Translate).delta == IntPoint{-2, -4}
	clip := calculate_svg_clip_display_list(SVGClipDefinition{
		id:      'clip'
		area:    Rect{3, 4, 4, 4}
		content: [child]
	}, converter)
	assert clip.commands.len == 2
	assert (clip.commands[0].command as Translate).delta == IntPoint{-6, -8}
	assert command_name(clip.commands[1].command) == 'FillPath'
	assert (clip.commands[1].command as FillPath).winding_rule == .nonzero
	assert child.paint_commands(.background, converter, Color{}).len == 0
}
