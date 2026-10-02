module libjs

fn test_regex_available_same_matcher_counts_code_points_in_the_supplied_direction_without_mutation() {
	mut scratch := RegexVmScratch.new()
	mut vm := RegexVm.new(&RegexProgram{ unicode: true }, RegexUtf16Input{
		units: [u16(0xd801), 0xdc00, 0xd801, 0xdc00, 32]
	}, 5, mut scratch)
	vm.backward = true
	vm.pc = 9
	vm.steps = 13
	matcher := RegexSimpleMatch(RegexLiteral{
		code_point: 0x10400
	})
	assert vm.count_available_same_matcher_chars(0, matcher, 5, false) == 2
	assert vm.count_available_same_matcher_chars(2, matcher, 5, false) == 1
	assert vm.count_available_same_matcher_chars(4, matcher, 5, true) == 2
	assert vm.count_available_same_matcher_chars(4, matcher, 1, true) == 1
	assert vm.count_available_same_matcher_chars(1, matcher, 5, true) == 1
	assert vm.count_available_same_matcher_chars(5, matcher, 5, true) == 0
	assert vm.count_available_same_matcher_chars(0, matcher, 5, true) == 0
	assert vm.count_available_same_matcher_chars(5, matcher, 5, false) == 0
	assert vm.count_available_same_matcher_chars(0, matcher, 0, false) == 0
	assert vm.pos == 5 && vm.pc == 9 && vm.steps == 13 && vm.backward
}

fn test_regex_available_same_matcher_uses_active_modifiers_and_unicode_set_negation() {
	matcher := RegexSimpleMatch(RegexUnicodePropertyData{
		name:    'Lowercase'
		negated: true
	})
	for sets in [false, true] {
		mut scratch := RegexVmScratch.new()
		mut vm := RegexVm.new(&RegexProgram{ unicode: true, unicode_sets: sets }, RegexAsciiInput{
			bytes: [u8(97), 65]
		}, 0, mut scratch)
		assert vm.count_available_same_matcher_chars(0, matcher, 2, false) == 0
		vm.modifiers.ignore_case = true
		assert vm.count_available_same_matcher_chars(0, matcher, 2, false) == if sets {
			u32(0)
		} else {
			u32(2)
		}
	}
}

fn test_regex_loop_suffix_deficit_requires_a_greedy_prefix_and_positive_matching_suffix() {
	matcher := RegexSimpleMatch(RegexLiteral{
		code_point: 65
	})
	mut program := &RegexProgram{
		instructions: [RegexInstruction(RegexGreedyLoop{
			matcher: matcher
			min:     3
		}), RegexLazyLoop{ matcher: matcher.clone(), min: 2 },
			RegexGreedyLoop{ matcher: matcher.clone(), min: 1 }, RegexNop{}]
	}
	mut scratch := RegexVmScratch.new()
	vm := RegexVm.new(program, RegexAsciiInput{ bytes: [u8(65), 65, 66, 65] }, 0, mut scratch)
	assert vm.same_matcher_loop_suffix_deficit(0, 0, false)? == 1
	assert vm.same_matcher_loop_suffix_deficit(0, 3, false)? == 2
	assert vm.same_matcher_loop_suffix_deficit(0, 4, true)? == 2
	assert vm.same_matcher_loop_suffix_deficit(0, 0, true)? == 3
	assert vm.same_matcher_loop_suffix_deficit(1, 0, false) == none
	assert vm.same_matcher_loop_suffix_deficit(2, 0, false) == none
	assert vm.same_matcher_loop_suffix_deficit(99, 0, false) == none
	program.instructions[1] = RegexLazyLoop{
		matcher: matcher.clone()
		min:     1
	}
	assert vm.same_matcher_loop_suffix_deficit(0, 0, false) == none
	program.instructions[1] = RegexLazyLoop{
		matcher: matcher.clone()
		min:     0xffffffff
	}
	assert vm.same_matcher_loop_suffix_deficit(0, 0, false) == none
}
