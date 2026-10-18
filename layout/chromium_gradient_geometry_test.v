module layout

import css
import html
import math

fn fractional_gradient_command(chromium bool) PaintCommand {
	mut document :=
		html.parse_document('<!doctype html><style>body{margin:0}div{position:absolute;left:32px;top:127px;width:268.796875px;height:151.1875px;background:linear-gradient(to right,black 20px,transparent)}</style><div></div>')
	defer { document.finalize() }
	if chromium { document.set_font_rendering_policy(.chromium) }
	root := layout_document_typed_in_viewport(document, 1024, 768)
	return root.paint_commands().filter(it.kind == 'fill_gradient')[0]
}

fn test_generated_gradient_resolves_tile_and_absolute_stops_against_snapped_area() {
	chromium := fractional_gradient_command(true)
	assert chromium.x == 32 && chromium.y == 127
	assert chromium.width == 269 && chromium.height == 151
	assert resolved_background_gradient_tiles(chromium)[0].width == 269
	gradient := chromium.gradient or { panic('gradient') }
	assert math.abs(gradient.stops[0].offset - 20.0 / 269) < 1e-12
	libweb := fractional_gradient_command(false)
	assert libweb.width == 268.796875 && libweb.height == 151.1875
	assert resolved_background_gradient_tiles(libweb)[0].width == 268.796875
	libweb_gradient := libweb.gradient or { panic('LibWeb gradient') }
	assert math.abs(libweb_gradient.stops[0].offset - 20.0 / 268.796875) < 1e-12
}

fn test_nondefault_gradient_geometry_keeps_its_independent_sizing_and_phase() {
	assert chromium_default_gradient_geometry(css.BackgroundLayerData{})
	assert !chromium_default_gradient_geometry(css.BackgroundLayerData{
		position_x: css.LengthPercentage.from_percentage(css.Percentage.new(50))
	})
	assert !chromium_default_gradient_geometry(css.BackgroundLayerData{ size_type: .cover })
	assert !chromium_default_gradient_geometry(css.BackgroundLayerData{
		size_x: css.LengthPercentageOrAuto.from_length_percentage(css.LengthPercentage.from_percentage(css.Percentage.new(75)))
	})
}
