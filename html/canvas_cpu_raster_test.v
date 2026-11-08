module html

import dom
import geometry
import math
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

// Fills and strokes inside canvas clips take the Skia-free rasterizer with
// its anti-aliased clip; they must match skia.draw_path() with the same
// device-space clip paths.
fn test_clipped_canvas_draws_match_skia() {
	mut context := cpu_raster_test_context()
	context.begin_path()
	context.arc(150, 80, 70.5, 0, 6.283, false) or { panic(err) }
	context.clip('nonzero')
	context.begin_path()
	context.rect(40.25, 20.5, 230.5, 110.75)
	context.rect(120, 60, 30, 30)
	context.clip('evenodd')
	widths := [f64(0), 1, 7, 3]
	mut expected := []u8{}
	mut expected_alpha_type := 0
	for i, width in widths {
		stroke := width > 0
		color := dom.Color{
			r: u8(30 + i * 60)
			g: 90
			b: u8(210 - i * 50)
			a: if i == 2 { u8(180) } else { u8(255) }
		}
		if stroke {
			context.drawing_state.stroke_style = FillOrStrokeStyle.from_color(color)
		} else {
			context.drawing_state.fill_style = FillOrStrokeStyle.from_color(color)
		}
		context.drawing_state.transform = CanvasAffineTransform{1, 0, 0, 1, 0, 0}
		context.drawing_state.line_width = if stroke { width } else { 1 }
		context.drawing_state.line_cap = if i == 2 { CanvasLineCap.round } else { .butt }
		context.drawing_state.dash_list = if i == 3 { [f64(9), 4] } else { []f64{} }
		cpu_raster_test_path(mut context, i % 3)
		bitmap := context.canvas_.bitmap() or { panic('missing canvas bitmap') }
		mut pixels := if i == 0 { bitmap.data.clone() } else { expected }
		alpha_type := if i == 0 { int(bitmap.alpha_type) } else { expected_alpha_type }
		state := context.drawing_state
		style := if stroke { state.stroke_style } else { state.fill_style }
		command := skia.Command{
			path:         canvas_skia_path(context.CanvasPath.path(), 'nonzero')
			style:        canvas_skia_style(style.to_gfx_paint_style())
			transform:    canvas_skia_transform(state.transform)
			clips:        state.clip_paths.map(canvas_skia_path(it.path, it.fill_rule))
			stroke:       stroke
			cap:          int(state.line_cap)
			join:         int(state.line_join)
			width:        f32(state.line_width)
			miter:        f32(state.miter_limit)
			global_alpha: f32(state.global_alpha)
			dashes:       state.dash_list.map(f32(it))
			dash_offset:  f32(state.line_dash_offset)
		}
		assert skia.draw_path(mut pixels, bitmap.width, bitmap.height, bitmap.pitch, alpha_type,
			command)
		expected = pixels.clone()
		expected_alpha_type = 2
		if stroke {
			context.stroke()
		} else {
			context.fill('nonzero')
		}
		after := context.canvas_.bitmap() or { panic('missing canvas bitmap') }
		assert after.data == expected, 'clipped draw ${i} differs from Skia'
	}
	assert expected.any(it != 0 && it != 255)
}

struct CpuRasterTestComposite {
	operation CompositingAndBlendingOperator
	width     f64
	alpha     f64
	color     dom.Color
}

