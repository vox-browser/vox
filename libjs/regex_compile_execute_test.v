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

fn test_compiled_empty_repetitions_and_limits() {
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
}

fn test_regex_class_merges_nested_and_touching_ranges() {
	mut ranges := [RegexCharRange{ start: 5, end: 6 }, RegexCharRange{ start: 1, end: 10 },
		RegexCharRange{ start: 11, end: 13 }, RegexCharRange{ start: 20, end: 21 }]
	regex_compiler_sort_ranges(mut ranges)
	assert ranges == [RegexCharRange{ start: 1, end: 13 }, RegexCharRange{ start: 20, end: 21 }]
}

fn test_compiled_regex_restores_popped_modifiers_when_backtracking() {
	for text in ['AaaAb', 'AaaAB'] {
		result, captures := regex_compile_test_execute(r'^(?i:a+)b$', text, RegexAstFlags{})
		if text.ends_with('b') {
			assert result == .match && captures == [i32(0), 5]
		} else {
			assert result == .no_match
		}
	}
	flags := RegexAstFlags{ ignore_case: true }
	result, captures := regex_compile_test_execute(r'^(?-i:a+)b$', 'aaB', flags)
	assert result == .match && captures == [i32(0), 3]
}

fn test_discarded_lookaround_restores_modifiers_and_captures() {
	result, captures := regex_compile_test_execute(r'^(?!(?=(?i:(a)))b)a$', 'a', RegexAstFlags{})
	assert result == .match && captures == [i32(0), 1, -1, -1]
	leaked, _ := regex_compile_test_execute(r'^(?!(?=(?i:(a)))b)a$', 'A', RegexAstFlags{})
	assert leaked == .no_match
}

fn test_regex_alternative_prefilter_preserves_captures_and_literal_case() {
	result, captures := regex_compile_test_execute(r'^(?:([a-c]x)|([a-c]y))$', 'by', RegexAstFlags{})
	assert result == .match && captures == [i32(0), 2, -1, -1, 0, 2]
	case_result, case_captures := regex_compile_test_execute(r'^(a(?:bc|bd)|ab)$', 'ABD',
		RegexAstFlags{ ignore_case: true })
	assert case_result == .match && case_captures == [i32(0), 3, 0, 3]
}
