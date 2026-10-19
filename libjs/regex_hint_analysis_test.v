module libjs

fn regex_hint_test_program(instructions []RegexInstruction) RegexProgram {
	return RegexProgram{
		instructions: instructions
	}
}

fn test_regex_hint_successors_retain_branch_order_and_terminal_boundaries() {
	for item in [RegexInstruction(RegexJump{
		target: 4
	}), RegexSplit{ prefer: 3, other: 3 },
		RegexRepeatCheck{ body: 6 }, RegexLookStart{ end: 7 },
		RegexMatch{}, RegexFail{}, RegexLookEnd{}, RegexLiteral{ code_point: 0x61 }] {
		mut observed := &[]usize{}
		regex_for_each_successor(item, 1, 8, fn [mut observed] (successor usize) {
			observed << successor
		})
		mut expected := []usize{}
		match item {
			RegexJump { expected = [usize(4)] }
			RegexSplit { expected = [usize(3), 3] }
			RegexRepeatCheck { expected = [usize(6), 2] }
			RegexLookStart { expected = [usize(7), 2] }
			RegexMatch, RegexFail, RegexLookEnd {}
			else { expected = [usize(2)] }
		}

		assert *observed == expected
	}
	mut last := &[]usize{}
	regex_for_each_successor(RegexRepeatCheck{ body: 0 }, 3, 4, fn [mut last] (successor usize) {
		last << successor
	})
	assert *last == [usize(0)]
	assert !regex_suffix_has_linear_tail([], 0)
}

fn test_regex_hint_suffix_control_flow_preserves_bookkeeping_and_wtf16() {
	instructions := [RegexInstruction(RegexSave{
		reg: 0
	}), RegexAnyChar{},
		RegexLiteral{ code_point: 0xd800 }, RegexSave{ reg: 2 },
		RegexClearRegister{ reg: 3 }, RegexLiteral{ code_point: 0x1f600 },
		RegexPopModifiers{}, RegexNop{}, RegexAssertEnd{}, RegexSave{ reg: 1 },
		RegexMatch{}]
	assert regex_extract_trailing_literal(instructions, 8)? == [u16(0xd800), 0xd83d, 0xde00]
	mut branch := instructions.clone()
	branch[1] = RegexSplit{
		prefer: 2
		other:  5
	}
	assert regex_extract_trailing_literal(branch, 8) == none
	branch[1] = RegexJump{
		target: 2
	}
	assert regex_extract_trailing_literal(branch, 8)? == [u16(0xd800), 0xd83d, 0xde00]
	branch[5] = RegexLiteral{
		code_point: 0x110000
	}
	assert regex_extract_trailing_literal(branch, 8) == none
	assert regex_extract_trailing_literal([RegexInstruction(RegexNop{}), RegexMatch{}], 1) == none
}

fn test_regex_hint_common_first_character_retains_source_case_flag_priority() {
	instructions := [RegexInstruction(RegexSplit{
		prefer: 1
		other:  4
	}), RegexSave{ reg: 2 },
		RegexCharNoCase{ first: 0x61, second: 0x41 }, RegexMatch{},
		RegexSplit{ prefer: 5, other: 7 }, RegexLiteral{ code_point: 0x61 },
		RegexMatch{}, RegexSave{ reg: 3 }, RegexLiteral{ code_point: 0x61 },
		RegexMatch{}]
	assert regex_find_common_first_char(instructions, 0)? == RegexFirstChar{
		code_point:       0x61
		case_insensitive: true
	}
	mut different := instructions.clone()
	different[8] = RegexLiteral{
		code_point: 0x62
	}
	assert regex_find_common_first_char(different, 0) == none
	different[8] = RegexNop{}
	assert regex_find_common_first_char(different, 0) == none
	assert regex_first_char_at(instructions, 100) == none
	hints := regex_analyze_pattern(regex_hint_test_program([
		RegexInstruction(RegexSave{ reg: 0 }),
		RegexAssertWordBoundary{},
		RegexLiteral{
			code_point: 0x61
		},
		RegexMatch{},
	]), false, none)
	assert hints.first_char? == RegexFirstChar{
		code_point: 0x61
	}
	assert hints.first_filter == none
}

fn test_regex_hint_leading_anchors_and_alternative_start_limits_follow_upstream() {
	setup := [RegexInstruction(RegexSave{
		reg: 0
	}), RegexClearRegister{ reg: 2 },
		RegexNop{}, RegexPushModifiers{}, RegexLookStart{ positive: true, forward: true, end: 7 },
		RegexAssertStart{}, RegexLiteral{ code_point: 0x61 },
		RegexMatch{}]
	mut program := regex_hint_test_program(setup)
	program.multiline = true
	hints := regex_analyze_pattern(program, true, none)
	assert hints.starts_with_anchor && hints.anchor_multiline && hints.can_match_empty
	mut negative := setup.clone()
	negative[4] = RegexLookStart{
		positive: false
		forward:  true
		end:      7
	}
	assert !regex_analyze_pattern(regex_hint_test_program(negative), false, none).starts_with_anchor
	negative[4] = RegexLookStart{
		positive: true
		forward:  false
		end:      7
	}
	assert !regex_analyze_pattern(regex_hint_test_program(negative), false, none).starts_with_anchor
	branches := [RegexInstruction(RegexSplit{
		prefer: 1
		other:  3
	}), RegexAssertStart{},
		RegexMatch{}, RegexSplit{ prefer: 4, other: 6 }, RegexLiteral{ code_point: 0x61 },
		RegexMatch{}, RegexNop{}, RegexLiteral{ code_point: 0x62 },
		RegexMatch{}]
	start := regex_analyze_start_position_hint(branches, 0)?
	assert start.includes_input_start && start.literal_code_units == [u16(0x61), 0x62]
	mut duplicate := branches.clone()
	duplicate[7] = RegexLiteral{
		code_point: 0x61
	}
	assert regex_analyze_start_position_hint(duplicate, 0)?.literal_code_units == [
		u16(0x61),
	]
	duplicate[7] = RegexAssertStart{}
	duplicate[4] = RegexAssertStart{}
	assert regex_analyze_start_position_hint(duplicate, 0) == none
	duplicate[4] = RegexAssertStart{
		multiline: true
	}
	assert regex_analyze_start_position_hint(duplicate, 0) == none
	mut unicode_program := regex_hint_test_program(branches)
	unicode_program.unicode = true
	assert regex_analyze_pattern(unicode_program, false, none).start_position_hint == none
	three := [RegexInstruction(RegexSplit{
		prefer: 1
		other:  2
	}), RegexLiteral{
		code_point: 0x61
	}, RegexSplit{ prefer: 3, other: 4 }, RegexLiteral{ code_point: 0x62 },
		RegexLiteral{ code_point: 0x63 }]
	assert regex_analyze_start_position_hint(three, 0) == none
}

