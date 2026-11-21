module ggshape

import gg.canvas
import os

fn pooled_region_leaf(mut ctx canvas.GpuContext, fresh bool, mut tile []u8, x int, y int, color f32) {
	mut s := if fresh {
		ctx.new_surface(width: 1056, height: 416) or { panic(err) }
	} else {
		ctx.new_document_leaf_surface(1056, 416, 1) or { panic(err) }
	}
	s.write_document_region(unsafe { &tile[(y * 1056 + x) * 4] }, 1056 * 4, x, y, 200, 40) or { panic(err) }
	s.save()
	s.clip_rect(canvas.Rect.ltrb(f32(x) + 3.5, f32(y) + 2.25, f32(x) + 190.5, f32(y) + 37.75), .intersect, true) or { panic(err) }
	s.draw_rrect(canvas.RRect.rect_radii(canvas.Rect.ltrb(f32(x) + 1.5, f32(y) + 1.5, f32(x) + 180.25, f32(y) + 39.5), [canvas.Point{6.5, 6.5}, canvas.Point{6.5, 6.5}, canvas.Point{6.5, 6.5}, canvas.Point{6.5, 6.5}]!), canvas.Paint{ color: canvas.Color4f{color, 0.2, 0.1, 0.7}, anti_alias: true }) or { panic(err) }
	s.restore()
	s.read_document_region(unsafe { &tile[(y * 1056 + x) * 4] }, 1056 * 4, x, y, 200, 40) or { panic(err) }
	if fresh { s.free() } else { s.release_document_leaf_surface() }
}

// Leaf surfaces reuse a released surface's render targets. A region leaf
// uploads and reads back only its rectangle, so the rest of a reused target
// holds an earlier leaf's pixels; full-surface leaves overwrite the whole
// target. Both must read back what a new surface produces, with and without
// multisampling, while targets of other sizes come and go.
fn test_pooled_leaf_surfaces_read_back_what_new_surfaces_do() {
	mut ctx := context() or { panic(err) }
	mut a := []u8{len: 1056 * 416 * 4}
	for i in 0 .. a.len { a[i] = u8((i * 7 + i / 4096) % 251) }
	mut b := a.clone()
	for round in 0 .. 60 {
		x := (round * 37) % 800
		y := (round * 13) % 360
		c := f32(round % 10) / 10
		pooled_region_leaf(mut ctx, true, mut a, x, y, c)
		pooled_region_leaf(mut ctx, false, mut b, x, y, c)
		// Glyph masks of changing sizes on full surfaces, pooled and fresh.
		w, h := 40 + round % 3 * 20, 30 + round % 2 * 10
		mask := []u8{len: w * h, init: u8((round * 29) % 256)}
		mut pa := []u8{len: w * h * 4, init: u8(round * 3)}
		mut pb := pa.clone()
		assert draw_clipped_glyph_mask(pa.data, i32(w), i32(h), i32(w * 4), 1, mask, [f32(0.2), 0.3, 0.9, 1]!, [f32(1.5), 0.5, f32(w) - 2.5, f32(h) - 1.25]!, 1 + round % 2 * 3) == 1
		mut fresh := ctx.new_surface(width: w, height: h, sample_count: 1 + round % 2 * 3) or { panic(err) }
		fresh.write_pixels(pb.data, w * 4) or { panic(err) }
		if round % 2 == 1 { fresh.draw_msaa_trigger() }
		fresh.clip_rect(canvas.Rect.ltrb(1.5, 0.5, f32(w) - 2.5, f32(h) - 1.25), .intersect, true) or { panic(err) }
		fresh.draw_alpha_mask(mask, w, h, canvas.Paint{ color: canvas.Color4f{0.2, 0.3, 0.9, 1} }) or { panic(err) }
		fresh.read_pixels(pb.data, w * 4) or { panic(err) }
		fresh.free()
		assert pa == pb, 'glyph round ${round}'
	}
	assert a == b
	reused, _ := canvas.document_leaf_surface_statistics()
	if os.getenv('VOX_GG_FRESH_LEAF_SURFACES') == '' {
		assert reused > 50
	}
}
