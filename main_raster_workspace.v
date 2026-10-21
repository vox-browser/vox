module main

import dom
import platform
import stbi

// The decoder's inflate buffers and intermediate channel planes have no
// readers after the final pixel copy. Under -prealloc, image.free() alone does
// not reclaim those buffers; keep them in a synchronous workspace instead.
fn browser_decode_stb_raster_bytes(bytes []u8) !&dom.Bitmap_ {
	mut work := platform.begin_thread_scratch('raster image decode')
	image := stbi.load_from_memory(bytes.data, bytes.len) or {
		work.leave()
		message := err.msg().clone()
		work.finish()
		return error(message)
	}
	work.leave()
	defer { work.finish() }
	defer {
		image.free()
	}
	if image.width <= 0 || image.height <= 0 || image.nr_channels != 4 {
		return error('Invalid decoded image')
	}
	mut pixels := []u8{len: image.width * image.height * 4}
	unsafe {
		vmemcpy(pixels.data, image.data, pixels.len)
	}
	return &dom.Bitmap_{
		width: image.width
		height: image.height
		pitch: image.width * 4
		data: pixels
		// stb preserves the encoded top-to-bottom scanline order. Keep the
		// native image bridge from reflecting those rows as Quartz storage.
		native_rows_are_top_down: true
	}
}