// Fills and strokes with composite operations take the Skia-free raster
// pipeline blitter, except the runtime-effect plus-lighter and plus-darker
// blenders, which stay on Skia; all must match skia.draw_path() with the same
// composite operation.
fn test_composited_canvas_draws_match_skia() {
	draws := [
		CpuRasterTestComposite{.source_over, 0, 1, dom.Color{200, 60, 40, 255}},
		CpuRasterTestComposite{.multiply, 0, 0.8, dom.Color{40, 140, 220, 255}},
		CpuRasterTestComposite{.color_dodge, 6, 0.9, dom.Color{230, 200, 30, 210}},
		CpuRasterTestComposite{.destination_out, 0.6, 1, dom.Color{0, 0, 0, 255}},
		CpuRasterTestComposite{.source_in, 0.6, 0.7, dom.Color{90, 220, 120, 255}},
		CpuRasterTestComposite{.copy, 0, 0.5, dom.Color{250, 250, 250, 160}},
		CpuRasterTestComposite{.hue, 3, 1, dom.Color{30, 60, 250, 255}},
		CpuRasterTestComposite{.plus_lighter, 0, 0.6, dom.Color{120, 30, 90, 255}},
		CpuRasterTestComposite{.soft_light, 0, 1, dom.Color{255, 255, 255, 255}},
	]
	mut context := cpu_raster_test_context()
	mut expected := []u8{}
	mut expected_alpha_type := 0
	for i, draw in draws {
		stroke := draw.width > 0
		if stroke {
			context.drawing_state.stroke_style = FillOrStrokeStyle.from_color(draw.color)
		} else {
			context.drawing_state.fill_style = FillOrStrokeStyle.from_color(draw.color)
		}
		context.drawing_state.transform = CanvasAffineTransform{0.97, 0.1, -0.12, 1.02, 4, -2}
		context.drawing_state.global_alpha = draw.alpha
		context.drawing_state.line_width = if stroke { draw.width } else { 1 }
		context.drawing_state.current_compositing_and_blending_operator = draw.operation
		cpu_raster_test_path(mut context, i % 3)
		bitmap := context.canvas_.bitmap() or { panic('missing canvas bitmap') }
		mut pixels := if i == 0 { bitmap.data.clone() } else { expected }
		alpha_type := if i == 0 { int(bitmap.alpha_type) } else { expected_alpha_type }
		state := context.drawing_state
		style := if stroke { state.stroke_style } else { state.fill_style }
		command := skia.Command{
			path:         canvas_skia_path(context.CanvasPath.path(), 'nonzero')
			style:        canvas_skia_style(style.to_gfx_paint_style())
			transform:    canvas_skia_transform(state.transform)
			stroke:       stroke
			cap:          int(state.line_cap)
			join:         int(state.line_join)
			composite:    int(draw.operation)
			width:        f32(state.line_width)
			miter:        f32(state.miter_limit)
			global_alpha: f32(state.global_alpha)
		}
		assert skia.draw_path(mut pixels, bitmap.width, bitmap.height, bitmap.pitch, alpha_type,
			command)
		expected = pixels.clone()
		expected_alpha_type = 2
		if stroke {
			context.stroke()
		} else {
			context.fill('nonzero')
		}
		after := context.canvas_.bitmap() or { panic('missing canvas bitmap') }
		assert after.data == expected, 'composited draw ${i} (${draw.operation}) differs from Skia'
	}
	assert expected.any(it != 0 && it != 255)
}

struct CpuRasterTestShadow {
	blur      f64
	offset_x  f64
	offset_y  f64
	width     f64
	operation CompositingAndBlendingOperator
	shadow    dom.Color
}

