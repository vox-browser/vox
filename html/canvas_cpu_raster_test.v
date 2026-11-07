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
	} else if index == 2 {
		// A lone closed rect, which SkStroke outlines as rects, and a
		// zero-length subpath that only round and square caps draw.
		context.rect(60.5, 40.25, 110, 70)
		context.move_to(250, 60)
		context.line_to(250, 60)
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
		context.drawing_state.global_alpha = if i == 0 { 1.0 } else { 0.62 }
		cpu_raster_test_path(mut context, i)
		bitmap := context.canvas_.bitmap() or { panic('missing canvas bitmap') }
		mut pixels := if i == 0 { bitmap.data.clone() } else { expected }
		alpha_type := if i == 0 { int(bitmap.alpha_type) } else { expected_alpha_type }
		command := skia.Command{
			path:         canvas_skia_path(context.CanvasPath.path(), fill.fill_rule)
			style:        canvas_skia_style(context.drawing_state.fill_style.to_gfx_paint_style())
			transform:    canvas_skia_transform(fill.transform)
			global_alpha: f32(context.drawing_state.global_alpha)
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

struct CpuRasterTestStroke {
	width       f64
	cap         CanvasLineCap
	join        CanvasLineJoin
	transform   CanvasAffineTransform
	alpha       f64
	dashes      []f64
	dash_offset f64
}

// Strokes at most a device pixel wide take the Skia-free hairline
// rasterizer, wider ones the Skia-free SkStroke port, and dashed ones the
// SkDashPathEffect port first; all must produce the pixels skia.draw_path()
// produces for the same command.
fn test_canvas_strokes_match_skia() {
	strokes := [
		CpuRasterTestStroke{1, .butt, .miter, CanvasAffineTransform{1, 0, 0, 1, 0, 0}, 1, []f64{}, 0},
		CpuRasterTestStroke{0.45, .round, .round, CanvasAffineTransform{1, 0, 0, 1, 0.5, 0}, 0.8, []f64{}, 0},
		CpuRasterTestStroke{1.6, .square, .bevel, CanvasAffineTransform{0.5, 0.2, -0.1, 0.55, 12, 4}, 1, []f64{}, 0},
		CpuRasterTestStroke{3, .round, .miter, CanvasAffineTransform{1, 0, 0, 1, 0, 0}, 0.7, []f64{}, 0},
		CpuRasterTestStroke{7.5, .square, .miter, CanvasAffineTransform{0.94, 0.34, -0.34, 0.94, 30, -12}, 1, []f64{}, 0},
		CpuRasterTestStroke{12, .round, .round, CanvasAffineTransform{1.2, 0, 0, 0.8, -6, 3}, 0.9, []f64{}, 0},
		CpuRasterTestStroke{9, .butt, .bevel, CanvasAffineTransform{0, 1, -1, 0, 260, 10}, 1, []f64{}, 0},
		CpuRasterTestStroke{5, .round, .miter, CanvasAffineTransform{1, 0, 0, 1, 0, 0}, 1, []f64{}, 0},
		CpuRasterTestStroke{16, .square, .round, CanvasAffineTransform{1, 0, 0, 1, 0, 0}, 0.6, []f64{}, 0},
		CpuRasterTestStroke{1, .butt, .miter, CanvasAffineTransform{1, 0, 0, 1, 0, 0}, 1, [
			f64(8),
			4,
		], 2},
		CpuRasterTestStroke{6, .round, .round, CanvasAffineTransform{0.94, 0.34, -0.34, 0.94, 30, -12}, 0.8, [
			f64(14),
			6,
			0,
			6,
		], -3},
		CpuRasterTestStroke{4, .butt, .bevel, CanvasAffineTransform{1, 0, 0, 1, 0, 0}, 1, [
			f64(10),
			5,
		], 7.5},
	]
	mut context := cpu_raster_test_context()
	mut expected := []u8{}
	mut expected_alpha_type := 0
	for i, stroke in strokes {
		color := dom.Color{
			r: u8(40 + i * 50)
			g: 120
			b: u8(220 - i * 40)
			a: if i == 1 { u8(200) } else { u8(255) }
		}
		context.drawing_state.stroke_style = FillOrStrokeStyle.from_color(color)
		context.drawing_state.transform = stroke.transform
		context.drawing_state.global_alpha = stroke.alpha
		context.drawing_state.line_width = stroke.width
		context.drawing_state.line_cap = stroke.cap
		context.drawing_state.line_join = stroke.join
		context.drawing_state.dash_list = stroke.dashes
		context.drawing_state.line_dash_offset = stroke.dash_offset
		cpu_raster_test_path(mut context, i % 3)
		bitmap := context.canvas_.bitmap() or { panic('missing canvas bitmap') }
		mut pixels := if i == 0 { bitmap.data.clone() } else { expected }
		alpha_type := if i == 0 { int(bitmap.alpha_type) } else { expected_alpha_type }
		state := context.drawing_state
		command := skia.Command{
			path:         canvas_skia_path(context.CanvasPath.path(), 'nonzero')
			style:        canvas_skia_style(state.stroke_style.to_gfx_paint_style())
			transform:    canvas_skia_transform(stroke.transform)
			stroke:       true
			cap:          int(stroke.cap)
			join:         int(stroke.join)
			width:        f32(stroke.width)
			miter:        f32(state.miter_limit)
			global_alpha: f32(stroke.alpha)
			dashes:       stroke.dashes.map(f32(it))
			dash_offset:  f32(stroke.dash_offset)
		}
		assert skia.draw_path(mut pixels, bitmap.width, bitmap.height, bitmap.pitch, alpha_type,
			command)
		expected = pixels.clone()
		expected_alpha_type = 2
		context.stroke()
		after := context.canvas_.bitmap() or { panic('missing canvas bitmap') }
		assert after.data == expected, 'stroke ${i} differs from Skia'
	}
	assert expected.any(it != 0 && it != 255)
}
