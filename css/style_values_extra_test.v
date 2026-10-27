module css

import dom

struct StyleValueTestDecodedImageData {
	bitmap_ &dom.Bitmap_
}

fn (data &StyleValueTestDecodedImageData) frame(_ uint) ?&dom.DecodedImageFrame_ {
	return dom.DecodedImageFrame_.create(data.bitmap_)
}

fn (_ &StyleValueTestDecodedImageData) frame_duration(_ uint) int {
	return 0
}

fn (_ &StyleValueTestDecodedImageData) frame_count() uint {
	return 1
}

fn (_ &StyleValueTestDecodedImageData) loop_count() uint {
	return 0
}

fn (_ &StyleValueTestDecodedImageData) is_animated() bool {
	return false
}

fn (data &StyleValueTestDecodedImageData) intrinsic_width() ?f64 {
	return f64(data.bitmap_.width)
}

fn (data &StyleValueTestDecodedImageData) intrinsic_height() ?f64 {
	return f64(data.bitmap_.height)
}

fn (data &StyleValueTestDecodedImageData) intrinsic_aspect_ratio() ?f64 {
	if data.bitmap_.height == 0 {
		return none
	}
	return f64(data.bitmap_.width) / f64(data.bitmap_.height)
}

fn test_basic_shape_inset_builds_upstream_rounded_path_geometry() {
	value := parse_css_value_logic(.clip_path, 'inset(0 round 60px)') or {
		assert false, 'failed to parse rounded inset'
		return
	}
	shape := match value {
		BasicShapeStyleValue { value }
		else {
			assert false, 'expected BasicShapeStyleValue'
			return
		}
	}
	node := &dom.LayoutNode{}
	path := shape.to_path(CSSPixelRect.new(0, 0, 100, 40), node)

	// 60px radii overflow the 100x40 box and normalize to 20px. The
	// translated path has the same move/line/four-arc/close sequence as C++.
	assert path.commands.len == 10
	assert path.commands[0].type_ == .move_to
	assert path.commands[0].point.x().to_double() == 20
	assert path.commands[0].point.y().to_double() == 0
	assert path.commands[2].type_ == .elliptical_arc_to
	assert path.commands[2].radii.width().to_double() == 20
	assert path.commands[2].radii.height().to_double() == 20
	assert path.commands[2].sweep
	assert path.commands[9].type_ == .close
}

fn test_cursor_retains_typed_image_and_uses_default_sizing_algorithm() {
	bitmap := &dom.Bitmap_{
		width: 10
		height: 20
		data: []u8{len: 10 * 20 * 4}
	}
	decoded := &StyleValueTestDecodedImageData{bitmap_: bitmap}
	mut image := ImageStyleValue.create_from_url_string('cursor.png')
	image.set_image_data(decoded)
	mut cursor := CursorStyleValue.create(CursorImageValue.create(CSSImageSourceStyleValue(image)),
		StyleValue(NumberStyleValue.create(4)), StyleValue(NumberStyleValue.create(7)))

	result := cursor.make_image_cursor(&dom.LayoutNode{}) or {
		assert false, 'paintable typed image should create a cursor description'
		return
	}
	assert result.size.width().to_double() == 10
	assert result.size.height().to_double() == 20
	assert result.hotspot_x == 4
	assert result.hotspot_y == 7
	assert result.image is ImageStyleValue
	assert cursor.serialize(.normal) == 'url("cursor.png") 4 7'
}

fn test_image_style_value_reads_single_pixel_from_real_decoded_image_contract() {
	bitmap := &dom.Bitmap_{
		width: 1
		height: 1
		data: [u8(12), 34, 56, 78]
	}
	mut image := ImageStyleValue.create_from_url_string('pixel.png')
	image.set_image_data(&StyleValueTestDecodedImageData{bitmap_: bitmap})
	assert image.natural_width()?.to_double() == 1
	assert image.natural_height()?.to_double() == 1
	assert image.color_if_single_pixel_bitmap()? == Color.rgba(12, 34, 56, 78)
}

@[heap]
struct ImageStyleValueClientRecorder {
mut:
	updates int
}

fn record_image_style_value_update(target voidptr) {
	mut recorder := unsafe { &ImageStyleValueClientRecorder(target) }
	recorder.updates++
}

fn test_image_style_value_copies_share_const_client_registration() {
	image := ImageStyleValue.create_from_url_string('shared.png')
	copy := image
	mut recorder := &ImageStyleValueClientRecorder{}
	image.register_client(ImageStyleValueClient{
		target: voidptr(recorder)
		did_update: record_image_style_value_update
	})

	copy.notify_clients()
	assert recorder.updates == 1
	copy.unregister_client(voidptr(recorder))
	image.notify_clients()
	assert recorder.updates == 1
}

