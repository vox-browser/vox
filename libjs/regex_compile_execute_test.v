module libjs

fn regex_compile_test_execute(pattern string, text string, flags RegexAstFlags) (RegexVmResult, []i32) {
	tree := parse_regex_ast(pattern, flags) or { panic(err) }
	program := compile_regex_ast(tree)
	hints := regex_analyze_pattern(program, regex_compiler_body_zero_width(tree.disjunction), none)
	mut scratch := RegexVmScratch.new()
	mut output := []i32{len: int(program.capture_count + 1) * 2, init: -77}
	result := regex_execute_into_with_scratch(&program, RegexUtf16Input{ units: utf16_string(text).code_units() }, 0, hints, mut output, mut scratch)
	return result, output
}

fn test_compiled_regex_runs_captures_quantifiers_lookarounds_and_modifiers() {
	for pattern in [r'^(?<x>a|b)+\k<x>$', r'^(?<x>a|b){1,5}\k<x>$', r'^(?<x>a|b)+?\k<x>$',
		r'(?<=a)(b)(?=b)b', r'(?i:(B))(?-i:b)', r'((a)?b)+', r'(?<!x)(a*)bb', r'(a|a?)+bb'] {
		result, captures := regex_compile_test_execute(pattern, 'abb', RegexAstFlags{ unicode: true })
		assert result == .match, pattern
		assert captures[0] >= 0 && captures[1] == 3, pattern
	}
	result, captures := regex_compile_test_execute(r'((a)?b)+', 'abb', RegexAstFlags{})
	assert result == .match
	assert captures == [i32(0), 3, 2, 3, -1, -1]
}

fn test_compiled_unicode_sets_use_equal_lengths_and_restore_capture_direction() {
	for pattern in [r'^[\p{Letter}&&\p{ASCII}]+$', r'^[[a-z]--[c-z]]+$', r'^[\q{a|ab}&&\q{ab}]+$',
		r'^[\q{abc|ab}--\q{abc}]+$'] {
		result, captures := regex_compile_test_execute(pattern, 'abab', RegexAstFlags{ unicode_sets: true })
		assert result == .match, pattern
		assert captures == [i32(0), 4]
	}
	result, captures := regex_compile_test_execute(r'(?<=([\q{ab}&&\q{ab}]))x', 'abx', RegexAstFlags{ unicode_sets: true })
	assert result == .match
	assert captures == [i32(2), 3, 0, 2]
}

fn test_compiled_empty_repetitions_limits_and_stable_range_order() {
	for pattern in [r'(a?)*', r'(a?){0,5}'] {
		result, _ := regex_compile_test_execute(pattern, '', RegexAstFlags{ unicode: true })
		assert result == .match, pattern
	}
	mut program := RegexProgram{ instructions: [RegexInstruction(RegexJump{ target: 0 })] }
	mut scratch := RegexVmScratch.new()
	mut vm := RegexVm.new(&program, RegexAsciiInput{}, 0, mut scratch)
	vm.steps = regex_match_limit - 2
	assert vm.run() == .limit_exceeded
	assert vm.steps == regex_match_limit
	mut ranges := [RegexCharRange{ start: 5, end: 8 }, RegexCharRange{ start: 1, end: 3 },
		RegexCharRange{ start: 5, end: 9 }]
	regex_compiler_sort_ranges(mut ranges)
	assert ranges[0].start == 1 && ranges[1].end == 8 && ranges[2].end == 9
}
