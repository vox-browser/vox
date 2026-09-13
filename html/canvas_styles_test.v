module html

import dom
import geometry

fn test_canvas_fill_and_stroke_styles() {
	mut state := &CanvasState{}
	mut styles := CanvasFillStrokeStyles.create(state)
	styles.set_fill_style(CanvasFillStrokeStyleValue('#123456'))
	assert state.drawing_state.fill_style.color == dom.Color{
		r: 0x12
		g: 0x34
		b: 0x56
		a: 255
	}
	styles.set_fill_style(CanvasFillStrokeStyleValue('not a color'))
	assert state.drawing_state.fill_style.color.r == 0x12

	gradient := styles.create_linear_gradient(1, 2, 3, 4)
	styles.set_stroke_style(CanvasFillStrokeStyleValue(gradient))
	assert state.drawing_state.stroke_style.kind == .gradient
	assert (state.drawing_state.stroke_style.gradient or { panic('missing gradient') }).x1 == 3
}

fn test_canvas_pattern_creation_and_transform() {
	mut image := ImageBitmap.create()
	image.set_bitmap(&dom.ImmutableBitmap_{ width: 3, height: 4, data: [u8(1)] })
	result := CanvasPattern.create(CanvasImageSource(ImageBitmapCanvasSource{ value: image }), '') or {
		panic(err)
	}
	mut pattern := result.pattern or { panic('missing pattern') }
	assert pattern.repetition() == .repeat
	assert pattern.bitmap().width == 3
	assert pattern.frame().bitmap() == pattern.bitmap()
	assert pattern.frame().color_space() == .srgb
	mut transform := geometry.DOMMatrix2DInit{
		a: 2
		d: 3
		e: 4
		f: 5
	}
	pattern.set_transform(mut transform) or { panic(err) }
	assert pattern.transform() == CanvasAffineTransform{
		a: 2
		d: 3
		e: 4
		f: 5
	}

	CanvasPattern.create(CanvasImageSource(ImageBitmapCanvasSource{ value: image }), 'invalid') or {
		assert err.msg().contains('SyntaxError')
		image.close()
		bad := CanvasPattern.create(CanvasImageSource(ImageBitmapCanvasSource{ value: image }),
			'repeat') or { panic(err) }
		assert bad.pattern == none
		return
	}
	assert false
}

fn test_canvas_pattern_retains_decoded_frame_color_space() {
	bitmap := &dom.ImmutableBitmap_{ width: 2, height: 1 }
	frame := dom.DecodedImageFrame_.create_with_color_space(bitmap, .display_p3)
	data := BitmapDecodedImageData.create([
		BitmapDecodedImageFrame{ frame: frame },
	], 0, false)
	result := CanvasPattern.create(CanvasImageSource(DecodedImageCanvasSource{
		value: data
	}), 'no-repeat') or { panic(err) }
	pattern := result.pattern or { panic('missing pattern') }
	assert pattern.frame() == frame
	assert pattern.frame().color_space() == .display_p3
}

fn test_canvas_text_drawing_styles_validate_and_store_values() {
	mut state := &CanvasState{}
	mut styles := CanvasTextDrawingStyles.create(state)
	assert styles.font() == '10px sans-serif'
	styles.set_font('italic 700 12px serif')
	assert styles.font() == 'italic 700 12px serif'
	styles.set_font('inherit')
	assert styles.font() == 'italic 700 12px serif'
	styles.set_text_align(.center)
	styles.set_text_baseline(.middle)
	styles.set_direction(.rtl)
	assert styles.text_align() == .center
	assert styles.text_baseline() == .middle
	assert styles.direction() == .rtl
	styles.set_letter_spacing('2.5px')
	assert styles.letter_spacing() == '2.5px'
	assert state.drawing_state.letter_spacing_px == 2.5
	styles.set_letter_spacing('normal')
	assert styles.letter_spacing() == '2.5px'
}