// Shadows with a blur take the Skia-free blur mask filter: a lone rect's
// analytic nine-patch, a stroked rect's ring nine-patch and blurred masks for
// other paths and hairlines. The shadow and the shape must match
// skia.draw_path() drawing both commands.
fn test_blurred_canvas_shadows_match_skia() {
	shadows := [
		CpuRasterTestShadow{12, 6, 4, 0, .source_over, dom.Color{20, 30, 60, 200}},
		CpuRasterTestShadow{3, -4, 5, 5, .source_over, dom.Color{200, 40, 40, 255}},
		CpuRasterTestShadow{20, 0, 8, 1, .multiply, dom.Color{0, 0, 0, 160}},
		CpuRasterTestShadow{8, 10, -6, 0, .destination_over, dom.Color{40, 160, 90, 230}},
	]
	mut context := cpu_raster_test_context()
	mut expected := []u8{}
	mut expected_alpha_type := 0
	for i, shadow in shadows {
		stroke := shadow.width > 0
		color := dom.Color{
			r: u8(60 + i * 40)
			g: 150
			b: u8(200 - i * 30)
			a: 255
		}
		if stroke {
			context.drawing_state.stroke_style = FillOrStrokeStyle.from_color(color)
		} else {
			context.drawing_state.fill_style = FillOrStrokeStyle.from_color(color)
		}
		context.drawing_state.transform = CanvasAffineTransform{0.95, 0, 0, 1.05, 3, 2}
		context.drawing_state.global_alpha = 1
		context.drawing_state.line_width = if stroke { shadow.width } else { 1 }
		context.drawing_state.current_compositing_and_blending_operator = shadow.operation
		context.drawing_state.shadow_blur = shadow.blur
		context.drawing_state.shadow_offset_x = shadow.offset_x
		context.drawing_state.shadow_offset_y = shadow.offset_y
		context.drawing_state.shadow_color = shadow.shadow
		cpu_raster_test_path(mut context, i % 3)
		bitmap := context.canvas_.bitmap() or { panic('missing canvas bitmap') }
		mut pixels := if i == 0 { bitmap.data.clone() } else { expected }
		mut alpha_type := if i == 0 { int(bitmap.alpha_type) } else { expected_alpha_type }
		state := context.drawing_state
		style := if stroke { state.stroke_style } else { state.fill_style }
		path := canvas_skia_path(context.CanvasPath.path(), 'nonzero')
		alpha := canvas_shadow_alpha(state)
		shadow_color := dom.Color{shadow.shadow.r, shadow.shadow.g, shadow.shadow.b, u8(math.round(f32(shadow.shadow.a) * alpha))}
		shadow_command := skia.Command{
			path:         path
			style:        canvas_skia_style(FillOrStrokeStyle.from_color(shadow_color).to_gfx_paint_style())
			transform:    canvas_skia_transform(canvas_transform_multiply(CanvasAffineTransform{
				e: shadow.offset_x
				f: shadow.offset_y
			}, state.transform))
			stroke:       stroke
			cap:          int(state.line_cap)
			join:         int(state.line_join)
			composite:    int(shadow.operation)
			width:        f32(state.line_width)
			miter:        f32(state.miter_limit)
			global_alpha: 1
			blur:         f32(shadow.blur)
		}
		assert skia.draw_path(mut pixels, bitmap.width, bitmap.height, bitmap.pitch, alpha_type,
			shadow_command)
		alpha_type = 2
		command := skia.Command{
			...shadow_command
			style:     canvas_skia_style(style.to_gfx_paint_style())
			transform: canvas_skia_transform(state.transform)
			blur:      0
		}
		assert skia.draw_path(mut pixels, bitmap.width, bitmap.height, bitmap.pitch, alpha_type,
			command)
		expected = pixels.clone()
		expected_alpha_type = 2
		if stroke {
			context.stroke()
		} else {
			context.fill('nonzero')
		}
		after := context.canvas_.bitmap() or { panic('missing canvas bitmap') }
		assert after.data == expected, 'shadow ${i} differs from Skia'
	}
	assert expected.any(it != 0 && it != 255)
}

