module main

import css
import layout
import painting
import html
import platform

fn test_css_gradient_modes_preserve_premultiplied_interpolation() {
	assert chromium_gradient_native_spread(&layout.PaintCommand{}) == chromium_gradient_css_spread
	assert chromium_gradient_native_spread(&layout.PaintCommand{
		image_data: &layout.PaintImageData{}
	}) == chromium_gradient_css_spread
	for pattern in [false, true] {
		command := layout.PaintCommand{
			image_data: &layout.PaintImageData{
				background_layer_data: &layout.PaintBackgroundLayerData{gradient_pattern: pattern}
			}
		}
		assert chromium_gradient_native_spread(&command) == if pattern {
			chromium_gradient_pattern_spread
		} else {
			chromium_gradient_css_spread
		}
	}
}

fn test_chromium_linear_gradient_keeps_original_alpha_and_hard_stops() {
	gradient := layout.LinearGradient{
		y2:    1
		stops: [layout.GradientStop{css.Color{0, 0, 0, 0}, 0},
			layout.GradientStop{css.Color{0, 0, 0, 153}, .5},
			layout.GradientStop{css.Color{0, 0, 0, 255}, .5},
			layout.GradientStop{css.Color{0, 0, 0, 255}, 1}]
	}
	data := chromium_linear_gradient_stop_data(gradient, .5) or { panic('eligible gradient') }
	assert data.len == 20
	assert data[8] == f32(.3)
	assert data[13] == f32(.5)
	assert data[9] == data[14] && data[9] == f32(.5)
	assert gradient.stops.len == 4
}

fn test_gradient_replay_reuses_stop_sample_and_clip_vectors() {
	gradient := layout.LinearGradient{
		stops: [layout.GradientStop{css.Color{255, 0, 0, 255}, 0},
			layout.GradientStop{css.Color{255, 0, 0, 255}, .5},
			layout.GradientStop{css.Color{0, 0, 255, 128}, .5},
			layout.GradientStop{css.Color{0, 0, 255, 128}, 1}]
	}
	colors := layout.LinearGradient{colors: [css.Color{0, 0, 0, 255}, css.Color{255, 255, 255, 255}]}
	empty := layout.LinearGradient{}
	polygon := layout.PaintCommand{points: [f64(1), 2, 3, 4, 5, 6, 7, 8, 9, 10]}
	rectangle := layout.PaintCommand{gradient_background_layer: true}
	tile := painting.Rect{20, 30, 40, 50}
	mut storage := NativeGradientStorage{}
	native_gradient_stop_data_into(gradient, .5, mut storage.stops, mut storage.samples)
	assert storage.stops == native_gradient_stop_data(gradient, .5)
	assert storage.samples.any(it.offset == .5 && it.color.r == 255)
	assert storage.samples.any(it.offset == .5 && it.color.b == 255)
	native_gradient_clip_path_into(polygon, tile, mut storage.path)
	assert storage.path == native_gradient_clip_path(polygon, tile)
	assert chromium_linear_gradient_stop_data_into(colors, 1, mut storage.gpu_stops)
	before := platform.thread_arena_usage().used
	for _ in 0 .. 100 {
		native_gradient_stop_data_into(empty, 1, mut storage.stops, mut storage.samples)
		assert storage.stops.len == 0 && storage.samples.len == 0
		native_gradient_stop_data_into(gradient, .5, mut storage.stops, mut storage.samples)
		native_gradient_stop_data_into(colors, 1, mut storage.stops, mut storage.samples)
		assert storage.stops.len == 85
		assert storage.stops[0] == 0 && storage.stops[80] == 1
		assert storage.stops[84] == 1
		assert chromium_linear_gradient_stop_data_into(colors, .5, mut storage.gpu_stops)
		assert storage.gpu_stops.len == 10 && storage.gpu_stops[8] == f32(0.5)
		assert !chromium_linear_gradient_stop_data_into(gradient, 1, mut storage.gpu_stops)
		assert storage.gpu_stops.len == 0
		native_gradient_clip_path_into(polygon, tile, mut storage.path)
		native_gradient_clip_path_into(rectangle, tile, mut storage.path)
		assert storage.path.len == 5 * layout.compatibility_clip_path_segment_stride
		assert storage.path[1] == 20 && storage.path[2] == 30
		assert storage.path[25] == 60 && storage.path[26] == 80
		assert storage.path[48] == 5
	}
	$if prealloc { assert platform.thread_arena_usage().used == before }
}

