module layout

import css
import html
import painting

fn test_retained_sprite_natural_size_uses_layout_coordinates() {
	for scale in [1.0, 2.0] {
		data := PaintBackgroundLayerData{
			layer:                   css.BackgroundLayerData{
				position_x: css.LengthPercentage.from_length(css.Length.make_px(-30 * scale))
				position_y: css.LengthPercentage.from_length(css.Length.make_px(-12 * scale))
				repeat_x:   .no_repeat
				repeat_y:   .no_repeat
			}
			layout_coordinate_scale: scale
		}
		natural := css.SizeWithAspectRatio{
			width:        css.CSSPixels.new(120)
			height:       css.CSSPixels.new(80)
			aspect_ratio: css.CSSPixelFraction.new(css.CSSPixels.new(3), css.CSSPixels.new(2))
		}
		layer := data.resolve_image('sprite.png', painting.Rect{0, 0, 20 * scale, 16 * scale},
			natural) or { panic('missing sprite layer') }
		assert layer.image_rect == painting.Rect{0, 0, 120 * scale, 80 * scale}
		assert layer.position_x == -30 * scale
		assert layer.position_y == -12 * scale
		// A clipped destination still selects the original sprite's source pixels.
		assert -layer.position_x * 120 / layer.image_rect.width == 30
		assert -layer.position_y * 80 / layer.image_rect.height == 12
		assert (natural.width or { panic('missing source width') }) == css.CSSPixels.new(120)
	}
}

fn test_device_background_sizing_preserves_svg_missing_dimension_and_ratio() {
	data := PaintBackgroundLayerData{ layout_coordinate_scale: 2 }
	layer := data.resolve_image('one-dimension.svg', painting.Rect{0, 0, 200, 100},
		css.SizeWithAspectRatio{
			height:       css.CSSPixels.new(10)
			aspect_ratio: css.CSSPixelFraction.new(css.CSSPixels.new(3), css.CSSPixels.new(2))
		}) or { panic('missing SVG layer') }
	assert layer.image_rect.width == 30
	assert layer.image_rect.height == 20
}

fn test_device_background_explicit_size_is_not_projected_twice() {
	data := PaintBackgroundLayerData{
		layer:                   css.BackgroundLayerData{
			size_x: css.LengthPercentageOrAuto.from_length(css.Length.make_px(40))
		}
		layout_coordinate_scale: 2
	}
	layer := data.resolve_image('sprite.png', painting.Rect{0, 0, 200, 100},
		css.SizeWithAspectRatio{
			width:        css.CSSPixels.new(120)
			height:       css.CSSPixels.new(80)
			aspect_ratio: css.CSSPixelFraction.new(css.CSSPixels.new(3), css.CSSPixels.new(2))
		}) or { panic('missing sized layer') }
	assert layer.image_rect.width == 40
	assert layer.image_rect.height == 26.65625
}

fn test_background_recording_retains_its_layout_coordinate_scale() {
	mut document := html.parse_document('<!doctype html><style>html,body{margin:0}div{width:20px;height:16px;background:url(sprite.png) no-repeat -30px -12px}</style><div></div>')
	defer { document.finalize() }
	document.set_layout_coordinate_scale(2)
	_ = layout_document_typed_in_viewport(document, 320, 100)
	commands := display_list_commands(document.record_display_list() or { panic('missing recording') })
	data := commands.filter(it.kind == 'draw_background_image')[0].image().background_layer_data or {
		panic('missing background snapshot')
	}
	assert data.layout_coordinate_scale == 2
	assert data.layer.position_x.to_px(data.resolution_context, css.CSSPixels.new(40)) == css.CSSPixels.new(-60)
	document.set_layout_coordinate_scale(1)
	assert data.layout_coordinate_scale == 2
}
