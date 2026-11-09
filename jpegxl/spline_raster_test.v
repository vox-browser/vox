module jpegxl

import crypto.sha256
import math

fn test_spline_raster_matches_native_float_images_and_irregular_chunks() {
	mut fixtures := map[string][]string{}
	for line in $embed_file('testdata/spline-cache.tsv').to_string().split_into_lines() {
		if line == '' || line.starts_with('#') { continue }
		f := line.split('\t')
		fixtures[f[0]] = f
	}
	mut count := 0
	mut accepted := 0
	mut words := 0
	mut changes := 0
	mut unchanged := 0
	for line in $embed_file('testdata/spline-raster.tsv').to_string().split_into_lines() {
		if line == '' || line.starts_with('#') { continue }
		gold := line.split('\t')
		f := fixtures[gold[0]]
		set, correlation := raster_fixture_splines(f, gold[1] == '1')
		if cache := set.create_draw_cache(gold[2].int(), gold[3].int(), correlation, f[3] == '1', f[4] == '1') {
			assert gold[4] == 'ok'
			mut bytes := []u8{cap: gold[5].int() * 4}
			mut changed := 0
			for y in 0 .. cache.height {
				mut full := [][]f32{}
				mut chunks := [][]f32{}
				mut background := [][]f32{}
				for c in 0 .. 3 {
					mut samples := []f32{len: cache.width}
					for x in 0 .. cache.width {
						samples[x] = if (gold[0].int() + x + y + c) % 31 == 0 {
							math.f32_from_bits(0x80000000)
						} else {
							f32((gold[0].int() * 11 + x * 5 + y * 7 + c * 3) % 31) / f32(16) - f32(0.5)
						}
					}
					full << samples.clone()
					chunks << samples.clone()
					background << samples
				}
				cache.draw_row(mut full, 0, y)!
				mut x := 0
				for x < cache.width {
					mut size := 1 + (x * 7 + gold[0].int()) % 11
					if size > cache.width - x { size = cache.width - x }
					mut chunk := [][]f32{}
					for c in 0 .. 3 { chunk << chunks[c][x..x + size] }
					cache.draw_row(mut chunk, x, y)!
					x += size
				}
				for c in 0 .. 3 {
					assert full[c].map(math.f32_bits(it)) == chunks[c].map(math.f32_bits(it)), 'Spline raster ${gold[0]}/${gold[1]}, row ${y}, channel ${c}'
					for i, value in full[c] {
						word := math.f32_bits(value)
						if word != math.f32_bits(background[c][i]) { changed++ }
						for shift in [0, 8, 16, 24] { bytes << u8(word >> shift) }
					}
				}
			}
			assert bytes.len == gold[5].int() * 4 && changed == gold[6].int()
			assert sha256.sum(bytes).hex() == gold[7], 'Spline raster ${gold[0]}/${gold[1]}'
			if changed == 0 { unchanged++ }
			words += bytes.len / 4
			changes += changed
			accepted++
		} else {
			assert gold[4] == 'err'
		}
		count++
	}
	assert count == 512 && accepted == 468 && words == 2227200 && changes == 618988 && unchanged == 128
}

fn raster_fixture_splines(f []string, negative bool) (Splines, ColorCorrelationParams) {
	c := f[6].split(',')
	correlation := ColorCorrelationParams{
		color_factor:       c[0].u32()
		base_correlation_x: math.f32_from_bits(c[1].u32())
		base_correlation_b: math.f32_from_bits(c[2].u32())
		ytox_lf:            i32(c[3].int())
		ytob_lf:            i32(c[4].int())
	}
	mut starts := []SplinePoint{}
	for point in f[7].split(';') {
		p := point.split(',').map(math.f32_from_bits(it.u32()))
		starts << SplinePoint{ x: p[0], y: p[1] }
	}
	mut deltas := f[8].split('|')
	if f[8] == '' { deltas = []string{len: starts.len} }
	coefficients := f[9].split('|')
	mut quantized := []QuantizedSpline{}
	for i in 0 .. starts.len {
		mut points := []SplineDelta{}
		if deltas[i] != '' {
			for delta in deltas[i].split(';') {
				points << SplineDelta{ x: delta.all_before(',').i64(), y: delta.all_after(',').i64() }
			}
		}
		values := coefficients[i].split(',').map(i32(it.int()))
		mut color := [3][32]i32{}
		mut sigma := [32]i32{}
		for channel in 0 .. 3 {
			for j in 0 .. 32 { color[channel][j] = values[channel * 32 + j] }
		}
		for j in 0 .. 32 { sigma[j] = if negative { -values[96 + j] } else { values[96 + j] } }
		quantized << QuantizedSpline{ control_points: points, color_dct: color, sigma_dct: sigma }
	}
	return Splines{ quantization_adjustment: i32(f[5].int()), splines: quantized, starting_points: starts }, correlation
}

fn test_spline_raster_checks_rows_before_drawing() {
	set := Splines{}
	cache := set.create_draw_cache(4, 2, ColorCorrelationParams{}, false, false)!
	mut row := [[f32(1), 2], [f32(3), 4], [f32(5), 6]]
	original := row.clone()
	for coordinates in [[-1, 0], [0, -1], [3, 0], [0, 2]] {
		if _ := cache.draw_row(mut row, coordinates[0], coordinates[1]) {
			assert false
		}
		assert row == original
	}
	cache.draw_row(mut row, 1, 1)!
	assert row == original
}