// Linear, radial and conic gradient fills and strokes take the Skia-free
// gradient shader; they must match skia.draw_path() with the same style.
fn test_gradient_canvas_draws_match_skia() {
	mut linear := CanvasGradient.create_linear(20, 10, 260, 130)
	linear.add_color_stop(0, 'rgb(220, 40, 60)') or { panic(err) }
	linear.add_color_stop(0.45, 'rgba(30, 200, 90, 0.4)') or { panic(err) }
	linear.add_color_stop(1, 'rgb(20, 60, 230)') or { panic(err) }
	mut radial := CanvasGradient.create_radial(120, 70, 8, 160, 90, 90) or { panic(err) }
	radial.add_color_stop(0, 'white') or { panic(err) }
	radial.add_color_stop(0.6, 'rgba(250, 180, 20, 0.7)') or { panic(err) }
	radial.add_color_stop(1, 'rgb(90, 20, 140)') or { panic(err) }
	mut conic := CanvasGradient.create_conic(0.8, 150, 80)
	conic.add_color_stop(0, 'red') or { panic(err) }
	conic.add_color_stop(0.5, 'rgba(0, 0, 255, 0.5)') or { panic(err) }
	conic.add_color_stop(1, 'red') or { panic(err) }
	gradients := [linear, radial, conic, radial]
	operations := [CompositingAndBlendingOperator.source_over, .multiply, .source_over, .color_dodge]
	mut context := cpu_raster_test_context()
	mut expected := []u8{}
	mut expected_alpha_type := 0
	for i, gradient in gradients {
		stroke := i == 3
		style := FillOrStrokeStyle.from_gradient(gradient)
		if stroke {
			context.drawing_state.stroke_style = style
		} else {
			context.drawing_state.fill_style = style
		}
		context.drawing_state.transform = CanvasAffineTransform{0.98, 0.08, -0.1, 1, 3, -1}
		context.drawing_state.global_alpha = if i == 2 { 0.75 } else { 1 }
		context.drawing_state.line_width = if stroke { 9 } else { 1 }
		context.drawing_state.current_compositing_and_blending_operator = operations[i]
		cpu_raster_test_path(mut context, i % 3)
		bitmap := context.canvas_.bitmap() or { panic('missing canvas bitmap') }
		mut pixels := if i == 0 { bitmap.data.clone() } else { expected }
		alpha_type := if i == 0 { int(bitmap.alpha_type) } else { expected_alpha_type }
		state := context.drawing_state
		command := skia.Command{
			path:         canvas_skia_path(context.CanvasPath.path(), 'nonzero')
			style:        canvas_skia_style(style.to_gfx_paint_style())
			transform:    canvas_skia_transform(state.transform)
			stroke:       stroke
			cap:          int(state.line_cap)
			join:         int(state.line_join)
			composite:    int(operations[i])
			width:        f32(state.line_width)
			miter:        f32(state.miter_limit)
			global_alpha: f32(state.global_alpha)
		}
		assert skia.draw_path(mut pixels, bitmap.width, bitmap.height, bitmap.pitch, alpha_type,
			command)
		expected = pixels.clone()
		expected_alpha_type = 2
		if stroke {
			context.stroke()
		} else {
			context.fill('nonzero')
		}
		after := context.canvas_.bitmap() or { panic('missing canvas bitmap') }
		assert after.data == expected, 'gradient draw ${i} differs from Skia'
	}
	assert expected.any(it != 0 && it != 255)
}

// Pattern fills and strokes take the Skia-free rasterizer too: a
// premultiplied repeating image under source-over uses Skia's legacy bitmap
// shader context, other patterns the raster pipeline's image shader.
fn test_pattern_canvas_draws_match_skia() {
	mut pixels := []u8{len: 6 * 4 * 4}
	for i in 0 .. 24 {
		a := if i % 5 == 0 { 0 } else { (i * 41 + 30) % 256 }
		for c in 0 .. 3 {
			pixels[i * 4 + c] = u8(((i * 23 + c * 70) % 256) * a / 255)
		}
		pixels[i * 4 + 3] = u8(a)
	}
	mut premultiplied := ImageBitmap.create()
	premultiplied.set_bitmap(&dom.Bitmap_{
		width:      6
		height:     4
		pitch:      24
		alpha_type: 2
		data:       pixels
	})
	mut unpremultiplied := ImageBitmap.create()
	unpremultiplied.set_bitmap(&dom.Bitmap_{
		width:      6
		height:     4
		pitch:      24
		alpha_type: 1
		data:       pixels.map(if it == 0 { u8(90) } else { it })
	})
	sources := [premultiplied, unpremultiplied, premultiplied]
	repetitions := ['repeat', 'no-repeat', 'repeat-y']
	operations := [CompositingAndBlendingOperator.source_over, .source_over, .multiply]
	mut context := cpu_raster_test_context()
	mut expected := []u8{}
	mut expected_alpha_type := 0
	for i, source in sources {
		result := CanvasPattern.create(CanvasImageSource(ImageBitmapCanvasSource{ value: source }),
			repetitions[i]) or { panic(err) }
		mut pattern := result.pattern or { panic('missing pattern') }
		mut transform := geometry.DOMMatrix2DInit{
			a: 2.5
			b: 0.3
			c: -0.2
			d: 1.8
			e: 7
			f: 3
		}
		pattern.set_transform(mut transform) or { panic(err) }
		stroke := i == 2
		style := FillOrStrokeStyle.from_pattern(pattern)
		if stroke {
			context.drawing_state.stroke_style = style
		} else {
			context.drawing_state.fill_style = style
		}
		context.drawing_state.transform = CanvasAffineTransform{0.98, 0.08, -0.1, 1, 3, -1}
		context.drawing_state.global_alpha = if i == 1 { 0.75 } else { 1 }
		context.drawing_state.line_width = if stroke { 9 } else { 1 }
		context.drawing_state.current_compositing_and_blending_operator = operations[i]
		cpu_raster_test_path(mut context, i)
		bitmap := context.canvas_.bitmap() or { panic('missing canvas bitmap') }
		mut target := if i == 0 { bitmap.data.clone() } else { expected }
		alpha_type := if i == 0 { int(bitmap.alpha_type) } else { expected_alpha_type }
		state := context.drawing_state
		command := skia.Command{
			path:         canvas_skia_path(context.CanvasPath.path(), 'nonzero')
			style:        canvas_skia_style(style.to_gfx_paint_style())
			transform:    canvas_skia_transform(state.transform)
			stroke:       stroke
			cap:          int(state.line_cap)
			join:         int(state.line_join)
			composite:    int(operations[i])
			width:        f32(state.line_width)
			miter:        f32(state.miter_limit)
			global_alpha: f32(state.global_alpha)
		}
		assert skia.draw_path(mut target, bitmap.width, bitmap.height, bitmap.pitch, alpha_type,
			command)
		expected = target.clone()
		expected_alpha_type = 2
		if stroke {
			context.stroke()
		} else {
			context.fill('nonzero')
		}
		after := context.canvas_.bitmap() or { panic('missing canvas bitmap') }
		assert after.data == expected, 'pattern draw ${i} differs from Skia'
	}
	assert expected.any(it != 0 && it != 255)
}

