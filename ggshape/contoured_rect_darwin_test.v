// vtest build: macos
module ggshape

import crypto.sha256

// Independent CPU SkPicture geometry, replayed by the pre-migration Graphite
// library (59b9b9a5d65da5d69b196474afc5eb48c9e71e21f3fddfc04b986aa9d2a47c54).
// Serialization reconstructs its byte-exact colors by multiplication with 1/255.
fn test_contoured_geometry_matches_the_independent_retained_gpu_oracle() {
	{
		shape := C.VoxGraphiteShape{
			matrix:                [f32(1), 0, 0, 0, 1, 0, 0, 0, 1]!
			rect:                  [f32(5.25), 4.5, 30.5, 20.25, 6, 6, 4, 3, 8, 8, 2, 5]!
			contour_reference:     [f32(4), 3, 33, 23, 7, 7, 5, 4, 9, 9, 3, 6]!
			underlay_rect:         [f32(7), 6, 27, 17, 5, 5, 3, 2, 7, 7, 1, 4]!
			contour_parameters:    [f32(1.1), 1.25, .98, 1.1]!
			has_float_color:       1
			float_color:           [f32(51) * (f32(1) / 255), f32(153) * (f32(1) / 255),
				f32(204) * (f32(1) / 255), f32(102) * (f32(1) / 255)]!
			anti_alias:            1
			fill:                  11
			has_contour_reference: 0
			thickness:             0
			force_msaa:            0
		}
		mut pixels := []u8{len: 48 * 32 * 4, init: u8(252)}
		for j in 0 .. 48 * 32 { pixels[j * 4 + 3] = 255 }
		assert draw(pixels.data, 48, 32, 48 * 4, 0, &shape) == 1
		assert sha256.sum(pixels).hex() == '3b91843a4964e0065d1c91d7b723f7d2417882aa1cd8f90be17ce639d82fc2d6', 'case 0'
	}

	{
		shape := C.VoxGraphiteShape{
			matrix:                [f32(1), 0, 0, 0, 1, 0, 0, 0, 1]!
			rect:                  [f32(5.25), 4.5, 30.5, 20.25, 6, 6, 4, 3, 8, 8, 2, 5]!
			contour_reference:     [f32(4), 3, 33, 23, 7, 7, 5, 4, 9, 9, 3, 6]!
			underlay_rect:         [f32(7), 6, 27, 17, 5, 5, 3, 2, 7, 7, 1, 4]!
			contour_parameters:    [f32(1.1), 1.25, .98, 1.1]!
			has_float_color:       1
			float_color:           [f32(51) * (f32(1) / 255), f32(153) * (f32(1) / 255),
				f32(204) * (f32(1) / 255), f32(102) * (f32(1) / 255)]!
			anti_alias:            1
			fill:                  11
			has_contour_reference: 0
			thickness:             0
			force_msaa:            0
		}
		mut pixels := []u8{len: 48 * 32 * 4, init: u8(252)}
		for j in 0 .. 48 * 32 { pixels[j * 4 + 3] = 255 }
		assert draw(pixels.data, 48, 32, 48 * 4, 1, &shape) == 1
		assert sha256.sum(pixels).hex() == 'f810f29bc76e99be8781bae7b07f0ac39c9254ee93573b4f16b8980ad2e22d63', 'case 1'
	}

	{
		shape := C.VoxGraphiteShape{
			matrix:                [f32(1), 0, 0, 0, 1, 0, 0, 0, 1]!
			rect:                  [f32(5.25), 4.5, 30.5, 20.25, 6, 6, 4, 3, 8, 8, 2, 5]!
			contour_reference:     [f32(4), 3, 33, 23, 7, 7, 5, 4, 9, 9, 3, 6]!
			underlay_rect:         [f32(7), 6, 27, 17, 5, 5, 3, 2, 7, 7, 1, 4]!
			contour_parameters:    [f32(1.1), 1.25, .98, 1.1]!
			has_float_color:       1
			float_color:           [f32(51) * (f32(1) / 255), f32(153) * (f32(1) / 255),
				f32(204) * (f32(1) / 255), f32(102) * (f32(1) / 255)]!
			anti_alias:            1
			fill:                  11
			has_contour_reference: 1
			thickness:             0
			force_msaa:            0
		}
		mut pixels := []u8{len: 48 * 32 * 4, init: u8(252)}
		for j in 0 .. 48 * 32 { pixels[j * 4 + 3] = 255 }
		assert draw(pixels.data, 48, 32, 48 * 4, 0, &shape) == 1
		assert sha256.sum(pixels).hex() == '3b91843a4964e0065d1c91d7b723f7d2417882aa1cd8f90be17ce639d82fc2d6', 'case 2'
	}

	{
		shape := C.VoxGraphiteShape{
			matrix:                [f32(1), 0, 0, 0, 1, 0, 0, 0, 1]!
			rect:                  [f32(5.25), 4.5, 30.5, 20.25, 6, 6, 4, 3, 8, 8, 2, 5]!
			contour_reference:     [f32(4), 3, 33, 23, 7, 7, 5, 4, 9, 9, 3, 6]!
			underlay_rect:         [f32(7), 6, 27, 17, 5, 5, 3, 2, 7, 7, 1, 4]!
			contour_parameters:    [f32(1.1), 1.25, .98, 1.1]!
			has_float_color:       1
			float_color:           [f32(51) * (f32(1) / 255), f32(153) * (f32(1) / 255),
				f32(204) * (f32(1) / 255), f32(102) * (f32(1) / 255)]!
			anti_alias:            1
			fill:                  11
			has_contour_reference: 1
			thickness:             0
			force_msaa:            0
		}
		mut pixels := []u8{len: 48 * 32 * 4, init: u8(252)}
		for j in 0 .. 48 * 32 { pixels[j * 4 + 3] = 255 }
		assert draw(pixels.data, 48, 32, 48 * 4, 1, &shape) == 1
		assert sha256.sum(pixels).hex() == 'f810f29bc76e99be8781bae7b07f0ac39c9254ee93573b4f16b8980ad2e22d63', 'case 3'
	}

	{
		shape := C.VoxGraphiteShape{
			matrix:                [f32(1), 0, 0, 0, 1, 0, 0, 0, 1]!
			rect:                  [f32(5.25), 4.5, 30.5, 20.25, 6, 6, 4, 3, 8, 8, 2, 5]!
			contour_reference:     [f32(4), 3, 33, 23, 7, 7, 5, 4, 9, 9, 3, 6]!
			underlay_rect:         [f32(7), 6, 27, 17, 5, 5, 3, 2, 7, 7, 1, 4]!
			contour_parameters:    [f32(1.1), 1.25, .98, 1.1]!
			has_float_color:       1
			float_color:           [f32(51) * (f32(1) / 255), f32(153) * (f32(1) / 255),
				f32(204) * (f32(1) / 255), f32(102) * (f32(1) / 255)]!
			anti_alias:            1
			fill:                  11
			has_contour_reference: 1
			thickness:             0
			force_msaa:            1
		}
		mut pixels := []u8{len: 48 * 32 * 4, init: u8(252)}
		for j in 0 .. 48 * 32 { pixels[j * 4 + 3] = 255 }
		assert draw(pixels.data, 48, 32, 48 * 4, 0, &shape) == 1
		assert sha256.sum(pixels).hex() == '3b91843a4964e0065d1c91d7b723f7d2417882aa1cd8f90be17ce639d82fc2d6', 'case 4'
	}

	{
		shape := C.VoxGraphiteShape{
			matrix:                [f32(1), 0, 0, 0, 1, 0, 0, 0, 1]!
			rect:                  [f32(5.25), 4.5, 30.5, 20.25, 6, 6, 4, 3, 8, 8, 2, 5]!
			contour_reference:     [f32(4), 3, 33, 23, 7, 7, 5, 4, 9, 9, 3, 6]!
			underlay_rect:         [f32(7), 6, 27, 17, 5, 5, 3, 2, 7, 7, 1, 4]!
			contour_parameters:    [f32(1.1), 1.25, .98, 1.1]!
			has_float_color:       1
			float_color:           [f32(51) * (f32(1) / 255), f32(153) * (f32(1) / 255),
				f32(204) * (f32(1) / 255), f32(102) * (f32(1) / 255)]!
			anti_alias:            1
			fill:                  11
			has_contour_reference: 1
			thickness:             0
			force_msaa:            1
		}
		mut pixels := []u8{len: 48 * 32 * 4, init: u8(252)}
		for j in 0 .. 48 * 32 { pixels[j * 4 + 3] = 255 }
		assert draw(pixels.data, 48, 32, 48 * 4, 1, &shape) == 1
		assert sha256.sum(pixels).hex() == 'f810f29bc76e99be8781bae7b07f0ac39c9254ee93573b4f16b8980ad2e22d63', 'case 5'
	}

	{
		shape := C.VoxGraphiteShape{
			matrix:                [f32(1), 0, 0, 0, 1, 0, 0, 0, 1]!
			rect:                  [f32(5.25), 4.5, 30.5, 20.25, 6, 6, 4, 3, 8, 8, 2, 5]!
			contour_reference:     [f32(4), 3, 33, 23, 7, 7, 5, 4, 9, 9, 3, 6]!
			underlay_rect:         [f32(7), 6, 27, 17, 5, 5, 3, 2, 7, 7, 1, 4]!
			contour_parameters:    [f32(1.1), 1.25, .98, 1.1]!
			has_float_color:       1
			float_color:           [f32(51) * (f32(1) / 255), f32(153) * (f32(1) / 255),
				f32(204) * (f32(1) / 255), f32(102) * (f32(1) / 255)]!
			anti_alias:            1
			fill:                  12
			has_contour_reference: 0
			thickness:             2
			force_msaa:            0
		}
		mut pixels := []u8{len: 48 * 32 * 4, init: u8(252)}
		for j in 0 .. 48 * 32 { pixels[j * 4 + 3] = 255 }
		assert draw(pixels.data, 48, 32, 48 * 4, 0, &shape) == 1
		assert sha256.sum(pixels).hex() == '7c5021030cd2b2d091902cee64307b9c9885a1dcbf42c59c46ba87878fab4599', 'case 6'
	}

	{
		shape := C.VoxGraphiteShape{
			matrix:                [f32(1), 0, 0, 0, 1, 0, 0, 0, 1]!
			rect:                  [f32(5.25), 4.5, 30.5, 20.25, 6, 6, 4, 3, 8, 8, 2, 5]!
			contour_reference:     [f32(4), 3, 33, 23, 7, 7, 5, 4, 9, 9, 3, 6]!
			underlay_rect:         [f32(7), 6, 27, 17, 5, 5, 3, 2, 7, 7, 1, 4]!
			contour_parameters:    [f32(1.1), 1.25, .98, 1.1]!
			has_float_color:       1
			float_color:           [f32(51) * (f32(1) / 255), f32(153) * (f32(1) / 255),
				f32(204) * (f32(1) / 255), f32(102) * (f32(1) / 255)]!
			anti_alias:            1
			fill:                  12
			has_contour_reference: 0
			thickness:             2
			force_msaa:            0
		}
		mut pixels := []u8{len: 48 * 32 * 4, init: u8(252)}
		for j in 0 .. 48 * 32 { pixels[j * 4 + 3] = 255 }
		assert draw(pixels.data, 48, 32, 48 * 4, 1, &shape) == 1
		assert sha256.sum(pixels).hex() == '1d02092eb0071ccd471543ec0f005816e248c0bc88281d3f949a362d8d957c85', 'case 7'
	}

	{
		shape := C.VoxGraphiteShape{
			matrix:                [f32(1), 0, 0, 0, 1, 0, 0, 0, 1]!
			rect:                  [f32(5.25), 4.5, 30.5, 20.25, 6, 6, 4, 3, 8, 8, 2, 5]!
			contour_reference:     [f32(4), 3, 33, 23, 7, 7, 5, 4, 9, 9, 3, 6]!
			underlay_rect:         [f32(7), 6, 27, 17, 5, 5, 3, 2, 7, 7, 1, 4]!
			contour_parameters:    [f32(1.1), 1.25, .98, 1.1]!
			has_float_color:       1
			float_color:           [f32(51) * (f32(1) / 255), f32(153) * (f32(1) / 255),
				f32(204) * (f32(1) / 255), f32(102) * (f32(1) / 255)]!
			anti_alias:            1
			fill:                  12
			has_contour_reference: 0
			thickness:             2
			force_msaa:            1
		}
		mut pixels := []u8{len: 48 * 32 * 4, init: u8(252)}
		for j in 0 .. 48 * 32 { pixels[j * 4 + 3] = 255 }
		assert draw(pixels.data, 48, 32, 48 * 4, 0, &shape) == 1
		assert sha256.sum(pixels).hex() == '7c5021030cd2b2d091902cee64307b9c9885a1dcbf42c59c46ba87878fab4599', 'case 8'
	}

	{
		shape := C.VoxGraphiteShape{
			matrix:                [f32(1), 0, 0, 0, 1, 0, 0, 0, 1]!
			rect:                  [f32(5.25), 4.5, 30.5, 20.25, 6, 6, 4, 3, 8, 8, 2, 5]!
			contour_reference:     [f32(4), 3, 33, 23, 7, 7, 5, 4, 9, 9, 3, 6]!
			underlay_rect:         [f32(7), 6, 27, 17, 5, 5, 3, 2, 7, 7, 1, 4]!
			contour_parameters:    [f32(1.1), 1.25, .98, 1.1]!
			has_float_color:       1
			float_color:           [f32(51) * (f32(1) / 255), f32(153) * (f32(1) / 255),
				f32(204) * (f32(1) / 255), f32(102) * (f32(1) / 255)]!
			anti_alias:            1
			fill:                  12
			has_contour_reference: 0
			thickness:             2
			force_msaa:            1
		}
		mut pixels := []u8{len: 48 * 32 * 4, init: u8(252)}
		for j in 0 .. 48 * 32 { pixels[j * 4 + 3] = 255 }
		assert draw(pixels.data, 48, 32, 48 * 4, 1, &shape) == 1
		assert sha256.sum(pixels).hex() == '1d02092eb0071ccd471543ec0f005816e248c0bc88281d3f949a362d8d957c85', 'case 9'
	}

	{
		shape := C.VoxGraphiteShape{
			matrix:                [f32(1), 0, 0, 0, 1, 0, 0, 0, 1]!
			rect:                  [f32(5.25), 4.5, 30.5, 20.25, 6, 6, 4, 3, 8, 8, 2, 5]!
			contour_reference:     [f32(4), 3, 33, 23, 7, 7, 5, 4, 9, 9, 3, 6]!
			underlay_rect:         [f32(7), 6, 27, 17, 5, 5, 3, 2, 7, 7, 1, 4]!
			contour_parameters:    [f32(1.1), 1.25, .98, 1.1]!
			has_float_color:       1
			float_color:           [f32(51) * (f32(1) / 255), f32(153) * (f32(1) / 255),
				f32(204) * (f32(1) / 255), f32(102) * (f32(1) / 255)]!
			anti_alias:            1
			fill:                  13
			has_contour_reference: 1
			thickness:             0
			force_msaa:            0
		}
		mut pixels := []u8{len: 48 * 32 * 4, init: u8(252)}
		for j in 0 .. 48 * 32 { pixels[j * 4 + 3] = 255 }
		assert draw(pixels.data, 48, 32, 48 * 4, 0, &shape) == 1
		assert sha256.sum(pixels).hex() == 'f91638daf3f647f3b07ac4381a55cef67ec266f58f561235eb21d50f3c2527e0', 'case 10'
	}

	{
		shape := C.VoxGraphiteShape{
			matrix:                [f32(1), 0, 0, 0, 1, 0, 0, 0, 1]!
			rect:                  [f32(5.25), 4.5, 30.5, 20.25, 6, 6, 4, 3, 8, 8, 2, 5]!
			contour_reference:     [f32(4), 3, 33, 23, 7, 7, 5, 4, 9, 9, 3, 6]!
			underlay_rect:         [f32(7), 6, 27, 17, 5, 5, 3, 2, 7, 7, 1, 4]!
			contour_parameters:    [f32(1.1), 1.25, .98, 1.1]!
			has_float_color:       1
			float_color:           [f32(51) * (f32(1) / 255), f32(153) * (f32(1) / 255),
				f32(204) * (f32(1) / 255), f32(102) * (f32(1) / 255)]!
			anti_alias:            1
			fill:                  13
			has_contour_reference: 1
			thickness:             0
			force_msaa:            0
		}
		mut pixels := []u8{len: 48 * 32 * 4, init: u8(252)}
		for j in 0 .. 48 * 32 { pixels[j * 4 + 3] = 255 }
		assert draw(pixels.data, 48, 32, 48 * 4, 1, &shape) == 1
		assert sha256.sum(pixels).hex() == '2df95a2ca99d37f8c73e4cf63f09762346342fff2645fdbacee8425743458b76', 'case 11'
	}

	{
		shape := C.VoxGraphiteShape{
			matrix:                [f32(1), 0, 0, 0, 1, 0, 0, 0, 1]!
			rect:                  [f32(5.25), 4.5, 30.5, 20.25, 6, 6, 4, 3, 8, 8, 2, 5]!
			contour_reference:     [f32(4), 3, 33, 23, 7, 7, 5, 4, 9, 9, 3, 6]!
			underlay_rect:         [f32(7), 6, 27, 17, 5, 5, 3, 2, 7, 7, 1, 4]!
			contour_parameters:    [f32(1.1), 1.25, .98, 1.1]!
			has_float_color:       1
			float_color:           [f32(51) * (f32(1) / 255), f32(153) * (f32(1) / 255),
				f32(204) * (f32(1) / 255), f32(102) * (f32(1) / 255)]!
			anti_alias:            1
			fill:                  13
			has_contour_reference: 1
			thickness:             8
			force_msaa:            0
		}
		mut pixels := []u8{len: 48 * 32 * 4, init: u8(252)}
		for j in 0 .. 48 * 32 { pixels[j * 4 + 3] = 255 }
		assert draw(pixels.data, 48, 32, 48 * 4, 0, &shape) == 1
		assert sha256.sum(pixels).hex() == 'd483508a00056fff452db117005c0e2f641bfc675467666016d53b8c41268473', 'case 12'
	}

	{
		shape := C.VoxGraphiteShape{
			matrix:                [f32(1), 0, 0, 0, 1, 0, 0, 0, 1]!
			rect:                  [f32(5.25), 4.5, 30.5, 20.25, 6, 6, 4, 3, 8, 8, 2, 5]!
			contour_reference:     [f32(4), 3, 33, 23, 7, 7, 5, 4, 9, 9, 3, 6]!
			underlay_rect:         [f32(7), 6, 27, 17, 5, 5, 3, 2, 7, 7, 1, 4]!
			contour_parameters:    [f32(1.1), 1.25, .98, 1.1]!
			has_float_color:       1
			float_color:           [f32(51) * (f32(1) / 255), f32(153) * (f32(1) / 255),
				f32(204) * (f32(1) / 255), f32(102) * (f32(1) / 255)]!
			anti_alias:            1
			fill:                  13
			has_contour_reference: 1
			thickness:             8
			force_msaa:            0
		}
		mut pixels := []u8{len: 48 * 32 * 4, init: u8(252)}
		for j in 0 .. 48 * 32 { pixels[j * 4 + 3] = 255 }
		assert draw(pixels.data, 48, 32, 48 * 4, 1, &shape) == 1
		assert sha256.sum(pixels).hex() == 'cf045b3606ef19686d43be29175059e013c658a20d9f1533495807af5ae2712f', 'case 13'
	}
}
