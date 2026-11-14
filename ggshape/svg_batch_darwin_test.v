// vtest build: macos
module ggshape

import crypto.sha256

fn test_adjacent_svg_paths_share_samples_until_the_resolve() {
	// Two triangles form one square; resolving each triangle separately leaves
	// a seam along their shared diagonal. Independent pre-migration Graphite
	// oracle: 59b9b9a5d65da5d69b196474afc5eb48c9e71e21f3fddfc04b986aa9d2a47c54.
	mut segments := [][]f32{}
	for points in [[[f32(2.5), 2.5], [f32(20.5), 2.5], [f32(2.5), 20.5]],
		[[f32(20.5), 2.5], [f32(20.5), 20.5], [f32(2.5), 20.5]]] {
		mut data := []f32{}
		for i, point in points {
			data << if i == 0 { f32(0) } else { f32(1) }
			data << point
			data << []f32{len: 9}
		}
		data << f32(5)
		data << []f32{len: 11}
		segments << data
	}
	mut paths := []C.VoxGraphitePath{}
	for data in segments {
		paths << C.VoxGraphitePath{
			matrix:        [f32(1), 0, 0, 0, 1, 0, 0, 0, 1]!
			segments:      data.data
			segment_count: 4
			red:           13
			green:         13
			blue:          13
			alpha:         255
			opacity:       1
		}
	}
	parent := [f32(1), 0, 0, 0, 1, 0, 0, 0, 1]!
	viewport := [f32(0), 0, 24, 24]!
	for flags in [i32(0), 1, 2, 3, 6, 7] {
		mut pixels := []u8{len: 24 * 24 * 4, init: u8(252)}
		for i in 0 .. 24 * 24 { pixels[i * 4 + 3] = 255 }
		assert draw_svg_image(pixels.data, 24, 24, 24 * 4, flags, paths.data, 2, &parent[0], &viewport[0], unsafe { nil }) == 1
		expected := if flags & 1 != 0 {
			'bbd1707a4c42381ef8a5d2b58ac4b983edf7b5da19038031c1d61d61c588d9d4'
		} else {
			'466e6260a5ee6d23bcdc1b266e73d04731705272383653e87157d266127d2d41'
		}
		assert sha256.sum(pixels).hex() == expected, 'flags=${flags}'
	}
}