// clearRect() and unfiltered drawImage() take the Skia-free rasterizer:
// legacy, pipeline and sprite image draws and a clear must match Skia's
// drawImageRect() and clear().
fn test_bitmap_commands_match_skia() {
	mut pixels := []u8{len: 6 * 4 * 4}
	for i in 0 .. 24 {
		a := if i % 5 == 0 { 0 } else { (i * 41 + 30) % 256 }
		for c in 0 .. 3 {
			pixels[i * 4 + c] = u8(((i * 23 + c * 70) % 256) * a / 255)
		}
		pixels[i * 4 + 3] = u8(a)
	}
	premultiplied := &dom.Bitmap_{
		width:      6
		height:     4
		pitch:      24
		alpha_type: 2
		data:       pixels
	}
	unpremultiplied := &dom.Bitmap_{
		width:      6
		height:     4
		pitch:      24
		alpha_type: 1
		data:       pixels.map(if it == 0 { u8(90) } else { it })
	}
	mut sources := []&ImageBitmap{}
	for bitmap in [premultiplied, unpremultiplied, premultiplied] {
		mut image := ImageBitmap.create()
		image.set_bitmap(bitmap)
		sources << image
	}
	destinations := [[f64(20.5), 10, 60, 40], [f64(100), 30, 6, 4], [f64(150), 70, 6, 4]]
	transforms := [CanvasAffineTransform{1.2, 0, 0, 0.9, 3, -1}, CanvasAffineTransform{},
		CanvasAffineTransform{}]
	operations := [CompositingAndBlendingOperator.source_over, .multiply, .source_over]
	mut context := cpu_raster_test_context()
	mut expected := []u8{}
	mut expected_alpha_type := 0
	for i in 0 .. 4 {
		bitmap := context.canvas_.bitmap() or { panic('missing canvas bitmap') }
		mut target := if i == 0 { bitmap.data.clone() } else { expected }
		alpha_type := if i == 0 { int(bitmap.alpha_type) } else { expected_alpha_type }
		context.drawing_state.transform = if i < 3 {
			transforms[i]
		} else {
			CanvasAffineTransform{
				e: 4
				f: -2
			}
		}
		context.drawing_state.global_alpha = if i == 1 { 0.6 } else { 1 }
		context.drawing_state.image_smoothing_enabled = i == 0
		context.drawing_state.current_compositing_and_blending_operator = if i < 3 {
			operations[i]
		} else {
			.source_over
		}
		state := context.drawing_state
		mut style := skia.Style{}
		mut destination := [f32(40), 20, 50, 30]!
		if i < 3 {
			source := sources[i].bitmap() or { panic('missing image bitmap') }
			d := destinations[i]
			destination = [f32(d[0]), f32(d[1]), f32(d[2]), f32(d[3])]!
			style = skia.Style{
				kind:           4
				pattern:        source.data.clone()
				pattern_width:  6
				pattern_height: 4
				pattern_pitch:  24
				pattern_alpha:  int(source.alpha_type)
			}
		}
		command := skia.Command{
			operation:    if i < 3 { 2 } else { 1 }
			destination:  destination
			source:       [f32(0), 0, 6, 4]!
			smoothing:    state.image_smoothing_enabled
			style:        style
			transform:    canvas_skia_transform(state.transform)
			composite:    int(state.current_compositing_and_blending_operator)
			global_alpha: f32(state.global_alpha)
		}
		assert skia.draw_path(mut target, bitmap.width, bitmap.height, bitmap.pitch, alpha_type,
			command)
		expected = target.clone()
		expected_alpha_type = 2
		if i < 3 {
			d := destinations[i]
			context.draw_image_internal(CanvasDrawImageRequest{
				image:              ImageBitmapCanvasSource{
					value: sources[i]
				}
				source_width:       6
				source_height:      4
				destination_x:      d[0]
				destination_y:      d[1]
				destination_width:  d[2]
				destination_height: d[3]
			}) or { panic(err) }
		} else {
			context.clear_rect(40, 20, 50, 30)
		}
		after := context.canvas_.bitmap() or { panic('missing canvas bitmap') }
		assert after.data == expected, 'bitmap command ${i} differs from Skia'
	}
	assert expected.any(it != 0 && it != 255)
}

