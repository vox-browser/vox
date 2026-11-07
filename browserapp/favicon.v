module main

import dom
import encoding.binary
import gg
import sokol.gfx

fn image_bytes_are_ico(bytes []u8) bool {
	return bytes.len >= 6 && bytes[0] == 0 && bytes[1] == 0 && bytes[2] == 1 && bytes[3] == 0
}

// The paint resource loader must use the same ICO decoder as the image model;
// gg's standard byte loader cannot decode the icon container.
fn (mut app BrowserApp) create_ico_resource_image(bytes []u8) !gg.Image {
	bitmap := browser_decode_ico_image_bytes(bytes)!
	$if macos {
		if app.ctx.native_rendering {
			C.native_tag_image_color_profile(bitmap.data.data, bitmap.width, bitmap.height,
				bytes.data, uint(bytes.len), 0)
		}
	}
	mut image := gg.Image{
		width: bitmap.width
		height: bitmap.height
		nr_channels: if app.ctx.native_rendering { native_bitmap_channel_marker(bitmap, false) } else { 4 }
		ok: true
		data: bitmap.data.data
		texture_filter: app.ctx.config.texture_filter
	}
	if !app.ctx.native_rendering && gfx.is_valid() { image.init_sokol_image() }
	image.id = app.ctx.cache_image(image)
	return image
}

// ICO stores either PNG images or BMP DIBs with a separate transparency mask.
// Select the frame nearest the shortcut's 32px size, preferring downscaling.
fn browser_decode_ico_image_bytes(bytes []u8) !&dom.Bitmap_ {
	if !image_bytes_are_ico(bytes) { return error('Invalid icon header') }
	count := int(binary.little_endian_u16_at(bytes, 4))
	if count == 0 || count > (bytes.len - 6) / 16 { return error('Invalid icon directory') }
	mut selected := -1
	mut best_score := 100000
	for index in 0 .. count {
		entry := 6 + index * 16
		size := int(binary.little_endian_u32_at(bytes, entry + 8))
		offset := int(binary.little_endian_u32_at(bytes, entry + 12))
		if offset < 6 + count * 16 || size <= 0 || offset > bytes.len || size > bytes.len - offset { continue }
		width := if bytes[entry] == 0 { 256 } else { int(bytes[entry]) }
		height := if bytes[entry + 1] == 0 { 256 } else { int(bytes[entry + 1]) }
		dimension := if width < height { width } else { height }
		score := if dimension >= 32 { dimension - 32 } else { (32 - dimension) * 16 }
		if score < best_score { selected = entry; best_score = score }
	}
	if selected < 0 { return error('Icon has no valid frames') }
	offset := int(binary.little_endian_u32_at(bytes, selected + 12))
	size := int(binary.little_endian_u32_at(bytes, selected + 8))
	frame := bytes[offset..offset + size]
	if frame.len >= 8 && frame[..8] == [u8(137), 80, 78, 71, 13, 10, 26, 10] {
		return browser_decode_stb_raster_bytes(frame)
	}
	if frame.len < 40 { return error('Truncated icon bitmap') }
	header_size := int(binary.little_endian_u32_at(frame, 0))
	width := int(binary.little_endian_u32_at(frame, 4))
	doubled_height := int(binary.little_endian_u32_at(frame, 8))
	bits := int(binary.little_endian_u16_at(frame, 14))
	compression := binary.little_endian_u32_at(frame, 16)
	if header_size !in [40, 56, 108, 124] || header_size > frame.len
		|| width <= 0 || width > 256 || doubled_height <= 0 || doubled_height > 512
		|| doubled_height % 2 != 0 || bits !in [1, 4, 8, 16, 24, 32] || compression !in [u32(0), 3] {
		return error('Unsupported icon bitmap')
	}
	height := doubled_height / 2
	colors_used := int(binary.little_endian_u32_at(frame, 32))
	palette_size := if bits <= 8 { if colors_used > 0 { colors_used } else { 1 << bits } } else { 0 }
	if palette_size > 256 { return error('Invalid icon palette') }
	pixel_offset := header_size + palette_size * 4 + if header_size == 40 && compression == 3 { 12 } else { 0 }
	stride := ((width * bits + 31) / 32) * 4
	pixel_end := pixel_offset + stride * height
	if pixel_end > frame.len { return error('Truncated icon pixels') }
	mut bitmap_file := []u8{len: 14 + pixel_end}
	bitmap_file[0] = `B`
	bitmap_file[1] = `M`
	binary.little_endian_put_u32_at(mut bitmap_file, u32(bitmap_file.len), 2)
	binary.little_endian_put_u32_at(mut bitmap_file, u32(14 + pixel_offset), 10)
	copy(mut bitmap_file[14..], frame[..pixel_end])
	binary.little_endian_put_u32_at(mut bitmap_file, u32(height), 22)
	mut bitmap := browser_decode_stb_raster_bytes(bitmap_file)!
	mask_stride := ((width + 31) / 32) * 4
	if frame.len - pixel_end >= mask_stride * height {
		for y in 0 .. height {
			for x in 0 .. width {
				mask := frame[pixel_end + (height - 1 - y) * mask_stride + x / 8]
				if mask & (u8(0x80) >> (x % 8)) != 0 { bitmap.data[y * bitmap.pitch + x * 4 + 3] = 0 }
			}
		}
	}
	return bitmap
}
