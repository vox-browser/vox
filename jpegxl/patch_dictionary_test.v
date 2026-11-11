module jpegxl

import crypto.sha256
import encoding.hex

fn test_patch_dictionary_matches_native_fields_consumption_and_ordered_rows() {
	mut count := 0
	mut accepted := 0
	mut modes := []bool{len: 8}
	mut maximum := 0
	for line in $embed_file('testdata/patch-dictionary.tsv').to_string().split_into_lines() {
		if line == '' || line.starts_with('#') { continue }
		f := line.split('\t')
		mut refs := []PatchReferenceInfo{cap: 4}
		for slot in 0 .. 4 {
			refs << PatchReferenceInfo{
				available:                    f[5].int() & (1 << slot) != 0
				saved_before_color_transform: f[6].int() & (1 << slot) != 0
				width:                        32
				height:                       24
			}
		}
		mut reader := new_bit_reader(hex.decode(f[1])!)
		if patches := reader.read_patches(f[2].int(), f[3].int(), f[4].int(), refs) {
			assert f[7] != 'err', f[0]
			assert reader.position == f[7].int(), f[0]
			assert patches.blendings_stride == f[4].int() + 1
			assert patches.positions.len == f[12].int()
			assert patches.references.len == f[13].int()
			assert patches.blendings.len == f[14].int()
			positions := patches.positions.map('${it.x},${it.y},${it.reference}').join(';')
			references := patches.references.map('${it.reference},${it.x0},${it.y0},${it.width},${it.height}').join(';')
			mut blend_fields := []string{}
			for blending in patches.blendings {
				clamp := if blending.clamp { 1 } else { 0 }
				blend_fields << '${int(blending.mode)},${blending.alpha_channel},${clamp}'
			}
			blends := blend_fields.join(';')
			mut rows := []string{}
			for y in 0 .. f[3].int() + 2 {
				rows << patches.patches_for_row(y).map(it.str()).join(',')
			}
			for i, fields in [positions, references, blends, rows.join(';')] {
				assert sha256.sum(fields.bytes()).hex() == f[8 + i], 'Patch dictionary ${f[0]}, field ${i}'
			}
			assert patches.patches_for_row(-1).len == 0
			for blend in patches.blendings { modes[int(blend.mode)] = true }
			if patches.positions.len > maximum { maximum = patches.positions.len }
			accepted++
		} else {
			assert f[7] == 'err', 'Rejected native patch dictionary ${f[0]}: ${err.msg()}'
		}
		count++
	}
	assert count == 678 && accepted == 514 && maximum == 5632 && modes.all(it)
}

fn test_patch_dictionary_rejects_invalid_api_dimensions_before_entropy() {
	for dimensions in [[-1, 1, 0], [1, 0, 0], [65536, 65536, 0], [1, 1, -1], [1, 1, 257]] {
		mut reader := new_bit_reader([]u8{})
		if _ := reader.read_patches(dimensions[0], dimensions[1], dimensions[2], []PatchReferenceInfo{}) {
			assert false
		}
		assert reader.position == 0
	}
}
