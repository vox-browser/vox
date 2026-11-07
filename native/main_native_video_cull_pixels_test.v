module main

import gg
import layout
import painting
import dom

$if macos {
	#include "@VMODROOT/tools/native_video_cull_pixels_test.m"
	fn C.native_video_cull_test_frame(voidptr, fn (voidptr), i32, &u8, i32) i32
}

struct VideoCullPixelProbe {
mut:
	app &BrowserApp
	command layout.PaintCommand
	cull bool
	blank bool
}

fn video_cull_pixel_paint(owner voidptr) {
	mut probe := unsafe { &VideoCullPixelProbe(owner) }
	if probe.blank { return }
	mut culling := PaintCanvasCulling{enabled: probe.cull}
	if !culling.skip(&probe.command, 0, 0, 160, 120) {
		probe.app.draw_command(probe.command, 0, 0, 120)
	}
}

fn video_cull_pixel_frame(mut probe VideoCullPixelProbe, scale int) []u8 {
	mut pixels := []u8{len: 160 * 120 * scale * scale * 4}
	$if macos {
		assert C.native_video_cull_test_frame(voidptr(&probe), video_cull_pixel_paint,
			i32(scale), pixels.data, i32(pixels.len)) != 0
	}
	return pixels
}

fn video_cull_pixel_difference(left []u8, right []u8) int {
	if left.len != right.len { return -2 }
	for index in 0 .. left.len {
		if left[index] != right[index] { return index }
	}
	return -1
}

fn test_native_video_culling_preserves_viewport_pixels_and_visible_edge_coverage() {
	$if !macos { return }
	mut source := painting.VideoFrameSource.create()
	source.update(painting.MediaVideoFrame.from_bitmap(&dom.Bitmap_{
		width: 2, height: 2, pitch: 8, native_rows_are_top_down: true,
		data: [u8(255),0,0,255,0,255,0,255,0,0,255,255,255,255,0,255]
	}))
	mut probe := VideoCullPixelProbe{app: &BrowserApp{ctx: &gg.Context{
		native_rendering: true, width: 160, height: 120}}}
	for scale in [1, 2] {
		probe.blank = true
		blank := video_cull_pixel_frame(mut probe, scale)
		probe.blank = false
		for y in [-50.0, -33.75, -30.25, -29.75, 0, 90.25, 119.75, 120.25, 124.5] {
			for shift in [0.0, 40.25] {
				probe.command = layout.PaintCommand{kind: 'draw_video',
					x: 20, y: y, width: 40, height: 30,
					transform: [f64(1), 0, 0, 1, 0, shift]!, opacity: 1,
					video_representation: .video_frame, video_frame_source: source,
					video_paintable: &painting.VideoPaintable{video_rect: painting.Rect{20, y, 40, 30}}}
				probe.cull = false
				reference := video_cull_pixel_frame(mut probe, scale)
				probe.cull = true
				candidate := video_cull_pixel_frame(mut probe, scale)
				assert video_cull_pixel_difference(reference, candidate) == -1
				if y == 0 && shift == 0 {
					assert video_cull_pixel_difference(reference, blank) >= 0
				}
			}
		}
	}
}