// fillText() runs without filters take the Skia-free glyph masks: solid
// text, a rotated translucent color and a gradient under multiply must
// match skia.draw_glyph_run() for the same glyph run.
fn test_canvas_text_matches_skia() {
	$if !macos {
		return
	}
	mut linear := CanvasGradient.create_linear(20, 10, 260, 130)
	linear.add_color_stop(0, 'rgb(220, 40, 60)') or { panic(err) }
	linear.add_color_stop(1, 'rgb(20, 60, 230)') or { panic(err) }
	styles := [FillOrStrokeStyle.from_color(dom.Color{
		a: 255
	}), FillOrStrokeStyle.from_color(dom.Color{
		r: 30
		g: 120
		b: 220
		a: 190
	}), FillOrStrokeStyle.from_gradient(linear)]
	transforms := [CanvasAffineTransform{1, 0, 0, 1, 0, 0}, CanvasAffineTransform{0.9, 0.35, -0.35, 0.9, 30, -10},
		CanvasAffineTransform{1.3, 0, 0.2, 1.1, 0, 0}]
	operations := [CompositingAndBlendingOperator.source_over, .source_over, .multiply]
	mut context := cpu_raster_test_context()
	context.set_font('17px sans-serif')
	mut expected := []u8{}
	mut expected_alpha_type := 0
	for i, style in styles {
		context.drawing_state.fill_style = style
		context.drawing_state.transform = transforms[i]
		context.drawing_state.global_alpha = if i == 1 { 0.8 } else { 1 }
		context.drawing_state.current_compositing_and_blending_operator = operations[i]
		text := 'Glyph run ${i}: fillText'
		x := 10.25 + f64(i) * 3.5
		y := 40.5 + f64(i) * 30
		bitmap := context.canvas_.bitmap() or { panic('missing canvas bitmap') }
		mut pixels := if i == 0 { bitmap.data.clone() } else { expected }
		alpha_type := if i == 0 { int(bitmap.alpha_type) } else { expected_alpha_type }
		run := canvas_text_run_for_canvas_state(&context.CanvasState, text, 0)
		translation := canvas_text_transform(context.drawing_state, run.font(), f64(run.width()),
			none).map(FloatPoint{x, y})
		state := context.drawing_state
		font_path := run.font().font_path() or { panic('missing font path') }
		command := skia.Command{
			style:        canvas_skia_style(style.to_gfx_paint_style())
			transform:    canvas_skia_transform(state.transform)
			composite:    int(operations[i])
			global_alpha: f32(state.global_alpha)
		}
		glyphs := skia.GlyphRun{
			font_path:   font_path
			face_index:  run.font().face_index()
			font_size:   run.font().point_size
			glyphs:      run.glyph_indices()
			positions:   run.glyph_positions().map(f32(it))
			translation: [f32(translation.x), f32(translation.y)]!
		}
		assert skia.draw_glyph_run(mut pixels, bitmap.width, bitmap.height, bitmap.pitch,
			alpha_type, command, glyphs)
		expected = pixels.clone()
		expected_alpha_type = 2
		context.fill_text(text, x, y, none)
		after := context.canvas_.bitmap() or { panic('missing canvas bitmap') }
		assert after.data == expected, 'glyph run ${i} differs from Skia'
	}
	assert expected.any(it != 0 && it != 255)
}

