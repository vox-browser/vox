module main

import crypto.sha256
import gg
import imageraster
import layout
import math
import painting
import platform
import yuv
import os

fn (mut app BrowserApp) draw_minified_webp(command &layout.PaintCommand, image &gg.Image, url string,
	destination painting.IntRect, source [4]f32, clip [12]f32, matrix [6]f64,
	page_x f32, page_y f32, scroll_y f64, nearest bool) bool {
	if os.getenv('VOX_DIAGNOSTIC_PNG') != '' {
		eprintln('VOX_PLANAR_INPUT ${image.width}x${image.height} channels=${image.nr_channels} dest=${destination.x},${destination.y},${destination.width},${destination.height} source=${source} matrix=${matrix} url=${url[..math.min(url.len, 180)]}')
	}
	atlas := yuv.webp_atlas_sampling_supported(image.width, image.height,
        f64(destination.width), f64(destination.height))
	if app.document == unsafe { nil } || app.document.font_rendering_policy() != .chromium
		|| command.apply_force_dark_to_image || nearest || command.opacity != 1
		|| image.path != '' || image.nr_channels != 7 || image.data == unsafe { nil }
		|| image.width <= 0 || image.height <= 0 || image.width > 4096 || image.height > 4096
		|| image.width * image.height > 4 * 1024 * 1024 || image.width % 2 != 0 || image.height % 2 != 0
		|| matrix[0] != 1 || matrix[1] != 0 || matrix[2] != 0 || matrix[3] != 1
		|| destination.width <= 0 || destination.height <= 0
		|| (!atlas && (destination.width * 2 > image.width || destination.height * 2 > image.height))
		|| source != [f32(0), 0, f32(image.width), f32(image.height)]! {
		return false
	}
	ox, oy := page_x + f32(matrix[4]), page_y + f32(matrix[5]) - f32(scroll_y)
	if !math.is_finite(ox) || !math.is_finite(oy) || ox != math.floor(ox) || oy != math.floor(oy) {
		return false
	}
	bytes := app.background_image_bytes(url) or { return false }
	if !lossy_webp_sampling_dimensions_match(bytes, image.width, image.height) || !app.webp_complete_yuv_allowed(url, bytes) {
		return false
	}
    mut tw, mut th := image.width, image.height
    if !atlas {
        tw, th = imageraster.decode_size(image.width, image.height, destination.width, destination.height) or { return false }
    }
    // Retain the full planes for aligned atlas mips; other uploads retain
    // their existing decode reduction and single/multiple-level selection.
    use_mips := math.log2(math.max(f64(tw) / destination.width, f64(th) / destination.height)) >= .5
	if image.width % tw != 0 || image.height % th != 0 || image.width / tw != image.height / th {
		return false
	}
	digest := sha256.sum(bytes).hex()
	if os.getenv('VOX_DIAGNOSTIC_PNG') != '' {
		eprintln('VOX_PLANAR_UPLOAD ${image.width}x${image.height}->${tw}x${th} body=${digest}')
	}
	key := '\x00minified-yuv:${u64(voidptr(app.document))}:${app.navigation_generation}:${png_decode_scope.scope}:${url}:${digest}:${tw}x${th}:atlas=${atlas}'
	mut decoded := &gg.Image{}
	if id := app.background_image_ids[key] {
		previous := app.ctx.get_cached_image_by_idx(id)
		if previous.ok && previous.width == tw && previous.height == th && previous.data != unsafe { nil } {
			decoded = previous
		}
	}
	if !decoded.ok {
		mut scratch := platform.begin_thread_scratch('Minified WebP planar upload')
		mut w, mut h, mut size := 0, 0, 0
		planes := C.native_decode_webp_yuv(bytes.data, uint(bytes.len), &w, &h, &size)
		if planes == unsafe { nil } {
			scratch.finish()
			return false
		}
		packed := if w == image.width && h == image.height {
			if atlas {
                yuv.webp_420_atlas_upload(unsafe { planes.vbytes(size) }, w, h) or { []u8{} }
            } else {
                yuv.webp_minified_upload(unsafe { planes.vbytes(size) }, w, h, tw, th) or { []u8{} }
            }
		} else {
			[]u8{}
		}
		C.native_free_webp_pixels(planes)
		if packed.len == 0 {
			scratch.finish()
			return false
		}
		persistent := platform.enter_persistent()
		retained := packed.clone()
		mut result := gg.Image{ width: tw, height: th, nr_channels: 5, ok: true, data: retained.data }
		result.id = app.ctx.cache_image(result)
		app.background_image_ids[key.clone()] = result.id
		decoded = app.ctx.get_cached_image_by_idx(result.id)
		platform.leave_persistent(persistent)
		scratch.finish()
	}
	mut clipping := clip
	clipping[0] += f32(matrix[4])
	clipping[1] += f32(matrix[5])
	if os.getenv('VOX_DIAGNOSTIC_PNG') != '' {
		eprintln('VOX_PLANAR_READY ok=${decoded.ok} upload=${decoded.width}x${decoded.height} nil=${decoded.data == unsafe { nil }}')
	}
	drawn := C.native_draw_sampled_png(decoded.data, i32(tw), i32(th), i32(image.width), i32(image.height), if atlas { i32(5) } else if use_mips { i32(4) } else { i32(3) },
		f32(destination.x) + f32(matrix[4]), f32(destination.y) + f32(matrix[5]), f32(destination.width), f32(destination.height),
		&clipping[0], page_x, page_y, f32(scroll_y), f32(app.ctx.width), f32(app.ctx.height)) != 0
	if os.getenv('VOX_DIAGNOSTIC_PNG') != '' {
		eprintln('VOX_PLANAR_DRAW ${tw}x${th} painted=${drawn}')
	}
	return drawn
}
