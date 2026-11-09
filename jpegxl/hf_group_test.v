module jpegxl

import crypto.sha256
import encoding.binary
import encoding.hex

fn hf_group_fixture_digest(maps HfGroupMaps, storage int, inputs []HfGroupInput, coefficients [3][]i32) string {
	mut words := [u32(maps.width), u32(maps.height), u32(storage), u32(inputs.len)]
	for input in inputs { words << [u32(input.pass), u32(input.reader.position)] }
	words << u32(maps.width * maps.height * 64)
	for channel in coefficients {
		for value in channel { words << u32(value) }
	}
	mut bytes := []u8{len: words.len * 4}
	for i, word in words { binary.little_endian_put_u32_at(mut bytes, word, i * 4) }
	return sha256.sum(bytes).hex()
}

fn test_hf_groups_match_source_entropy_channel_order_sampling_and_progressive_passes() {
	mut count := 0
	mut successes := 0
	mut storage_widths := map[int]int{}
	mut shapes := map[int]bool{}
	for line in $embed_file('testdata/hf-groups.tsv').to_string().split_into_lines() {
		if line == '' || line.starts_with('#') { continue }
		f := line.split('\t')
		assert f.len == 14
		maps := HfGroupMaps{
			width: f[1].int()
			height: f[2].int()
			transform_ids: f[6].split(',').map(u8(it.u32()))
			raw_quant: f[7].split(',').map(i32(it.i64()))
			lf_contexts: f[8].split(',').map(u8(it.u32()))
		}
		for id in maps.transform_ids { if id >= 128 { shapes[int(id & 127)] = true } }
		sampling := f[3].split(';')
		h := sampling[0].split(',').map(it.u32())
		v := sampling[1].split(',').map(it.u32())
		shifts := if f[5] == '-' { []u32{} } else { f[5].split(',').map(it.u32()) }
		params := HfGroupParameters{
			horizontal_shift: [h[0], h[1], h[2]]!
			vertical_shift: [v[0], v[1], v[2]]!
			frame_passes: Passes{ count: u32(shifts.len + 1), shifts: shifts }
		}
		mut context_map := []u8{len: 3 * 13 * 3 * 2}
		for i in 0 .. context_map.len { context_map[i] = u8((i * 7 + i / 3) % f[4].int()) }
		block_context := BlockContextMap{
			lf_thresholds: [[i32(0)], []i32{}, []i32{}]!
			qf_thresholds: [u32(2), 5]
			context_map: context_map
			num_lf_contexts: 2
			num_contexts: f[4].int()
		}
		mut inputs := []HfGroupInput{}
		if f[10] != '-' {
			for stream in f[10].split(';') {
				parts := stream.split(':')
				inputs << HfGroupInput{ pass: parts[0].int(), reader: new_bit_reader(hex.decode(parts[1])!) }
			}
		}
		mut coefficients := [3][]i32{}
		for c in 0 .. 3 { coefficients[c] = []i32{len: maps.width * maps.height * 64} }
		mut global_reader := new_bit_reader(hex.decode(f[9])!)
		mut storage := 0
		status := if global := global_reader.read_hf_passes(f[0].u32(), params.frame_passes, f[4].int()) {
			storage = if global.coefficient_storage == .signed16 { 16 } else { 32 }
			if _ := decode_hf_group(maps, params, block_context, global, mut inputs, mut coefficients) { 'ok' } else { 'decode' }
		} else { 'global' }
		assert status == f[12], 'HF group status ${count}: ${status}'
		assert global_reader.position == f[11].int(), 'HF group global cursor ${count}'
		assert hf_group_fixture_digest(maps, storage, inputs, coefficients) == f[13], 'HF group output and cursors ${count}'
		if count >= 94 { assert storage == 16 && coefficients[0].any(it > 0) }
		if status == 'ok' { successes++ }
		storage_widths[storage]++
		count++
	}
	assert count == 96 && successes == 89
	assert shapes.len == 27
	assert storage_widths[16] == 64 && storage_widths[32] == 31 && storage_widths[0] == 1
}

fn hf_group_minimal_global(passes int) !HfPasses {
	mut header := new_bit_reader([u8(0xf2), 1])
	histograms := header.read_histograms(511, true)!
	mut order_reader := new_bit_reader([]u8{})
	orders := order_reader.read_coefficient_orders(0)!
	return HfPasses{
		histogram_sets: 1
		passes: []HfPassState{len: passes, init: HfPassState{ coefficient_orders: orders, histograms: histograms }}
		coefficient_storage: .signed16
	}
}

fn test_hf_group_single_pass_clears_scratch_and_progressive_preserves_prior_coefficients() {
	maps := HfGroupMaps{ width: 1, height: 1, raw_quant: [i32(1)], transform_ids: [u8(128)], lf_contexts: [u8(0)] }
	mut context_header := new_bit_reader([u8(1)])
	context := context_header.read_block_context_map()!
	mut inputs := []HfGroupInput{}
	for passes in [1, 2] {
		mut coefficients := [3][]i32{}
		for c in 0 .. 3 { coefficients[c] = []i32{len: 64, init: i32(c + 1)} }
		decode_hf_group(maps, HfGroupParameters{ frame_passes: Passes{ count: u32(passes) } }, context,
			hf_group_minimal_global(passes)!, mut inputs, mut coefficients)!
		for c in 0 .. 3 { assert coefficients[c].all(it == if passes == 1 { 0 } else { c + 1 }) }
	}
}

fn test_hf_group_invalid_metadata_is_rejected_before_consuming_input_or_clearing_buffers() {
	mut context_header := new_bit_reader([u8(1)])
	context := context_header.read_block_context_map()!
	global := hf_group_minimal_global(1)!
	for maps in [
		HfGroupMaps{ width: 1, height: 1, raw_quant: [i32(0)], transform_ids: [u8(128)], lf_contexts: [u8(0)] },
		HfGroupMaps{ width: 1, height: 1, raw_quant: [i32(1)], transform_ids: [u8(0)], lf_contexts: [u8(0)] },
		HfGroupMaps{ width: 1, height: 1, raw_quant: [i32(1)], transform_ids: [u8(155)], lf_contexts: [u8(0)] },
		HfGroupMaps{ width: 1, height: 1, raw_quant: [i32(1)], transform_ids: [u8(132)], lf_contexts: [u8(0)] },
		HfGroupMaps{ width: 1, height: 1, raw_quant: [i32(1)], transform_ids: [u8(128)], lf_contexts: [u8(1)] },
	] {
		mut coefficients := [3][]i32{}
		for c in 0 .. 3 { coefficients[c] = []i32{len: 64, init: 7} }
		mut inputs := [HfGroupInput{ reader: new_bit_reader([u8(0)]) }]
		if _ := decode_hf_group(maps, HfGroupParameters{}, context, global, mut inputs, mut coefficients) { assert false }
		assert inputs[0].reader.position == 0
		for channel in coefficients { assert channel.all(it == 7) }
	}
}