// Filter lists of CSS color functions become the paint's color filter:
// fills, strokes and text through cpuraster must match skia.draw_path()
// and skia.draw_glyph_run() with the same filters.
fn test_color_filtered_canvas_draws_match_skia() {
	mut context := cpu_raster_test_context()
	context.set_font('19px sans-serif')
	filters := ['grayscale(40%) contrast(180%)', 'sepia(70%) hue-rotate(50deg)',
		'brightness(160%) opacity(60%)', 'invert(80%) saturate(30%)']
	mut expected := []u8{}
	mut expected_alpha_type := 0
	for i, filter in filters {
		context.set_filter(filter)
		context.drawing_state.fill_style = FillOrStrokeStyle.from_color(dom.Color{
			r: 40 + u8(i * 50)
			g: 160
			b: 220 - u8(i * 40)
			a: 230
		})
		context.drawing_state.stroke_style = context.drawing_state.fill_style
		context.drawing_state.transform = CanvasAffineTransform{0.98, 0.08, -0.1, 1, 3, -1}
		context.drawing_state.global_alpha = if i == 2 { 0.75 } else { 1 }
		context.drawing_state.line_width = if i == 1 { 7 } else { 1 }
		bitmap := context.canvas_.bitmap() or { panic('missing canvas bitmap') }
		mut pixels := if i == 0 { bitmap.data.clone() } else { expected }
		alpha_type := if i == 0 { int(bitmap.alpha_type) } else { expected_alpha_type }
		state := context.drawing_state
		skia_filters := context.canvas_skia_filters()
		assert skia_filters.len == 2
		if i == 3 {
			text := 'Filtered text ${i}'
			run := canvas_text_run_for_canvas_state(&context.CanvasState, text, 0)
			translation := canvas_text_transform(context.drawing_state, run.font(), f64(run.width()),
				none).map(FloatPoint{20.5, 120.25})
			command := skia.Command{
				style:        canvas_skia_style(state.fill_style.to_gfx_paint_style())
				transform:    canvas_skia_transform(state.transform)
				global_alpha: f32(state.global_alpha)
				filters:      skia_filters
			}
			glyphs := skia.GlyphRun{
				font_path:   run.font().font_path() or { panic('missing font path') }
				face_index:  run.font().face_index()
				font_size:   run.font().point_size
				glyphs:      run.glyph_indices()
				positions:   run.glyph_positions().map(f32(it))
				translation: [f32(translation.x), f32(translation.y)]!
			}
			assert skia.draw_glyph_run(mut pixels, bitmap.width, bitmap.height, bitmap.pitch,
				alpha_type, command, glyphs)
			expected = pixels.clone()
			context.fill_text(text, 20.5, 120.25, none)
		} else {
			stroke := i == 1
			cpu_raster_test_path(mut context, i % 3)
			command := skia.Command{
				path:         canvas_skia_path(context.CanvasPath.path(), 'nonzero')
				style:        canvas_skia_style(state.fill_style.to_gfx_paint_style())
				transform:    canvas_skia_transform(state.transform)
				stroke:       stroke
				cap:          int(state.line_cap)
				join:         int(state.line_join)
				width:        f32(state.line_width)
				miter:        f32(state.miter_limit)
				global_alpha: f32(state.global_alpha)
				filters:      skia_filters
			}
			assert skia.draw_path(mut pixels, bitmap.width, bitmap.height, bitmap.pitch, alpha_type,
				command)
			expected = pixels.clone()
			if stroke {
				context.stroke()
			} else {
				context.fill('nonzero')
			}
		}
		expected_alpha_type = 2
		after := context.canvas_.bitmap() or { panic('missing canvas bitmap') }
		assert after.data == expected, 'filtered draw ${i} differs from Skia'
	}
	assert expected.any(it != 0 && it != 255)
}