fn test_chromium_linear_gradient_falls_back_for_other_interpolation_semantics() {
	gradient := layout.LinearGradient{
		stops: [layout.GradientStop{css.Color{255, 0, 0, 64}, 0},
			layout.GradientStop{css.Color{0, 0, 255, 255}, 1}]
	}
	assert chromium_linear_gradient_stop_data(gradient, 1) == none
	opaque := layout.LinearGradient{
		colors: [css.Color{255, 0, 0, 255}, css.Color{0, 0, 255, 255}]
	}
	assert (chromium_linear_gradient_stop_data(opaque, 1) or { panic('opaque sRGB') }).len == 10
	assert chromium_linear_gradient_stop_data(layout.LinearGradient{ ...opaque, radial: true }, 1) == none
	assert chromium_linear_gradient_stop_data(layout.LinearGradient{ ...opaque, kind: 'conic' }, 1) == none
	assert chromium_linear_gradient_stop_data(layout.LinearGradient{
		...opaque
		interpolation_method: css.ColorInterpolationMethod(css.RectangularColorSpace.oklab)
	}, 1) == none
	out_of_range := layout.LinearGradient{
		stops: [layout.GradientStop{css.Color{0, 0, 0, 0}, -.5},
			layout.GradientStop{css.Color{0, 0, 0, 255}, 1}]
	}
	assert chromium_linear_gradient_stop_data(out_of_range, 1) == none
}

fn test_chromium_linear_gradient_discards_invisible_rgb_before_constant_color_interpolation() {
	gradient := layout.LinearGradient{
		stops: [layout.GradientStop{css.Color{102, 102, 102, 0}, .7203},
			layout.GradientStop{css.Color{0, 0, 0, 255}, .9108}]
	}
	data := chromium_linear_gradient_stop_data(gradient, 1) or {
		panic('transparent RGB is not premultiplied color')
	}
	assert data == [f32(0), 0, 0, 0, .7203, 0, 0, 0, 1, .9108]
	assert gradient.stops[0].color.r == 102
	// A second visible color still requires general premultiplied interpolation.
	varying := layout.LinearGradient{
		stops: [layout.GradientStop{css.Color{102, 102, 102, 0}, 0},
			layout.GradientStop{css.Color{255, 0, 0, 128}, .5},
			layout.GradientStop{css.Color{0, 0, 0, 255}, 1}]
	}
	assert chromium_linear_gradient_stop_data(varying, 1) == none
}

fn test_chromium_linear_gradient_uses_float_angle_points_in_local_tile_coordinates() {
	tile := painting.Rect{20, 20, 269, 151}
	// Float reference values from Blink EndPointsFromAngle, compiled for arm64
	// with contraction disabled, matching its C++ arithmetic.
	angled := chromium_linear_gradient_points(layout.LinearGradient{ css_angle_degrees: 222 }, tile)
	assert angled == [f32(232.263672), -33.0775528, 36.7363281, 184.077545]!
	for angle, expected in {
		0:   [f32(0), 151, 0, 0]!
		90:  [f32(0), 0, 269, 0]!
		180: [f32(0), 0, 0, 151]!
		270: [f32(269), 0, 0, 0]!
	} {
		assert chromium_linear_gradient_points(layout.LinearGradient{ css_angle_degrees: f64(angle) },
			tile) == expected
	}
	assert chromium_linear_gradient_points(layout.LinearGradient{ css_angle_degrees: -138 }, tile) == angled
	assert chromium_linear_gradient_points(layout.LinearGradient{ css_angle_degrees: 582 }, tile) == angled
	// Detached commands without a source angle keep their existing endpoints.
	assert chromium_linear_gradient_points(layout.LinearGradient{ x1: .25, y1: .5, x2: .75, y2: 1 }, painting.Rect{10, 20, 100, 80}) == [
		f32(35),
		60,
		85,
		100,
	]!
}

fn test_retained_css_linear_gradient_carries_the_source_angle() {
	mut document :=
		html.parse_document('<!doctype html><style>body{margin:0}div{width:269px;height:151px;background:linear-gradient(222deg,#6660 72.03%,black 91.08%)}</style><div></div>')
	defer { document.finalize() }
	document.set_font_rendering_policy(.chromium)
	root := layout.layout_document_typed_in_viewport(document, 1024, 768)
	commands := root.paint_commands().filter(it.kind == 'fill_gradient')
	assert commands.len == 1
	gradient := commands[0].gradient or { panic('missing retained gradient') }
	assert gradient.css_angle_degrees? == 222
}

