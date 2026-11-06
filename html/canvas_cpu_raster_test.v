module html

import dom
import skia

fn cpu_raster_test_context() &CanvasRenderingContext2D {
	mut document := dom.Document.create(dom.url_about_blank())
	element := document.create_element_ns('http://www.w3.org/1999/xhtml', 'canvas') or {
		panic(err)
	}
	canvas := unsafe { &dom.HTMLCanvasElement(element) }
	return html_canvas_element_get_context(canvas, '2d', none) or { panic(err) }
}

struct CpuRasterTestFill {
	color     dom.Color
	transform CanvasAffineTransform
	fill_rule string
}

fn cpu_raster_test_path(mut context CanvasRenderingContext2D, index int) {
	context.begin_path()
	if index == 0 {
		context.move_to(12.25, 8.5)
		context.quadratic_curve_to(140, 4, 120.75, 90.5)
		context.bezier_curve_to(60, 160, -20, 40, 30.5, 70.25)
		context.close_path()
		context.rect(40.5, 30.25, 80, 50)
	} else {
		context.move_to(150, 20)
		context.line_to(320, 75.5)
		context.line_to(150, 140)
		context.line_to(200, 10)
		context.line_to(260, 160)
		context.arc(230, 90, 35.5, 0.3, 4.2, false) or { panic(err) }
		context.ellipse(90, 110, 50, 22.5, 0.6, 0, 5.5, true) or { panic(err) }
	}
}

// Solid source-over fills take the Skia-free rasterizer; they must produce
// the pixels skia.draw_path() produces for the same command.
fn test_solid_canvas_fills_match_skia() {
	fills := [
		CpuRasterTestFill{dom.Color{
			r: 200
			g: 40
			b: 90
			a: 255
		}, CanvasAffineTransform{1, 0, 0, 1, 0, 0}, 'nonzero'},
		CpuRasterTestFill{dom.Color{
			r: 30
			g: 160
			b: 220
			a: 128
		}, CanvasAffineTransform{0.9, 0.35, -0.3, 1.1, 20, -6}, 'evenodd'},
	]
	mut context := cpu_raster_test_context()
	mut expected := []u8{}
	mut expected_alpha_type := 0
	for i, fill in fills {
		context.drawing_state.fill_style = FillOrStrokeStyle.from_color(fill.color)
		context.drawing_state.transform = fill.transform
		cpu_raster_test_path(mut context, i)
		bitmap := context.canvas_.bitmap() or { panic('missing canvas bitmap') }
		mut pixels := if i == 0 { bitmap.data.clone() } else { expected }
		alpha_type := if i == 0 { int(bitmap.alpha_type) } else { expected_alpha_type }
		command := skia.Command{
			path:         canvas_skia_path(context.CanvasPath.path(), fill.fill_rule)
			style:        canvas_skia_style(context.drawing_state.fill_style.to_gfx_paint_style())
			transform:    canvas_skia_transform(fill.transform)
			global_alpha: 1
		}
		assert skia.draw_path(mut pixels, bitmap.width, bitmap.height, bitmap.pitch, alpha_type,
			command)
		expected = pixels.clone()
		expected_alpha_type = 2
		context.fill(fill.fill_rule)
	}
	bitmap := context.canvas_.bitmap() or { panic('missing canvas bitmap') }
	assert bitmap.alpha_type == 2
	assert bitmap.data == expected
	assert expected.any(it != 0 && it != 255)
}
