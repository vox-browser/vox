module jpegxl

import encoding.hex

fn ans_fixture_result(log_alphabet_size int, contexts int, mut reader BitReader) !string {
	codes := reader.read_ans_codes(contexts, log_alphabet_size)!
	mut maximum := []string{}
	mut single := []string{}
	for context in 0 .. contexts {
		maximum << codes.max_symbol_for_cluster(context)!.str()
		single << if symbol := codes.single_symbol(context) { symbol.str() } else { '-' }
	}
	mut ans := reader.read_ans_state()!
	mut output := []string{cap: 32}
	for i in 0 .. 32 { output << ans.read(codes, i % contexts, mut reader)!.str() }
	end := if _ := reader.check_end() { 1 } else { 0 }
	checksum := if _ := ans.check_final_state() { 1 } else { 0 }
	return '${maximum.join(',')}|${single.join(',')}|${output.join(',')}|AnsReader(${ans.state})|${end}|${checksum}'
}

fn test_ans_tables_symbols_and_state_match_frozen_source() {
	mut count := 0
	mut successful := 0
	for line in $embed_file('testdata/ans.tsv').to_string().split_into_lines() {
		if line == '' || line.starts_with('#') { continue }
		fields := line.split('\t')
		assert fields.len == 5
		mut reader := new_bit_reader(hex.decode(fields[2])!)
		actual := ans_fixture_result(fields[0].int(), fields[1].int(), mut reader) or { 'err' }
		assert actual == fields[4], 'ANS case ${count}'
		assert reader.position == fields[3].int(), 'ANS case ${count}: position ${reader.position}, expected ${fields[3]}'
		if actual != 'err' { successful++ }
		count++
	}
	assert count == 4096
	assert successful > 1000
}

fn test_ans_alias_maps_match_every_state_position_from_source() {
	mut histograms := 0
	for line in $embed_file('testdata/ans-alias.tsv').to_string().split_into_lines() {
		if line == '' || line.starts_with('#') { continue }
		fields := line.split('\t')
		assert fields.len == 4
		mut header := new_bit_reader(hex.decode(fields[1])!)
		codes := header.read_ans_codes(1, fields[0].int())!
		assert header.position == fields[2].int()
		expected := fields[3].split(';')
		assert expected.len == 4096
		for index in 0 .. 4096 {
			mut ans := AnsReader{ state: u32(0x130000 | index) }
			mut input := new_bit_reader([u8(0x5a), 0xc3])
			symbol := ans.read(codes, 0, mut input)!
			assert '${symbol},${ans.state},${input.position}' == expected[index], 'Histogram ${histograms}, alias position ${index}'
			input.check_end()!
		}
		histograms++
	}
	assert histograms == 12
}

fn test_ans_single_two_and_uniform_distributions_preserve_invariants() {
	mut single_input := new_bit_reader([u8(0x25), 1])
	codes := single_input.read_ans_codes(1, 5)!
	assert codes.single_symbol(0)? == 20
	assert codes.max_symbol_for_cluster(0)! == 20
	mut ans := AnsReader{}
	mut no_input := new_bit_reader([]u8{})
	for _ in 0 .. 100 {
		assert ans.read(codes, 0, mut no_input)! == 20
	}
	ans.check_final_state()!
	assert no_input.position == 0
	mut invalid := new_bit_reader([u8(0x2d), 0])
	if _ := invalid.read_ans_codes(1, 5) {
		assert false
	}
	mut two_input := new_bit_reader([u8(0x9f), 0x92, 0, 2])
	two := two_input.read_ans_codes(1, 5)!
	assert two.histograms[0].buckets[10].distance == 256
	assert two.histograms[0].buckets[20].distance == 4096 - 256
	mut total := 0
	for bucket in two.histograms[0].buckets { total += int(bucket.distance) }
	assert total == 4096
	assert two.single_symbol(0) == none
	if _ := two.max_symbol_for_cluster(-1) {
		assert false
	}
	if _ := ans.read(two, 1, mut no_input) {
		assert false
	}
	for contexts in [0, 65537] {
		if _ := no_input.read_ans_codes(contexts, 5) {
			assert false
		}
	}
	for size in [4, 9] {
		if _ := no_input.read_ans_codes(1, size) {
			assert false
		}
	}
}

fn test_ans_state_init_checks_truncation_and_checksum() {
	for length in 0 .. 4 {
		mut input := new_bit_reader([u8(0), 0, 0x13, 0][..length])
		if _ := input.read_ans_state() {
			assert false
		}
	}
	mut valid := new_bit_reader([u8(0), 0, 0x13, 0])
	state := valid.read_ans_state()!
	state.check_final_state()!
	assert valid.position == 32
	bad := AnsReader{ state: 0 }
	if _ := bad.check_final_state() {
		assert false
	}
}
