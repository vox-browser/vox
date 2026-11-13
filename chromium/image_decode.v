module main

import crypto.sha256

// Keep large data URLs eligible for the same decode history as ordinary URLs.
// Separate the two namespaces so a literal URL cannot impersonate a digest.
fn chromium_image_decode_resource_identity(url string) string {
	if url.len == 0 || url.len > 128 * 1024 * 1024 { return '' }
	if url.len <= 16380 { return 'url:${url}' }
	return 'sha256:${sha256.hexhash(url)}'
}

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
		for index in 0 .. app.paint_commands.len {
			command := unsafe { &app.paint_commands[index] }
			if command.kind != 'draw_replaced_image' { continue }
			image := command.image()
			mode := chromium_paint_image_decoding_hint(app.document, command)
			if mode < 0 { continue }
			identity := chromium_image_decode_resource_identity(image.image_url)
			if identity.len == 0 { continue }
			C.native_add_image_decoding_hint(identity.str, i32(identity.len), i32(mode))
		}
	}
}

fn set_chromium_image_decode_scope(scope int) {
	$if macos {
		mut state := unsafe { png_decode_scope }
		state.scope = scope
		C.native_set_image_decode_scope(u64(scope))
	}
}

fn (app &BrowserApp) set_chromium_image_resource_identity(url string) {
	$if macos {
		identity := chromium_image_decode_resource_identity(url)
		if app.document != unsafe { nil } && app.document.font_rendering_policy() == .chromium
			&& identity.len > 0 {
			C.native_set_image_resource_identity(identity.str, i32(identity.len))
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
