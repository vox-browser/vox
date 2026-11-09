// Run with modules prepared by prepare_ui2.py before @vlib in -path.
module main

import gg.canvas
import os

fn draw_transfer(mut ctx canvas.GpuContext, samples int, frame int) ![]u8 {
	mut surface := ctx.new_surface(width: 37, height: 29, sample_count: samples)!
	defer {
		surface.free()
	}
	mut pixels := []u8{len: 37 * 29 * 4, init: u8((index + frame) % 127)}
	surface.write_pixels(pixels.data, 37 * 4)!
	if samples == 4 {
		surface.draw_msaa_trigger()
	}
	surface.clip_rect(canvas.Rect.xywh(1.25, 2.5, 32.5, 23.25), .intersect, true)!
	radii := [canvas.Point{5, 7}, canvas.Point{5, 7}, canvas.Point{5, 7}, canvas.Point{5, 7}]!
	surface.draw_rrect(canvas.RRect.rect_radii(canvas.Rect.xywh(0.375, 0.25, 31.5, 25.5), radii),
		canvas.Paint{ color: canvas.Color4f{0.25, 0.5, 0.125, 0.75}, anti_alias: true })!
	surface.read_pixels(pixels.data, 37 * 4)!
	return pixels
}

fn main() {
	os.setenv('VOX_GG_JOINED_READBACK', '1', true)
	mut ctx := canvas.new_gpu_context() or { panic(err) }
	mut count := 0
	for samples in [1, 4] {
		for frame in 0 .. 32 {
			os.setenv('VOX_GG_SEPARATE_READBACK', '1', true)
			expected := draw_transfer(mut ctx, samples, frame) or { panic(err) }
			os.unsetenv('VOX_GG_SEPARATE_READBACK')
			actual := draw_transfer(mut ctx, samples, frame) or { panic(err) }
			assert actual == expected
			count++
		}
	}
	println('GG canvas readback: ${count} exact AA/MSAA backdrop cases')
}