fn test_chromium_gradient_clip_transfer_preserves_local_rect_and_corner_order() {
	command := layout.PaintCommand{
		gradient_background_layer: true
		transform:                 [f64(1), 0, 0, 1, 200, 300]!
		image_data:                &layout.PaintImageData{
			image_clip_x:      2.25
			image_clip_y:      7.5
			image_clip_width:  129
			image_clip_height: 81
			image_clip_radii:  layout.BoxRadii{
				top_left:     layout.CornerRadius{1, 2}
				top_right:    layout.CornerRadius{3, 4}
				bottom_right: layout.CornerRadius{5, 6}
				bottom_left:  layout.CornerRadius{7, 8}
			}
		}
	}
	assert chromium_gradient_clip_data(command) == [f32(2.25), 7.5, 129, 81, 1, 2, 3, 4, 5, 6,
		7, 8]!
	gradient := layout.LinearGradient{ y2: 1, colors: [css.Color{0, 0, 0, 0}, css.Color{0, 0, 0, 255}] }
	assert chromium_gradient_uses_gpu_clip(command, gradient)
	assert !chromium_gradient_uses_gpu_clip(layout.PaintCommand{ ...command, gradient_background_layer: false }, gradient)
	assert !chromium_gradient_uses_gpu_clip(command, layout.LinearGradient{ ...gradient, y2: 0 })
	assert chromium_gradient_uses_gpu_clip(command, layout.LinearGradient{ ...gradient, kind: 'radial' })
}

fn test_chromium_gradient_transfers_only_compatible_rounded_ancestor() {
	identity := [f64(1), 0, 0, 1, 0, 0]!
	radius := layout.BoxRadii{top_left: layout.CornerRadius{4, 4}}
	compatible := layout.PaintClip{
		rect: layout.LayoutRect{32, 127, 269, 151}
		corner_radii: radius
		transform: identity
	}
	clips := [compatible,
		layout.PaintClip{...compatible, is_path: true},
		layout.PaintClip{...compatible, is_svg_mask: true},
		layout.PaintClip{...compatible, is_svg_content_mask: true},
		layout.PaintClip{...compatible, transform: [f64(1), 0, 0, 1, 0, 8]!}]
	command := layout.PaintCommand{
		kind: 'fill_gradient'
		gradient_background_layer: true
		has_clip: true
		gradient: &layout.LinearGradient{y2: 1, colors: [css.Color{0, 0, 0, 0}, css.Color{0, 0, 0, 255}]}
		transform: identity
		clip_list: &layout.PaintClipList{items: clips}
	}
	assert chromium_gradient_gpu_ancestor_clip_index(&command) == 0
	assert chromium_paint_clip_data(compatible) == [f32(32), 127, 269, 151, 4, 4, 0, 0, 0, 0, 0, 0]!
	assert chromium_gradient_gpu_ancestor_clip_index(&layout.PaintCommand{...command, kind: 'draw_svg_path'}) == -1
	assert chromium_gradient_gpu_ancestor_clip_index(&layout.PaintCommand{...command, gradient_background_layer: false}) == -1
	assert chromium_gradient_gpu_ancestor_clip_index(&layout.PaintCommand{...command, has_clip: false}) == -1
	assert chromium_gradient_gpu_ancestor_clip_index(&layout.PaintCommand{...command, clip_list: &layout.PaintClipList{items: clips[1..]}}) == -1
}

fn test_chromium_radial_gradient_retains_unquantized_stops_and_gpu_clips() {
	gradient := layout.LinearGradient{
		kind: 'radial'
		radial: true
		radius_x: .7
		radius_y: .9
		stops: [layout.GradientStop{css.Color{23,43,66,31}, 0},
			layout.GradientStop{css.Color{0,0,0,0}, .64}]
	}
	mut stops := []f32{}
	assert chromium_gradient_stop_data_into(gradient, .5, mut stops)
	assert stops.len == 10
	assert stops[0] == f32(23) / 255
	assert stops[3] == f32(f64(31) / 255 * .5)
	assert stops[5] == stops[0] && stops[6] == stops[1] && stops[7] == stops[2]
	assert stops[8] == 0 && stops[9] == f32(.64)
	command := layout.PaintCommand{gradient_background_layer: true}
	assert chromium_gradient_uses_gpu_clip(command, gradient)
	assert !chromium_gradient_uses_gpu_clip(command, layout.LinearGradient{...gradient, radius_x: 0})
	assert !chromium_gradient_uses_gpu_clip(command, layout.LinearGradient{
		...gradient
		interpolation_method: css.ColorInterpolationMethod(css.RectangularColorSpace.oklab)
	})
	assert !chromium_gradient_uses_gpu_clip(command, layout.LinearGradient{
		...gradient
		stops: [layout.GradientStop{css.Color{255,0,0,128}, 0},
			layout.GradientStop{css.Color{0,0,255,255}, 1}]
	})
}
