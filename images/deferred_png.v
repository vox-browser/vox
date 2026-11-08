module main

import dom
import os
import platform

const disable_deferred_png_decode = os.getenv('VOX_DISABLE_DEFERRED_PNG_DECODE') != ''

const png_signature = [u8(0x89), `P`, `N`, `G`, `\r`, `\n`, 0x1a, `\n`]
const png_iend_chunk = [u8(0), 0, 0, 0, `I`, `E`, `N`, `D`, 0xae, 0x42, 0x60, 0x82]

fn png_u32_at(bytes []u8, offset int) u32 {
	return (u32(bytes[offset]) << 24) | (u32(bytes[offset + 1]) << 16) | (u32(bytes[offset + 2]) << 8) | u32(bytes[offset + 3])
}

// The natural size of a complete PNG stream from its IHDR chunk: the header
// stb accepts, followed by the stream's final IEND chunk. A truncated or
// otherwise unrecognised stream returns none and is decoded immediately.
fn png_stream_natural_size(bytes []u8) ?(int, int) {
	if bytes.len < png_signature.len + 25 + png_iend_chunk.len {
		return none
	}
	if bytes[..8] != png_signature || png_u32_at(bytes, 8) != 13 || bytes[12..16] != 'IHDR'.bytes() {
		return none
	}
	width := png_u32_at(bytes, 16)
	height := png_u32_at(bytes, 20)
	depth := bytes[24]
	valid_format := match bytes[25] {
		0 { depth in [u8(1), 2, 4, 8, 16] }
		2, 4, 6 { depth in [u8(8), 16] }
		3 { depth in [u8(1), 2, 4, 8] }
		else { false }
	}
	if !valid_format || bytes[26] != 0 || bytes[27] != 0 || bytes[28] > 1 {
		return none
	}
	// stb's dimension limit, and a pixel count whose RGBA size fits an int.
	if width == 0 || height == 0 || width > 1 << 24 || height > 1 << 24
		|| u64(width) * u64(height) > u64(1) << 28 {
		return none
	}
	if bytes[bytes.len - png_iend_chunk.len..] != png_iend_chunk {
		return none
	}
	return int(width), int(height)
}

// A PNG response's bitmap with its natural size and replay flags, whose pixels
// stb decodes on first use. Most of a page's images are laid out and recorded
// but never drawn before the next navigation (README screenshots far below the
// viewport, hidden menu previews), and a drawn one decodes the same pixels.
fn browser_deferred_png_bitmap(bytes []u8) ?&dom.Bitmap_ {
	if disable_deferred_png_decode {
		return none
	}
	width, height := png_stream_natural_size(bytes) or { return none }
	// The pixels belong to the owner of this response's decoded image data,
	// as they would have if decoded now, not to whichever scratch or frame
	// workspace is entered when they are first drawn.
	storage := platform.current_retained_arena()
	encoded := bytes.clone()
	mut bitmap := dom.Bitmap_.create_deferred(width, height, fn [encoded, storage] (mut target dom.Bitmap_) {
		mut owner := storage
		persistent := platform.enter_persistent_if(owner == unsafe { nil })
		defer { platform.leave_persistent(persistent) }
		mut allocations := if owner != unsafe { nil } {
			owner.enter_nested()
		} else {
			platform.RetainedArenaScope{}
		}
		defer { allocations.finish() }
		size := target.pitch * target.height
		if decoded := browser_decode_stb_raster_bytes(encoded) {
			if decoded.width == target.width && decoded.height == target.height
				&& decoded.data.len == size {
				target.data = decoded.data
			}
		}
		// A stream that fails after a valid header keeps its natural size and
		// paints transparent pixels, as a partially decoded image would.
		if target.data.len != size {
			target.data = []u8{len: size}
		}
		$if macos {
			if target.native_resource_replay_compatible {
				// An arena can reuse an address that previously held tagged pixels.
				C.native_tag_image_color_profile(target.data.data, target.width, target.height,
					encoded.data, uint(encoded.len), 0)
			}
		}
	})
	bitmap.native_rows_are_top_down = true
	bitmap.native_resource_replay_compatible = browser_raster_can_share_native_pixels(bytes)
	return bitmap
}
