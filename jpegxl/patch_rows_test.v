module jpegxl

import crypto.sha256
import encoding.hex
import math

fn test_patch_row_application_matches_native_words_and_irregular_chunks() {
	mut packets := map[string][]string{}
	for line in $embed_file('testdata/patch-dictionary.tsv').to_string().split_into_lines() {
		if line == '' || line.starts_with('#') { continue }
		f := line.split('\t')
		packets[f[0]] = f
	}
	mut count := 0
	mut words := 0
	for line in $embed_file('testdata/patch-application.tsv').to_string().split_into_lines() {
		if line == '' || line.starts_with('#') { continue }
		gold := line.split('\t')
		f := packets[gold[0]]
		seed := gold[1].int()
		width := f[2].int()
		height := f[3].int()
		channels := 3 + f[4].int()
		mut refs := []PatchFrameReference{}
		mut geometry := []PatchReferenceInfo{}
		for slot in 0 .. 4 {
			info := PatchReferenceInfo{
				available:                    f[5].int() & (1 << slot) != 0
				saved_before_color_transform: f[6].int() & (1 << slot) != 0
				width:                        32
				height:                       24
			}
			mut planes := []FloatPlane{}
			for c in 0 .. channels {
				mut samples := []f32{len: 32 * 24}
				for y in 0 .. 24 {
					for x in 0 .. 32 {
						samples[y * 32 + x] = f32((slot * 7 + c * 5 + x * 3 + y * 11 + seed) % 25) / f32(16) - f32(0.25)
					}
				}
				planes << FloatPlane{ width: 32, height: 24, samples: samples }
			}
			refs << PatchFrameReference{ info: info, planes: planes }
			geometry << info
		}
		mut reader := new_bit_reader(hex.decode(f[1])!)
		patches := reader.read_patches(width, height, channels - 3, geometry)!
		mut extra := []ExtraChannelInfo{}
		for i in 0 .. channels - 3 {
			extra << ExtraChannelInfo{ kind: .alpha, alpha_associated: gold[2].int() & (1 << i) != 0 }
		}
		mut bytes := []u8{cap: gold[3].int() * 4}
		for y in 0 .. height {
			mut full := [][]f32{}
			mut chunked := [][]f32{}
			for c in 0 .. channels {
				mut samples := []f32{len: width}
				for x in 0 .. width {
					samples[x] = f32((seed + c * 7 + x * 11 + y * 3) % 29) / f32(16) - f32(0.5)
				}
				full << samples
				chunked << samples.clone()
			}
			patches.apply_row(mut full, 0, y, extra, refs)!
			mut x := 0
			for x < width {
				mut size := 1 + (x * 7 + seed) % 11
				if size > width - x { size = width - x }
				mut chunk := [][]f32{}
				for c in 0 .. channels { chunk << chunked[c][x..x + size] }
				patches.apply_row(mut chunk, x, y, extra, refs)!
				x += size
			}
			for c in 0 .. channels {
				assert full[c].map(math.f32_bits(it)) == chunked[c].map(math.f32_bits(it)), 'Patch chunks ${gold[0]}, row ${y}, channel ${c}'
				for value in full[c] {
					word := math.f32_bits(value)
					for shift in [0, 8, 16, 24] { bytes << u8(word >> shift) }
				}
			}
		}
		assert bytes.len == gold[3].int() * 4
		assert sha256.sum(bytes).hex() == gold[4], 'Patch row application ${gold[0]}'
		words += bytes.len / 4
		count++
	}
	assert count == 514 && words == 3121152
}

fn test_patch_rows_validate_stored_planes_before_changing_output() {
	mut packet := []string{}
	for line in $embed_file('testdata/patch-dictionary.tsv').to_string().split_into_lines() {
		if line.starts_with('mode-trunc-zero\t') {
			packet = line.split('\t')
			break
		}
	}
	mut reader := new_bit_reader(hex.decode(packet[1])!)
	info := PatchReferenceInfo{ available: true, saved_before_color_transform: true, width: 32, height: 24 }
	patches := reader.read_patches(48, 32, 0, [info])!
	mut row := [[f32(1), 2, 3, 4], [f32(5), 6, 7, 8], [f32(9), 10, 11, 12]]
	original := row.clone()
	if _ := patches.apply_row(mut row, 0, 0, []ExtraChannelInfo{}, []PatchFrameReference{}) {
		assert false
	}
	assert row == original
	if _ := patches.apply_row(mut row, 0, 0, []ExtraChannelInfo{}, [PatchFrameReference{ info: info }]) {
		assert false
	}
	assert row == original
	// A chunk that only touches the patch's right boundary has no intersection.
	patches.apply_row(mut row, 4, 0, []ExtraChannelInfo{}, []PatchFrameReference{})!
	assert row == original
}
