module layout

import css
import dom
import html
import painting
import platform

fn test_chromium_broken_image_frame_retains_device_scale_and_direction() {
	for scale in [1.0, 2.0] {
		for rtl in [false, true] {
			mut commands := []PaintCommand{}
			append_chromium_broken_image(mut commands, &painting.ImagePaintable{
				image_rect:                  painting.Rect{10 * scale, 20 * scale, 70 * scale, 40 * scale}
				broken_image_fallback_scale: scale
				broken_image_fallback_rtl:   rtl
			}, 0.5)
			assert commands.len == 2
			assert commands[0].stroke_width == scale
			assert commands[0].x == 10.5 * scale
			assert commands[0].width == 69 * scale
			assert commands[0].opacity == 0.5
			assert commands[1].x == (if rtl { 62.0 } else { 12.0 }) * scale
			assert commands[1].y == 22 * scale
			assert commands[1].width == 16 * scale
			bitmap := commands[1].replaced_image_bitmap or { panic('icon') }
			assert bitmap.width == int(14 * scale)
			assert bitmap.height == int(16 * scale)
			assert bitmap.native_rows_are_top_down
		}
	}
	mut commands := []PaintCommand{}
	append_chromium_broken_image(mut commands, &painting.ImagePaintable{
		image_rect:                  painting.Rect{0, 0, 17, 40}
		broken_image_fallback_scale: 1
	}, 1)
	assert commands.len == 0
}

fn test_only_failed_fixed_size_chromium_images_get_the_frame() {
	for chromium in [true, false] {
		address := dom.URL{ value: 'https://image.example.test/' }
		mut document := html.parse_navigation_document('<!doctype html><style>body{margin:0;font-size:0}</style><img id="image" src="https://image.example.test/fail.png" alt="" width="70" height="70">', address, address.origin(), none) or { panic(err) }
		defer { document.finalize() }
		if chromium { document.set_font_rendering_policy(.chromium) }
		document.set_layout_coordinate_scale(2)
		mut element := document.get_element_by_id('image') or { panic('image') }
		mut model := html.html_image_element_model_for_dom_element(unsafe { &dom.HTMLImageElement(element) })
		model.set_async_fetch_hook(fn (_ dom.URL, _ html.HTMLImageFetchCompletion) {})
		model.update_the_image_data(false, false)
		_ = layout_document_typed_in_viewport(document, 200, 100)
		pending := display_list_commands(document.record_display_list() or { panic('pending') })
		assert pending.filter(it.color == 'rgb(192 192 192)').len == 0
		model.set_fetch_hook(fn (_ dom.URL) !html.DecodedImageData { return error('missing image') })
		model.update_the_image_data(false, false)
		document.update_layout(.debugging)
		failed := display_list_commands(document.record_display_list() or { panic('failed') })
		assert (failed.filter(it.color == 'rgb(192 192 192)').len == 1) == chromium
		model.set_fetch_hook(fn (_ dom.URL) !html.DecodedImageData {
			return html.BitmapDecodedImageData.create([
				html.BitmapDecodedImageFrame{
					frame: dom.DecodedImageFrame_.create(&dom.Bitmap_{
						width:  1
						height: 1
						pitch:  4
						data:   [u8(255), 255, 255, 255]
					})
				},
			], 0, false)
		})
		element.set_attribute_value('src', 'https://image.example.test/recovered.png')
		html.html_image_element_form_associated_element_attribute_changed(unsafe { &dom.HTMLImageElement(element) },
			'src', 'https://image.example.test/fail.png', 'https://image.example.test/recovered.png', none)
		model.update_the_image_data(false, false)
		document.update_layout(.debugging)
		recovered := display_list_commands(document.record_display_list() or { panic('recovered') })
		assert recovered.filter(it.color == 'rgb(192 192 192)').len == 0
		assert recovered.filter(it.kind == 'draw_replaced_image').len == 1
	}
}

fn test_zero_font_thumbnail_line_does_not_add_a_descent() {
	for scale in [1.0, 2.0] {
		mut document := html.parse_document('<!doctype html><style>body{margin:0}#thumb{font:0px Arial}span{display:inline-block;width:70px;height:70px}</style><div id="thumb"><span></span></div>')
		defer { document.finalize() }
		document.set_font_rendering_policy(.chromium)
		document.set_layout_coordinate_scale(scale)
		_ = layout_document_typed_in_viewport(document, 200, 100)
		thumb := css.query_selector(document.as_node(), '#thumb') or { panic('thumb') }
		assert thumb.get_bounding_client_rect().height == 70
	}
}

fn test_chromium_broken_image_cache_outlives_the_document_arena() {
	$if !prealloc {
		return
	}
	// Force a cache miss while the native document's allocation owner is active.
	chromium_broken_image_bitmaps.delete(2)
	mut document := dom.Document.create(dom.url_about_blank())
	document.enable_native_storage()
	mut owner := document.enter_native_storage()
	bitmap := chromium_broken_image_bitmap(2) or { panic('icon') }
	assert !document.native_storage().arena.contains(voidptr(bitmap))
	assert !document.native_storage().arena.contains(bitmap.data.data)
	persistent := platform.enter_persistent()
	pixels := bitmap.data.clone()
	platform.leave_persistent(persistent)
	owner.finish()
	document.finalize()
	document.release_native_storage()
	cached := chromium_broken_image_bitmap(2) or { panic('cached icon') }
	assert voidptr(cached) == voidptr(bitmap)
	assert cached.data == pixels
}
