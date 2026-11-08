module main

import gg
import painting

fn (mut player BrowserMediaPlayback) update_frame_planes(pixels &u8, length int, format int,
	previous_generation u64) {
	mut frame := player.frame or { return }
	width := int(frame.width)
	height := int(frame.height)
	y_size := width * height
	uv_size := ((width + 1) / 2) * ((height + 1) / 2)
	alpha := format in [13, 14]
	expected := y_size * (if alpha { 2 } else { 1 }) + uv_size * 2
	if pixels == unsafe { nil } || format !in [8, 9, 13, 14] || length != expected {
		if frame.yuv_data != none {
			player.frame = &painting.MediaVideoFrame{
				...frame
				yuv_data:   none
				generation: if frame.generation == previous_generation {
					previous_generation + 1
				} else {
					frame.generation
				}
			}
		}
		return
	}
	full_range := format in [9, 14]
	if data := frame.yuv_data {
		if data.packed_planes.len == length && data.full_range == full_range
			&& (data.a_plane.len > 0) == alpha {
			if unsafe { vmemcmp(data.packed_planes.data, pixels, length) == 0 } { return }
			unsafe { vmemcpy(data.packed_planes.data, pixels, length) }
			// Distinct planes can quantize to the same CPU RGBA frame while
			// producing different filtered GPU pixels. Keep that generation live.
			if frame.generation == previous_generation { frame.generation++ }
			return
		}
	}
	mut packed := []u8{len: length}
	unsafe { vmemcpy(packed.data, pixels, length) }
	player.frame = &painting.MediaVideoFrame{
		...frame
		generation:  if frame.generation == previous_generation {
			previous_generation + 1
		} else {
			frame.generation
		}
		color_space: .bt601
		yuv_data:    painting.MediaVideoYUVData{
			y_plane:       packed[..y_size]
			u_plane:       packed[y_size..y_size + uv_size]
			v_plane:       packed[y_size + uv_size..y_size + uv_size * 2]
			a_plane:       if alpha { packed[y_size + uv_size * 2..] } else { []u8{} }
			y_stride:      width
			u_stride:      (width + 1) / 2
			v_stride:      (width + 1) / 2
			a_stride:      width
			full_range:    full_range
			packed_planes: packed
		}
	}
}

fn browser_planar_video_image(frame &painting.MediaVideoFrame) ?&gg.Image {
	$if macos {
		if C.native_webp_yuv_paint_supported() == 0 || frame.color_space != .bt601
			|| frame.bit_depth != 8 {
			return none
		}
		data := frame.yuv_data or { return none }
		if data.subsampling != .yuv420 { return none }
		width := int(frame.width)
		height := int(frame.height)
		if width <= 0 || height <= 0 { return none }
		alpha := data.a_plane.len > 0
		expected := width * height * (if alpha { 2 } else { 1 }) +
			((width + 1) / 2) * ((height + 1) / 2) * 2
		if data.packed_planes.len != expected { return none }
		return &gg.Image{
			width:       width
			height:      height
			nr_channels: (if alpha { 13 } else { 8 }) + (if data.full_range { 1 } else { 0 })
			ok:          true
			data:        data.packed_planes.data
		}
	} $else {
		return none
	}
}