fn test_regex_hint_analysis_clones_class_and_recursive_greedy_matcher_filters() {
	mut program := regex_hint_test_program([RegexInstruction(RegexSave{ reg: 0 }), RegexBytecodeCharClass{
		ranges:  [
			RegexCharRange{
				start: 1
				end:   9
			},
		]
		negated: true
	}, RegexSave{ reg: 1 }, RegexMatch{}])
	mut hints := regex_analyze_pattern(program, false, none)
	filter_value := hints.first_filter?
	scan_value := hints.simple_scan?
	mut filter := filter_value as RegexBytecodeCharClass
	mut scan := scan_value as RegexBytecodeCharClass
	filter.ranges[0].start = 4
	scan.ranges[0].end = 7
	assert (program.instructions[1] as RegexBytecodeCharClass).ranges == [
		RegexCharRange{
			start: 1
			end:   9
		},
	]
	assert filter.ranges[0].end == 9 && scan.ranges[0].start == 1
	matcher := RegexSimpleMatch(RegexSimpleUnion{
		left:  box_regex_simple_match(RegexBytecodeCharClass{
			ranges: [RegexCharRange{ start: 0x61, end: 0x7a }]
		})
		right: box_regex_simple_match(RegexLiteral{ code_point: 0x20 })
	})
	program.instructions[1] = RegexGreedyLoop{
		matcher: matcher
		min:     1
		max:     u32(4)
	}
	hints = regex_analyze_pattern(program, false, none)
	union_value := hints.first_filter?
	mut union_filter := union_value as RegexSimpleUnion
	original_union := matcher as RegexSimpleUnion
	assert voidptr(union_filter.left) != voidptr(original_union.left)
	mut union_class := (*union_filter.left) as RegexBytecodeCharClass
	union_class.ranges[0].end = 0x62
	assert ((*original_union.left) as RegexBytecodeCharClass).ranges[0].end == 0x7a
	greedy_value := hints.simple_scan?
	greedy_scan := greedy_value as RegexGreedyLoop
	assert (greedy_scan.matcher as RegexSimpleUnion) == original_union && greedy_scan.max? == 4
	program.ignore_case = true
	hints = regex_analyze_pattern(program, false, none)
	assert hints.first_filter == none && hints.simple_scan == none
	program.ignore_case = false
	program.instructions[1] = RegexGreedyLoop{
		matcher: matcher
		min:     0
	}
	hints = regex_analyze_pattern(program, false, none)
	assert hints.first_filter == none && hints.simple_scan == none
}

fn test_regex_hint_required_literal_selection_and_end_anchor_arm_order_are_exact() {
	mut program := regex_hint_test_program([RegexInstruction(RegexSave{ reg: 0 }), RegexLiteral{
		code_point: 0x61
	}, RegexLiteral{ code_point: 0x62 }, RegexSave{ reg: 1 },
		RegexMatch{}])
	mut ast := RegexRequiredLiteralHint{
		literal:                [u16(0x78)]
		ascii_case_insensitive: true
	}
	assert regex_analyze_pattern(program, false, ast).required_literal?.literal == [
		u16(0x61),
		0x62,
	]
	ast.literal = [u16(0x78), 0x79]
	assert !regex_analyze_pattern(program, false, ast).required_literal?.ascii_case_insensitive
	ast.ascii_case_insensitive = false
	assert regex_analyze_pattern(program, false, ast).required_literal?.literal == ast.literal
	ast.literal << u16(0x7a)
	mut hints := regex_analyze_pattern(program, false, ast)
	mut owned := hints.required_literal?
	owned.literal[0] = 0x70
	assert ast.literal[0] == 0x78
	program.instructions.insert(3, RegexAssertEnd{})
	hints = regex_analyze_pattern(program, false, none)
	assert hints.trailing_literal? == [u16(0x61), 0x62]
	// The source's first broad required-literal arm wins, then stops at
	// AssertEnd. Its later end-anchor arm is unreachable for this shape.
	assert hints.required_literal == none
	program.multiline = true
	assert regex_analyze_pattern(program, false, none).trailing_literal == none
	program.multiline = false
	program.ignore_case = true
	assert regex_analyze_pattern(program, false, none).trailing_literal == none
	empty := regex_analyze_pattern(RegexProgram.new(), true, none)
	assert empty.first_char == none && empty.first_filter == none && empty.simple_scan == none
	assert empty.trailing_literal == none && empty.required_literal == none && empty.can_match_empty
}
