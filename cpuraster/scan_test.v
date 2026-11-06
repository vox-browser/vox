module cpuraster

import crypto.sha256
import math

fn fill_background(width int, height int) []u8 {
	mut px := []u8{len: width * height * 4}
	for y in 0 .. height {
		for x in 0 .. width {
			o := (y * width + x) * 4
			a := u8((x * 7 + y * 3) % 256)
			px[o + 3] = a
			px[o] = u8(int(a) * x / math.max(width, 1))
			px[o + 1] = u8(int(a) * y / math.max(height, 1))
			px[o + 2] = a / 2
		}
	}
	return px
}

fn fill_hash(path Path, m Matrix, width int, height int, color u32) string {
	mut pixels := fill_background(width, height)
	mut blitter := new_solid_blitter(mut pixels, width * 4, color)
	assert anti_fill_path(path.transform(m), IRect{0, 0, width, height}, mut blitter)
	return sha256.sum(pixels).hex()[..16]
}

// Hashes of LibWeb Skia's drawPath() output for the same paths, colors,
// matrices and backgrounds (test_cpu_raster.sh compares random paths).
fn test_fill_concave_even_odd_star() {
	mut b := PathBuilder{}
	for i in 0 .. 5 {
		angle := f64(i) * 4 * math.pi / 5 - math.pi / 2
		x := f32(32 + 28 * math.cos(angle))
		y := f32(32 + 28 * math.sin(angle))
		if i == 0 {
			b.move_to(x, y)
		} else {
			b.line_to(x, y)
		}
	}
	b.close()
	b.fill_type = .even_odd
	assert fill_hash(b.detach(), Matrix{}, 64, 64, 0xffe0302a) == '22a9484776b4f994'
}

fn test_fill_transformed_conic_circle_with_translucent_color() {
	mut b := PathBuilder{}
	b.move_to(50, 20)
	b.conic_to(50, 50, 20, 50, 0.70710677)
	b.conic_to(-10, 50, -10, 20, 0.70710677)
	b.conic_to(-10, -10, 20, -10, 0.70710677)
	b.conic_to(50, -10, 50, 20, 0.70710677)
	b.close()
	m := Matrix{
		a: 0.9
		b: 0.35
		c: -0.3
		d: 1.1
		e: 20
		f: 8
	}
	assert fill_hash(b.detach(), m, 80, 70, 0x80123456) == 'ed2df0405244e13e'
}

fn test_fill_clips_cubics_crossing_the_device() {
	mut b := PathBuilder{}
	b.move_to(-20, 10)
	b.cubic_to(30, -40, 90, 120, 20, 70)
	b.cubic_to(-30, 60, 10, -5, -20, 10)
	assert fill_hash(b.detach(), Matrix{}, 60, 50, 0xff000000) == '8816a23b0806c6f9'
}

fn test_fill_small_path_uses_the_coverage_mask() {
	mut b := PathBuilder{}
	b.move_to(3.25, 2.5)
	b.quad_to(18, 1, 16.75, 15.5)
	b.line_to(2, 17)
	b.close()
	b.fill_type = .even_odd
	assert fill_hash(b.detach(), Matrix{ e: 0.5, f: 0.25 }, 20, 20, 0xff3366cc) == '6732031662533dfc'
}