fn test_css_image_reads_decoded_data_from_shared_resource_request() {
	bitmap := &dom.Bitmap_{
		width: 3
		height: 5
		data: []u8{len: 3 * 5 * 4}
	}
	decoded := &StyleValueTestDecodedImageData{bitmap_: bitmap}
	mut document := dom.Document{}
	mut image := ImageStyleValue.create_from_url_string('https://example.test/image.png')
	mut recorder := &ImageStyleValueClientRecorder{}
	image.register_client(ImageStyleValueClient{
		target: voidptr(recorder)
		did_update: record_image_style_value_update
	})
	image.load_any_resources(mut document)
	request := image.resource_request_ or {
		assert false, 'CSS image should create a shared resource request'
		return
	}
	mut mutable_request := unsafe { &dom.SharedResourceRequest(request) }
	mutable_request.handle_successful_resource_load(decoded)

	assert image.is_paintable()
	assert image.natural_width()?.to_double() == 3
	assert image.natural_height()?.to_double() == 5
	assert recorder.updates == 1
}

fn test_color_function_uses_color_resolution_calculation_context() {
	channel := parse_css_value_logic(.opacity, 'calc(1em / 32px)') or {
		panic('failed to parse calculated color channel')
	}
	zero := StyleValue(NumberStyleValue.create(0))
	one := StyleValue(NumberStyleValue.create(1))
	color_function := ColorFunctionStyleValue.create('srgb', channel, zero, zero, one)
	metrics := LengthFontMetrics.default()
	color := color_function.to_color(ColorResolutionContext{
		calculation_resolution_context: CalculationResolutionContext{
			length_resolution_context: LengthResolutionContext{
				font_metrics: metrics
				root_font_metrics: metrics
			}
		}
	}) or { panic('calculated color channel did not resolve') }

	// 1em / 32px at the default 16px font size is 0.5.
	assert color.red() == 128
	assert color.green() == 0
	assert color.blue() == 0
}

fn test_link_system_colors_resolve_without_a_document_palette() {
	light := ColorResolutionContext{color_scheme: PreferredColorScheme.light}
	dark := ColorResolutionContext{color_scheme: PreferredColorScheme.dark}
	assert KeywordStyleValue.create(.linktext).to_color(light)? == SystemColor.link_text(.light)
	assert KeywordStyleValue.create(.visitedtext).to_color(light)? == SystemColor.visited_text(.light)
	assert KeywordStyleValue.create(.activetext).to_color(dark)? == SystemColor.active_text(.dark)
}

// ColorStyleValue::serialize_hue_component() formats the resolved hue with AK's
// `{:.4}`, which rounds to four decimals and then drops trailing zeros.
fn test_lch_and_oklch_hues_drop_trailing_zeros() {
	assert parse_css_value(ParsingParams{}, 'lch(50% 40 30deg)', PropertyID.color)?.css_text == 'lch(50 40 30)'
	assert parse_css_value(ParsingParams{}, 'oklch(0.5 0.1 30)', PropertyID.color)?.css_text == 'oklch(0.5 0.1 30)'
	assert parse_css_value(ParsingParams{}, 'lch(50 300 30)', PropertyID.color)?.css_text == 'lch(50 300 30)'
	assert parse_css_value(ParsingParams{}, 'oklch(0.5 3 30)', PropertyID.color)?.css_text == 'oklch(0.5 3 30)'
	assert parse_css_value(ParsingParams{}, 'lch(50% 40 30.5deg)', PropertyID.color)?.css_text == 'lch(50 40 30.5)'
	assert parse_css_value(ParsingParams{}, 'lch(50% 40 12.75deg)', PropertyID.color)?.css_text == 'lch(50 40 12.75)'
	// Still rounded to four decimals, and a hue below that resolution is zero.
	assert parse_css_value(ParsingParams{}, 'lch(50% 40 30.123456deg)', PropertyID.color)?.css_text == 'lch(50 40 30.1235)'
	assert parse_css_value(ParsingParams{}, 'lch(50% 40 0.000001deg)', PropertyID.color)?.css_text == 'lch(50 40 0)'
	// Hues normalize into [0, 360) first.
	assert parse_css_value(ParsingParams{}, 'lch(50% 40 -30deg)', PropertyID.color)?.css_text == 'lch(50 40 330)'
	assert parse_css_value(ParsingParams{}, 'oklch(0.5 0.1 1turn)', PropertyID.color)?.css_text == 'oklch(0.5 0.1 0)'
}
