module libjs

fn test_regex_scan_execution_writes_only_a_successful_capture_pair_and_preserves_tail() {
	input := RegexInput(RegexAsciiInput{
		bytes: [u8(0x61), 0x41, 0x41]
	})
	mut output := [i32(91), 92, 93, 94]
	assert !regex_execute_simple_scan_into(RegexProgram{ ignore_case: true }, input, 0, RegexLiteral{
		code_point: 0x42
	}, mut output)
	assert output == [i32(91), 92, 93, 94]
	assert regex_execute_simple_scan_into(RegexProgram{ ignore_case: true }, input, 0, RegexLiteral{
		code_point: 0x41
	}, mut output)
	assert output == [i32(1), 2, 93, 94]
	assert !regex_execute_simple_scan_into(RegexProgram{}, input, 3,
		RegexBuiltinCharacterClass.word, mut output)
	assert !regex_execute_simple_scan_into(RegexProgram{}, input, 4,
		RegexBuiltinCharacterClass.word, mut output)
	assert output == [i32(1), 2, 93, 94]
}

fn test_regex_scan_execution_decodes_pairs_but_retains_a_requested_low_surrogate_start() {
	input := RegexInput(RegexUtf16Input{
		units: [u16(0xd801), 0xdc00, 0x41, 0xd801, 0xdc00]
	})
	program := RegexProgram{
		unicode: true
	}
	mut output := [i32(-1), -1]
	assert regex_execute_simple_scan_into(program, input, 0, RegexLiteral{ code_point: 0x10400 }, mut
		output)
	assert output == [i32(0), 2]
	assert !regex_execute_simple_scan_into(program, input, 0, RegexLiteral{ code_point: 0xdc00 }, mut
		output)
	assert regex_execute_simple_scan_into(program, input, 1, RegexLiteral{ code_point: 0xdc00 }, mut
		output)
	assert output == [i32(1), 2]
	assert regex_execute_simple_scan_into(RegexProgram{}, input, 0, RegexLiteral{ code_point: 0xdc00 }, mut
		output)
	assert output == [i32(1), 2]
}

fn test_regex_greedy_scan_enforces_code_point_counts_and_skips_insufficient_runs() {
	program := RegexProgram{
		unicode: true
	}
	input := RegexInput(RegexUtf16Input{
		units: [u16(0xd801), 0xdc00, 0x20, 0xd801, 0xdc00, 0xd801, 0xdc00, 0xd801, 0xdc00]
	})
	matcher := RegexSimpleMatch(RegexLiteral{
		code_point: 0x10400
	})
	mut output := [i32(-1), -1, 99]
	assert regex_execute_simple_greedy_scan_into(program, input, 0, matcher, 2, u32(2), mut output)
	assert output == [i32(3), 7, 99]
	assert regex_execute_simple_scan_into(program, input, 0, RegexGreedyLoop{
		matcher: matcher
		min:     2
	}, mut output)
	assert output == [i32(3), 9, 99]
	assert !regex_execute_simple_greedy_scan_into(program, input, 0, matcher, 4, none, mut output)
	assert output == [i32(3), 9, 99]
}

fn test_regex_greedy_scan_zero_bounds_preserve_source_nonmatching_and_end_behavior() {
	input := RegexInput(RegexAsciiInput{
		bytes: [u8(0x20), 0x61, 0x62, 0x20]
	})
	scan := RegexSimpleScan(RegexGreedyLoop{
		matcher: RegexBuiltinCharacterClass.word
		min:     0
		max:     u32(0)
	})
	mut output := [i32(99), 100]
	assert regex_execute_simple_scan_into(RegexProgram{}, input, 0, scan, mut output)
	assert output == [i32(1), 1]
	assert !regex_execute_simple_scan_into(RegexProgram{}, input, 3, scan, mut output)
	assert !regex_execute_simple_scan_into(RegexProgram{}, input, 4, scan, mut output)
	assert !regex_execute_simple_scan_into(RegexProgram{}, RegexAsciiInput{}, 0, scan, mut output)
	assert output == [i32(1), 1]
	mut all := [i32(99), 99, 99, 99, 99]
	assert regex_find_all_simple_scan(RegexProgram{}, input, 0, scan, mut all) == 2
	assert all == [i32(1), 1, 2, 2, 99]
}

fn test_regex_find_all_scan_preserves_completed_pairs_on_capacity_exhaustion() {
	input := RegexInput(RegexAsciiInput{
		bytes: [u8(0x61), 0x61, 0x61]
	})
	for capacity in 0 .. 8 {
		mut output := []i32{len: capacity, init: 91}
		count := regex_find_all_simple_scan(RegexProgram{}, input, 0, RegexLiteral{ code_point: 0x61 }, mut
			output)
		assert count == if capacity < 6 {
			i32(-1)
		} else {
			i32(3)
		}
		written := if capacity / 2 < 3 { capacity / 2 } else { 3 }
		for pair in 0 .. written {
			assert output[2 * pair] == pair && output[2 * pair + 1] == pair + 1
		}
		for value in output[written * 2..] {
			assert value == 91
		}
	}
	mut empty := []i32{}
	assert regex_find_all_simple_scan(RegexProgram{}, input, 0, RegexLiteral{ code_point: 0x42 }, mut
		empty) == 0
}
