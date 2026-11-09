module jpegxl

import crypto.sha256
import encoding.binary

fn hf_metadata_fixture_digest(metadata HfMetadata) string {
	mut words := [u32(metadata.width), u32(metadata.height)]
	for value in metadata.colors.y_to_x { words << u32(value) }
	for value in metadata.colors.y_to_b { words << u32(value) }
	for value in metadata.raw_quant { words << u32(value) }
	for value in metadata.transform_ids { words << u32(value) }
	for value in metadata.sharpness { words << u32(value) }
	mut bytes := []u8{len: words.len * 4}
	for i, value in words { binary.little_endian_put_u32_at(mut bytes, value, i * 4) }
	return sha256.sum(bytes).hex()
}

fn test_hf_metadata_maps_match_source_color_clamping_quantization_and_group_boundaries() {
	mut count := 0
	mut accepted := 0
	mut words := 0
	mut shapes := map[int]bool{}
	for line in $embed_file('testdata/hf-metadata.tsv').to_string().split_into_lines() {
		if line == '' || line.starts_with('#') { continue }
		f := line.split('\t')
		assert f.len == 12
		w := f[0].int()
		h := f[1].int()
		storage := if f[3] == '16' { ModularStorage.signed16 } else { ModularStorage.signed32 }
		n := f[4].int()
		mut transforms := f[7].split(',').map(i32(it.i64()))
		transforms << f[8].split(',').map(i32(it.i64()))
		inputs := [
			ModularChannel{ width: (w + 7) / 8, height: (h + 7) / 8, samples: f[5].split(',').map(i32(it.i64())) },
			ModularChannel{ width: (w + 7) / 8, height: (h + 7) / 8, samples: f[6].split(',').map(i32(it.i64())) },
			ModularChannel{ width: n, height: 2, samples: transforms },
			ModularChannel{ width: w, height: h, samples: f[9].split(',').map(i32(it.i64())) },
		]
		actual := if result := reconstruct_hf_metadata(inputs, w, h, n, f[2] == '1', storage) {
			assert f[10] == 'ok', 'HF metadata status ${count}'
			for id in result.transform_ids { if id >= 128 { shapes[int(id & 127)] = true } }
			words += 2 + result.colors.y_to_x.len * 2 + result.raw_quant.len * 3
			accepted++
			hf_metadata_fixture_digest(result)
		} else {
			assert f[10] == 'err', 'HF metadata error ${count}: ${err}'
			sha256.sum([]u8{}).hex()
		}
		assert actual == f[11], 'HF metadata maps ${count}'
		count++
	}
	assert count == 256
	assert accepted == 208
	assert shapes.len == 27
	assert words == 773525
}

fn test_hf_metadata_checks_channel_geometry_and_preserves_unused_transform_records() {
	inputs := [ModularChannel{ width: 1, height: 1, samples: [i32(0)] },
		ModularChannel{ width: 1, height: 1, samples: [i32(0)] },
		ModularChannel{ width: 2, height: 2, samples: [i32(0), 27, -1, 255] },
		ModularChannel{ width: 1, height: 1, samples: [i32(7)] }]
	metadata := reconstruct_hf_metadata(inputs, 1, 1, 2, true, .signed32)!
	assert metadata.transform_ids == [u8(128)]
	assert metadata.raw_quant == [i32(1)] && metadata.sharpness == [u8(7)]
	for dimensions in [[0, 1, 2], [1, 0, 2], [257, 1, 2], [1, 257, 2], [1, 1, 0], [1, 1, 65537], [2, 1, 2]] {
		if _ := reconstruct_hf_metadata(inputs, dimensions[0], dimensions[1], dimensions[2], true, .signed32) { assert false }
	}
	if _ := reconstruct_hf_metadata(inputs[..3], 1, 1, 2, true, .signed32) { assert false }
}
