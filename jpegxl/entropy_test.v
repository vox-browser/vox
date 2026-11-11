module jpegxl

import encoding.hex

fn entropy_fixture_result(contexts int, allow_lz77 bool, width u32, reads int, resize int, mut input BitReader) !string {
	mut hist := input.read_histograms(contexts, allow_lz77)!
	if resize != 0 { hist.resize(resize)! }
	count := hist.num_histograms()
	info := '${count},${hist.max_num_bits()!},${if hist.is_rle() { 1 } else { 0 }},${if hist.can_use_config_420_fast_path() {
		1
	} else {
		0
	}}'
	mut map_ := []string{}
	for i in 0 .. if resize == 0 { contexts } else { resize } {
		map_ << hist.map_context_to_cluster(i)!.str()
	}
	mut single := []string{}
	for i in 0 .. count { single << if value := hist.single_symbol(i) { value.str() } else { '-' } }
	optional_width := if width == 0 { ?u32(none) } else { ?u32(width) }
	mut symbols := SymbolReader.new(hist, mut input, optional_width)!
	mut values := []string{}
	for i in 0 .. reads { values << symbols.read_unsigned(&hist, i % contexts, mut input)!.str() }
	valid := if _ := symbols.check_final_state(hist, input) { 1 } else { 0 }
	return '${info}|${map_.join(',')}|${single.join(',')}|${values.join(',')}|${valid}'
}

fn test_combined_entropy_reader_matches_every_source_record() {
	mut count := 0
	mut successful := 0
	for line in $embed_file('testdata/entropy.tsv').to_string().split_into_lines() {
		if line == '' || line.starts_with('#') { continue }
		fields := line.split('\t')
		assert fields.len == 8
		mut input := new_bit_reader(hex.decode(fields[5])!)
		mut diagnosis := ''
		actual := entropy_fixture_result(fields[0].int(), fields[1] == '1', u32(fields[2].u64()), fields[3].int(), fields[4].int(), mut input) or {
			diagnosis = err.msg()
			'err'
		}
		assert actual == fields[7], 'Entropy case ${count}: ${actual}, expected ${fields[7]}'
		assert input.position == fields[6].int(), 'Entropy case ${count}: position ${input.position}, expected ${fields[6]}: ${diagnosis}'
		if actual != 'err' { successful++ }
		count++
	}
	assert count == 5656
	assert successful > 1500
}

fn test_context_maps_match_simple_nested_and_mtf_source_records() {
	mut count := 0
	mut successful := 0
	for line in $embed_file('testdata/context-map.tsv').to_string().split_into_lines() {
		if line == '' || line.starts_with('#') { continue }
		fields := line.split('\t')
		assert fields.len == 4
		mut input := new_bit_reader(hex.decode(fields[1])!)
		actual := if values := input.read_context_map(fields[0].int()) {
			values.map(it.str()).join(',')
		} else {
			'err'
		}
		assert actual == fields[3], 'Context map case ${count}'
		assert input.position == fields[2].int(), 'Context map case ${count}: position ${input.position}, expected ${fields[2]}'
		if actual != 'err' { successful++ }
		count++
	}
	assert count == 4098
	assert successful > 500
}

fn test_context_map_holes_and_highest_cluster_validation() {
	verify_context_map([u8(0), 1, 1, 0])!
	if _ := verify_context_map([u8(0), 2]) {
		assert false
	}
	if _ := verify_context_map([u8(1)]) {
		assert false
	}
	mut all := []u8{len: 256}
	for i in 0 .. 256 { all[i] = u8(i) }
	verify_context_map(all)!
	mut mtf := [u8(0), 1, 1, 0, 2, 2]
	inverse_move_to_front(mut mtf)
	assert mtf == [u8(0), 1, 0, 0, 2, 1]
	mut input := new_bit_reader([]u8{})
	for contexts in [0, 65538, -1] {
		if _ := input.read_context_map(contexts) {
			assert false
		}
	}
	for contexts in [0, 65537, -1] {
		if _ := input.read_histograms(contexts, true) {
			assert false
		}
	}
}

fn test_lz77_window_wrap_and_overlapping_copies_are_bounded() {
	mut state := Lz77State{}
	for i in 0 .. lz77_window_size + 16 { state.push(u32(i)) }
	assert state.window.len == lz77_window_size
	state.apply_copy(0, 3)
	for _ in 0 .. 3 {
		value := state.pull()?
		assert value == u32(lz77_window_size + 15)
		state.push(value)
	}
	assert state.pull() == none
	state.apply_copy(u32(0xffffffff), 1)
	assert state.pull()? == state.window[int((state.decoded - u32(lz77_window_size)) & lz77_window_mask)]
}