// A lone blur() draws through cpuraster's image filter layer: a scaled
// fill, a stroke and text must match Skia with the same filter.
fn test_blur_filtered_canvas_draws_match_skia() {
	check_filtered_canvas_draws_match_skia(['blur(3px)', 'blur(1.2px)', 'blur(6px)'])
}

fn test_drop_shadow_filtered_canvas_draws_match_skia() {
	check_filtered_canvas_draws_match_skia(['drop-shadow(5px 10px 3px #80402080)',
		'drop-shadow(-10px 10px 1.2px blue)', 'drop-shadow(5px -10px 6px #10203090)'])
}

fn check_filtered_canvas_draws_match_skia(filters []string) {
	mut context := cpu_raster_test_context()
	context.set_font('21px sans-serif')
	mut expected := []u8{}
	mut expected_alpha_type := 0
	for i, filter in filters {
		context.set_filter(filter)
		context.drawing_state.fill_style = FillOrStrokeStyle.from_color(dom.Color{
			r: 200 - u8(i * 60)
			g: 60 + u8(i * 50)
			b: 120
			a: 220
		})
		context.drawing_state.stroke_style = context.drawing_state.fill_style
		context.drawing_state.transform = if filter.starts_with('drop-shadow') {
			CanvasAffineTransform{1, 0, 0, 1, 4, 2}
		} else {
			CanvasAffineTransform{1.2, 0, 0, 0.9, 4, 2}
		}
		context.drawing_state.line_width = 5
		bitmap := context.canvas_.bitmap() or { panic('missing canvas bitmap') }
		mut pixels := if i == 0 { bitmap.data.clone() } else { expected }
		alpha_type := if i == 0 { int(bitmap.alpha_type) } else { expected_alpha_type }
		state := context.drawing_state
		skia_filters := context.canvas_skia_filters()
		assert skia_filters.len == 1
		supported, cpu_filter := canvas_cpu_filter(skia_filters)
		assert supported
		assert cpu_filter != none
		if i == 2 {
			text := 'Blurred text'
			run := canvas_text_run_for_canvas_state(&context.CanvasState, text, 0)
			translation := canvas_text_transform(context.drawing_state, run.font(), f64(run.width()),
				none).map(FloatPoint{30.5, 110.25})
			command := skia.Command{
				style:        canvas_skia_style(state.fill_style.to_gfx_paint_style())
				transform:    canvas_skia_transform(state.transform)
				global_alpha: f32(state.global_alpha)
				filters:      skia_filters
			}
			glyphs := skia.GlyphRun{
				font_path:   run.font().font_path() or { panic('missing font path') }
				face_index:  run.font().face_index()
				font_size:   run.font().point_size
				glyphs:      run.glyph_indices()
				positions:   run.glyph_positions().map(f32(it))
				translation: [f32(translation.x), f32(translation.y)]!
			}
			assert skia.draw_glyph_run(mut pixels, bitmap.width, bitmap.height, bitmap.pitch,
				alpha_type, command, glyphs)
			expected = pixels.clone()
			context.fill_text(text, 30.5, 110.25, none)
		} else {
			stroke := i == 1
			cpu_raster_test_path(mut context, i)
			command := skia.Command{
				path:         canvas_skia_path(context.CanvasPath.path(), 'nonzero')
				style:        canvas_skia_style(state.fill_style.to_gfx_paint_style())
				transform:    canvas_skia_transform(state.transform)
				stroke:       stroke
				cap:          int(state.line_cap)
				join:         int(state.line_join)
				width:        f32(state.line_width)
				miter:        f32(state.miter_limit)
				global_alpha: f32(state.global_alpha)
				filters:      skia_filters
			}
			assert skia.draw_path(mut pixels, bitmap.width, bitmap.height, bitmap.pitch, alpha_type,
				command)
			expected = pixels.clone()
			if stroke {
				context.stroke()
			} else {
				context.fill('nonzero')
			}
		}
		expected_alpha_type = 2
		after := context.canvas_.bitmap() or { panic('missing canvas bitmap') }
		assert after.data == expected, '${filter} draw ${i} differs from Skia'
	}
	assert expected.any(it != 0 && it != 255)
}
