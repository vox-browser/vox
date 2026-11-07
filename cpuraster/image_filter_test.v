module cpuraster

import crypto.sha256

fn image_filter_test_image() BlurImage {
	mut px := []u8{len: 20 * 16 * 4}
	for y in 0 .. 16 {
		for x in 0 .. 20 {
			o := (y * 20 + x) * 4
			mut a := (x * 37 + y * 91) % 256
			if (x + 2 * y) % 5 == 0 {
				a = 255
			}
			if (x * 3 + y) % 7 == 3 {
				a = 0
			}
			px[o + 3] = u8(a)
			px[o] = u8((x * 53 + y * 17) % 256 * a / 255)
			px[o + 1] = u8((x * 11 + y * 67) % 256 * a / 255)
			px[o + 2] = u8((x * 29 + y * 41 + 100) % 256 * a / 255)
		}
	}
	return BlurImage{px, 20, 16}
}

fn image_blur_test(sx f32, sy f32, subset IRect, clip IRect) string {
	image, x, y := image_with_blur_filter(image_filter_test_image(), subset, clip, sx, sy) or {
		return 'none'
	}
	return '${image.width}x${image.height} at ${x},${y} ${sha256.sum(image.pixels).hex()[..16]}'
}

// SkImages::MakeWithFilter() with SkImageFilters::Blur() in LibWeb Skia for
// the same images (test_cpu_raster.sh compares random ones): the Gaussian
// pass, mixed Gaussian and three-box passes, a three-box blur past a
// subset, and one effectively unblurred axis.
fn test_image_blurs_match_skia() {
	assert image_blur_test(0.7, 0.7, IRect{0, 0, 20, 16}, IRect{-4, -4, 24, 20}) == '26x22 at -3,-3 cd273c8b138ae7d3'
	assert image_blur_test(3.2, 1.1, IRect{3, 2, 17, 13}, IRect{0, 0, 20, 16}) == '20x16 at 0,0 a276900bbfcee6b5'
	assert image_blur_test(12, 12, IRect{0, 0, 20, 16}, IRect{-30, -30, 50, 46}) == '80x76 at -30,-30 d91f4eccf672fc0f'
	assert image_blur_test(0.01, 5, IRect{5, 0, 15, 16}, IRect{2, -10, 18, 26}) == '10x36 at 5,-10 99ed73d38c5612df'
}

// Box blur windows and Gaussian radii at their boundaries.
fn test_blur_windows() {
	assert blur_sigma_to_radius(0.03) == 0
	assert blur_sigma_to_radius(0.031) == 1
	assert box_blur_window(2) == 4
	assert box_blur_window(135) == 254
	assert new_blur_maker(1.99).gaussian
	assert !new_blur_maker(2).gaussian
}
