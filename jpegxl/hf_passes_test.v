module jpegxl

import crypto.sha256
import encoding.binary
import encoding.hex

fn hf_pass_fixture_word(mut data []u8, offset int, word u32) int {
	binary.little_endian_put_u32_at(mut data, word, offset)
	return offset + 4
}

fn hf_pass_fixture_digest(state HfPasses) !string {
	mut words := 3
	for pass in state.passes {
		words++
		for order in pass.coefficient_orders { words += 1 + order.values.len }
		words += 5 + pass.histograms.context_map.len + pass.histograms.num_histograms()
	}
	mut data := []u8{len: words * 4}
	mut offset := 0
	for value in [state.histogram_sets, u32(if state.coefficient_storage == .signed16 { 16 } else { 32 }), u32(state.passes.len)] {
		offset = hf_pass_fixture_word(mut data, offset, value)
	}
	for pass in state.passes {
		offset = hf_pass_fixture_word(mut data, offset, u32(pass.coefficient_orders.len))
		for order in pass.coefficient_orders {
			offset = hf_pass_fixture_word(mut data, offset, u32(order.values.len))
			for value in order.values { offset = hf_pass_fixture_word(mut data, offset, value) }
		}
		histograms := pass.histograms
		for value in [u32(histograms.num_histograms()), u32(histograms.max_num_bits()!),
			u32(if histograms.can_use_config_420_fast_path() { 1 } else { 0 }),
			u32(if histograms.is_rle() { 1 } else { 0 }), u32(histograms.context_map.len)] {
			offset = hf_pass_fixture_word(mut data, offset, value)
		}
		for value in histograms.context_map { offset = hf_pass_fixture_word(mut data, offset, u32(value)) }
		for c in 0 .. histograms.num_histograms() {
			offset = hf_pass_fixture_word(mut data, offset, histograms.single_symbol(c) or { u32(0xffffffff) })
		}
	}
	assert offset == data.len
	return sha256.sum(data).hex()
}

fn test_hf_pass_headers_match_source_orders_histograms_padding_and_storage() {
	mut count := 0
	mut successes := 0
	mut excess_sets := 0
	mut widths := map[int]bool{}
	for line in $embed_file('testdata/hf-passes.tsv').to_string().split_into_lines() {
		if line == '' || line.starts_with('#') { continue }
		f := line.split('\t')
		assert f.len == 7
		shifts := if f[2] == '-' { []u32{} } else { f[2].split(',').map(it.u32()) }
		passes := Passes{ count: f[1].u32(), shifts: shifts }
		bytes := hex.decode(f[4])!
		mut input := new_bit_reader(bytes)
		actual := if state := input.read_hf_passes(f[0].u32(), passes, f[3].int()) {
			assert state.passes.len == int(passes.count)
			for pass in state.passes { assert pass.coefficient_orders.len == 39 }
			widths[int(state.coefficient_storage)] = true
			if state.histogram_sets > f[0].u32() { excess_sets++ }
			if count == 32 { assert state.coefficient_storage == .signed16 }
			if count == 33 { assert state.coefficient_storage == .signed32 }
			successes++
			hf_pass_fixture_digest(state)!
		} else { 'err' }
		assert actual == f[6], 'HF pass header ${count}'
		assert input.position == f[5].int(), 'HF pass cursor ${count}'
		count++
	}
	assert count == 66
	assert successes == 34
	assert excess_sets > 0
	assert widths.len == 2
}

fn test_hf_passes_validate_dimensions_and_bound_context_allocation() {
	for groups in [u32(0), 65537] {
		mut reader := new_bit_reader([]u8{})
		if _ := reader.read_hf_passes(groups, Passes{}, 1) { assert false }
		assert reader.position == 0
	}
	for passes in [Passes{ count: 0 }, Passes{ count: 12 },
		Passes{ count: 1, shifts: [u32(1)] }, Passes{ count: 2, shifts: [u32(4)] }] {
		mut reader := new_bit_reader([]u8{})
		if _ := reader.read_hf_passes(1, passes, 1) { assert false }
		assert reader.position == 0
	}
	for contexts in [0, 17] {
		mut reader := new_bit_reader([]u8{})
		if _ := reader.read_hf_passes(1, Passes{}, contexts) { assert false }
		assert reader.position == 0
	}
	mut excessive := new_bit_reader([u8(255), 255])
	if _ := excessive.read_hf_passes(65536, Passes{}, 16) { assert false }
	assert excessive.position == 16
}
