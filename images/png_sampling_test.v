module main

import gg
import dom
import html
import layout
import os
import stbi

fn test_poster_resource_lookup_rejects_retained_pixels_after_a_poster_change() {
	$if macos {
		mut document := html.parse_document('<!doctype html><video id="v"></video>')
		defer { document.finalize() }
		mut element := document.get_element_by_id('v') or { panic('video') }
		mut model := html.html_video_element_model_for_dom_element(unsafe { &dom.HTMLVideoElement(element) })
		model.set_poster_fetch_hook(fn (_ dom.URL) !&dom.Bitmap_ {
			return &dom.Bitmap_{ width: 2, height: 2, pitch: 8, data: [u8(0), 0, 255, 255].repeat(4) }
		})
		element.set_attribute_value('poster', 'https://poster.example/current.png')
		_ = layout.layout_document_typed_in_viewport(document, 240, 160)
		list := document.record_display_list() or { panic('display list') }
		commands := layout.display_list_commands(list).filter(it.kind == 'draw_video')
		assert commands.len == 1
		assert layout.video_poster_resource_url(document, &commands[0])? == 'https://poster.example/current.png'
		element.set_attribute_value('poster', 'https://poster.example/replaced.png')
		assert layout.video_poster_resource_url(document, &commands[0]) == none
	}
}

fn test_png_decode_history_keeps_resource_and_compositor_scope_identity() {
	$if macos {
		mut document := html.parse_document('<!doctype html>')
		defer { document.finalize() }
		document.set_font_rendering_policy(.chromium)
		mut app := BrowserApp{ document: document, ctx: gg.new_context(native_rendering: true) }
		path := os.join_path(@VMODROOT, 'Tests/Browser/Brave/resources/image-decode-cold.png')
		bytes := os.read_bytes(path) or { panic('${err}') }
		decoded := stbi.load_from_memory(bytes.data, bytes.len, desired_channels: 4) or { panic('${err}') }
		defer { decoded.free() }
		image := &gg.Image{ width: decoded.width, height: decoded.height, nr_channels: 6, data: decoded.data, ok: true }
		previous := png_decode_scope.scope
		defer { set_chromium_image_decode_scope(previous) }
		set_chromium_image_decode_scope(0)
		first := app.sampled_png_decode(path, image, 60, 60) or { panic('first decode') }
		assert first.width == 63 && first.height == 63
		assert (app.sampled_png_decode(path, image, 32, 32) or { panic('reuse') }).id == first.id
		other := os.join_path(@VMODROOT, 'Tests/Browser/Brave/resources/image-decode-separate.png')
		separate := app.sampled_png_decode(other, image, 32, 32) or { panic('separate resource') }
		assert separate.width == 32 && separate.id != first.id
		set_chromium_image_decode_scope(1)
		layer := app.sampled_png_decode(path, image, 32, 32) or { panic('separate compositor') }
		assert layer.width == 32 && layer.id != first.id
		assert !png_sampling_bytes_supported(bytes[..32])
		// Color-managed and animated inputs must retain the existing renderer.
		for kind in ['iCCP', 'gAMA', 'cHRM', 'cICP', 'acTL'] {
			mut tagged := bytes[..33].clone()
			tagged << [u8(0), 0, 0, 0]
			tagged << kind.bytes()
			tagged << [u8(0), 0, 0, 0]
			tagged << bytes[33..]
			assert !png_sampling_bytes_supported(tagged)
		}
	}
}
