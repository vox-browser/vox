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
	// Odd frames leave another surface's rendering pending, so the upload
	// joins that command buffer instead of being submitted alone.
	mut pending := ctx.new_surface(width: 9, height: 7)!
	defer {
		pending.free()
	}
	if frame % 2 == 1 {
		pending.draw_rect(canvas.Rect.xywh(1, 1, 5, 4), canvas.Paint{
			color: canvas.Color4f{0.5, 0.25, 0.75, 1}
		})!
		pending.flush()!
	}
	surface.write_pixels(pixels.data, 37 * 4)!
	// The caller's buffer is reusable as soon as the upload returns.
	for i in 0 .. pixels.len {
		pixels[i] = 0x5a
	}
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
	mut ctx := canvas.new_gpu_context() or { panic(err) }
	mut count := 0
	for samples in [1, 4] {
		for frame in 0 .. 32 {
			os.setenv('VOX_GG_SEPARATE_TRANSFERS', '1', true)
			expected := draw_transfer(mut ctx, samples, frame) or { panic(err) }
			os.unsetenv('VOX_GG_SEPARATE_TRANSFERS')
			actual := draw_transfer(mut ctx, samples, frame) or { panic(err) }
			assert actual == expected
			count++
		}
	}
	println('GG canvas transfers: ${count} exact AA/MSAA backdrop cases')
}
