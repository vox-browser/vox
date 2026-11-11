module jpegxl

import math

fn test_patch_blending_matches_native_float_words_across_modes_and_extra_channels() {
	mut count := 0
	mut words := 0
	for line in $embed_file('testdata/patch-blending.tsv').to_string().split_into_lines() {
		if line == '' || line.starts_with('#') { continue }
		f := line.split('\t')
		extras := f[1].int()
		width := f[2].int()
		mut info := []ExtraChannelInfo{}
		for i in 0 .. extras {
			info << ExtraChannelInfo{
				kind:             if f[3].int() & (1 << i) != 0 { .alpha } else { .depth }
				alpha_associated: f[4].int() & (1 << i) != 0
			}
		}
		color := parse_patch_blending_record(f[5])
		mut extra := []PatchBlending{}
		if f[6] != '' {
			for record in f[6].split(';') { extra << parse_patch_blending_record(record) }
		}
		bg := f[7].split(',').map(math.f32_from_bits(it.u32()))
		fg := f[8].split(',').map(math.f32_from_bits(it.u32()))
		mut background := [][]f32{}
		mut foreground := [][]f32{}
		for c in 0 .. 3 + extras {
			background << bg[c * width..(c + 1) * width].clone()
			foreground << fg[c * width..(c + 1) * width].clone()
		}
		blend_patch_rows(mut background, foreground, color, extra, info)!
		mut actual := []u32{}
		for row in background { actual << row.map(math.f32_bits(it)) }
		expected := f[9].split(',').map(it.u32())
		assert actual == expected, 'Patch blending ${f[0]}'
		count++
		words += actual.len
	}
	assert count == 1024 && words == 32640
}

fn parse_patch_blending_record(record string) PatchBlending {
	f := record.split(',')
	return PatchBlending{ mode: unsafe { PatchBlendMode(f[0].int()) }, alpha_channel: f[1].int(), clamp: f[2] == '1' }
}

fn test_patch_blending_validates_rows_before_mutating_them() {
	mut background := [[f32(1)], [f32(2)], [f32(3)]]
	original := background.clone()
	if _ := blend_patch_rows(mut background, [[f32(0)]], PatchBlending{}, []PatchBlending{}, []ExtraChannelInfo{}) {
		assert false
	}
	assert background == original
	mut mismatched := [[f32(0)], [f32(0)], [f32(0), 1]]
	if _ := blend_patch_rows(mut background, mismatched, PatchBlending{}, []PatchBlending{}, []ExtraChannelInfo{}) {
		assert false
	}
	assert background == original
	mut foreground := [[f32(0)], [f32(0)], [f32(0)]]
	foreground[2][0] = math.f32_from_bits(0x7fc00001)
	if _ := blend_patch_rows(mut background, foreground, PatchBlending{}, []PatchBlending{}, []ExtraChannelInfo{}) {
		assert false
	}
	assert background == original
}
