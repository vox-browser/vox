module jpegxl

import encoding.hex

fn test_entropy_checkpoints_and_replay_match_pinned_source() {
	mut count := 0
	for line in $embed_file('testdata/entropy-checkpoint.tsv').to_string().split_into_lines() {
		if line == '' || line.starts_with('#') { continue }
		fields := line.split('\t')
		assert fields.len == 7
		contexts := fields[0].int()
		mut input := new_bit_reader(hex.decode(fields[4])!)
		mut hist := input.read_histograms(contexts, fields[1] == '1')!
		if fields[3] != '0' { hist.resize(fields[3].int())! }
		width := if fields[2] == '0' { ?u32(none) } else { ?u32(u32(fields[2].u64())) }
		mut reader := SymbolReader.new(hist, mut input, width)!
		mut warm := []string{}
		for i in 0 .. 4 { warm << reader.read_unsigned(&hist, i % contexts, mut input)!.str() }
		checkpoint := reader.checkpoint(16)!
		cursor := input
		mut first := []u32{}
		for i in 0 .. 8 { first << reader.read_unsigned(&hist, i % contexts, mut input)! }
		position := input.position
		reader.restore(checkpoint)!
		input = cursor
		mut replay := []string{}
		for i in 0 .. 8 {
			value := reader.read_unsigned(&hist, i % contexts, mut input)!
			assert value == first[i], 'Checkpoint case ${count}'
			replay << value.str()
		}
		assert input.position == position && position == fields[5].int()
		valid := if _ := reader.check_final_state(hist, input) { 1 } else { 0 }
		assert '${warm.join(',')}|${replay.join(',')}|${valid}' == fields[6], 'Checkpoint case ${count}'
		count++
	}
	assert count == 84
}

fn test_checkpoint_restores_wrapped_window_and_pending_copy_state() {
	mut reader := SymbolReader{ lz77_enabled: true }
	for i in 0 .. lz77_window_size - 4 { reader.lz77.push(u32(i)) }
	reader.lz77.apply_copy(1, 24)
	checkpoint := reader.checkpoint(16)!
	mut expected := []u32{}
	for _ in 0 .. 16 {
		value := reader.lz77.pull()?
		expected << value
		reader.lz77.push(value)
	}
	assert reader.lz77.window.len == lz77_window_size
	reader.repeat_error = true
	reader.overflow_error = true
	reader.ans.state = 0
	reader.restore(checkpoint)!
	assert !reader.repeat_error && !reader.overflow_error
	assert reader.ans.state == 0x130000
	assert reader.lz77.decoded == u32(lz77_window_size - 4)
	assert reader.lz77.to_copy == 24
	for value in expected {
		assert reader.lz77.pull()? == value
		reader.lz77.push(value)
	}
	assert reader.lz77.to_copy == 8
}

fn test_checkpoint_bounds_and_type_errors_leave_state_untouched() {
	mut reader := SymbolReader{ lz77_enabled: true }
	reader.lz77.push(17)
	checkpoint := reader.checkpoint(1)!
	reader.lz77.push(18)
	reader.lz77.push(19)
	if _ := reader.restore(checkpoint) {
		assert false
	}
	assert reader.lz77.decoded == 3
	assert reader.lz77.window[..3] == [u32(17), 18, 19]
	mut plain := SymbolReader{}
	if _ := plain.restore(checkpoint) {
		assert false
	}
	assert plain.ans.state == 0x130000
	for bound in [-1, lz77_window_size + 1] {
		if _ := reader.checkpoint(bound) {
			assert false
		}
	}
	zero := reader.checkpoint(0)!
	reader.restore(zero)!
}
