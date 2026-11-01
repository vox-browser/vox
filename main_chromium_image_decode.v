module main

fn C.native_set_image_resource_identity(&u8, i32)
fn C.native_add_image_decoding_hint(&u8, i32, i32)
fn C.native_begin_image_decode_frame(voidptr, u64, u64)
fn C.native_set_image_decode_scope(u64)

fn (app &BrowserApp) begin_chromium_image_decode_frame() {
	$if macos {
		C.native_begin_image_decode_frame(voidptr(app.document), app.paint_generation,
			u64(app.navigation_generation))
		if app.document == unsafe { nil } || app.document.font_rendering_policy() != .chromium { return }
		// Collect all uses before drawing: an earlier async use must see a
		// later sync use of the same resource, including another raster layer.
		for command in app.paint_commands {
			if command.kind != 'draw_replaced_image' { continue }
			image := command.image()
			mode := chromium_image_decoding_hint(app.document, image.image_element_id)
			if mode < 0 || image.image_url.len == 0 || image.image_url.len > 16384 { continue }
			C.native_add_image_decoding_hint(image.image_url.str, i32(image.image_url.len), i32(mode))
		}
	}
}

fn set_chromium_image_decode_scope(scope int) {
	$if macos {
		C.native_set_image_decode_scope(u64(scope))
	}
}

fn (app &BrowserApp) set_chromium_image_resource_identity(url string) {
	$if macos {
		if app.document != unsafe { nil } && app.document.font_rendering_policy() == .chromium
			&& url.len > 0 && url.len <= 16384 {
			C.native_set_image_resource_identity(url.str, i32(url.len))
		} else {
			C.native_set_image_resource_identity(unsafe { nil }, 0)
		}
	}
}

fn clear_chromium_image_resource_identity() {
	$if macos {
		C.native_set_image_resource_identity(unsafe { nil }, 0)
	}
}
