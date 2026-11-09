module jpegxl

import encoding.hex

fn decode_channel_spec(text string) ![]ModularChannel {
	mut channels := []ModularChannel{}
	for item in text.split(';') {
		fields := item.split(',')
		assert fields.len == 4
		shift := if fields[2] == '-1' {
			?ModularShift(none)
		} else {
			?ModularShift(ModularShift{ horizontal: fields[2].u32(), vertical: fields[3].u32() })
		}
		channels << ModularChannel.new(fields[0].int(), fields[1].int(), shift)!
	}
	return channels
}

fn test_modular_channel_samples_validity_and_consumed_bits_match_source() {
	mut cases := 0
	mut accepted := 0
	for line in $embed_file('testdata/modular-channels.tsv').to_string().split_into_lines() {
		if line == '' || line.starts_with('#') { continue }
		f := line.split('\t')
		assert f.len == 8
		storage := if f[0] == '16' { ModularStorage.signed16 } else { ModularStorage.signed32 }
		mut wp_reader := new_bit_reader(hex.decode(f[2])!)
		header := wp_reader.read_weighted_predictor_header()!
		mut channels := decode_channel_spec(f[3])!
		mut reader := new_bit_reader(hex.decode(f[4])!)
		mut tree := reader.read_modular_tree(31)!
		if f[5] != '-' {
			reader = new_bit_reader(hex.decode(f[5])!)
			histograms := reader.read_histograms((tree.nodes.len + 1) / 2, true)!
			tree = ModularTree{ ...tree, histograms: histograms }
		}
		mut valid := 1
		reader.decode_modular_channels(mut channels, f[1].u32(), header, tree, storage) or { valid = 0 }
		actual := '${valid}|${channels.map(it.samples.map(it.str()).join(',')).join(';')}'
		assert actual == f[7], 'Modular channel source case ${cases}'
		assert reader.position == f[6].int(), 'Modular channel bit position ${cases}: ${reader.position}, expected ${f[6]}'
		if valid == 1 { accepted++ }
		cases++
	}
	assert cases == 952 && accepted == 924
}

fn test_reference_rows_match_nearest_compatible_channels_and_zero_missing_values() {
	mut channels := decode_channel_spec('2,2,0,0;2,2,1,0;2,2,0,0;2,2,-1,-1;2,2,0,0')!
	channels[0].samples = [i32(1), 3, 4, 8]
	channels[1].samples = [i32(99), 99, 99, 99]
	channels[2].samples = [i32(-2), -4, -7, -9]
	channels[3].samples = [i32(99), 99, 99, 99]
	mut references := []i32{len: 24, init: 99}
	prepare_modular_references(channels, 4, 1, 12, .signed32, mut references)!
	assert references == [i32(7), -7, 5, -5, 4, 4, 3, 3, 0, 0, 0, 0, 9, -9, 2, -2, 8, 8, 4, 4,
		0, 0, 0, 0]
	prepare_modular_references(channels, 0, 0, 12, .signed32, mut references)!
	assert references.all(it == 0)
	channels[0].samples = [i32(65535), 65536, 0, 0]
	mut narrow := []i32{len: 8}
	prepare_modular_references(channels, 2, 0, 4, .signed16, mut narrow)!
	assert narrow == [i32(1), -1, 1, -1, 0, 0, 1, 1]
}

fn test_modular_decoder_rejects_invalid_buffers_and_keeps_empty_channel_numbering() {
	for shape in [[-1, 1]!, [1, -1]!, [1048577, 1]!, [1, 1048577]!, [65536, 65536]!] {
		if _ := ModularChannel.new(shape[0], shape[1], none) {
			assert false
		}
	}
	mut empty_reader := new_bit_reader([])
	mut empty := [ModularChannel.new(65536, 0, none)!, ModularChannel.new(0, 8, none)!]
	empty_reader.decode_modular_channels(mut empty, 0, WeightedPredictorHeader{}, ModularTree{}, .signed32)!
	assert empty_reader.position == 0
	mut bad := [ModularChannel{ width: 1, height: 1 }]
	mut rejected := false
	empty_reader.decode_modular_channels(mut bad, 0, WeightedPredictorHeader{}, ModularTree{}, .signed32) or { rejected = true }
	assert rejected && empty_reader.position == 0
	mut channels := [ModularChannel.new(1, 1, none)!]
	channels[0].samples[0] = 7
	rejected = false
	empty_reader.decode_modular_channels(mut channels, 0, WeightedPredictorHeader{}, ModularTree{}, .signed32) or { rejected = true }
	assert rejected && channels[0].samples == [i32(7)]
	for request in [[-1, 0, 4]!, [1, 0, 4]!, [0, -1, 4]!, [0, 1, 4]!, [0, 0, 3]!, [0, 0, 244]!] {
		mut refs := [i32(9), 9, 9, 9]
		rejected = false
		prepare_modular_references(channels, request[0], request[1], request[2], .signed32, mut refs) or { rejected = true }
		assert rejected && refs.all(it == 9)
	}
}
