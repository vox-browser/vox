module libjs

import os

fn test_regex_program_defaults_offsets_and_split_patch_priority_follow_upstream() {
	mut program := RegexProgram.new()
	assert program.instructions.len == 0 && program.capture_count == 0
		&& program.register_count == 2
	assert !program.unicode && !program.unicode_sets && !program.ignore_case && !program.multiline
		&& !program.dot_all
	assert program.named_groups.len == 0 && program.current_offset() == 0
	jump := program.emit(RegexJump{ target: 0xffffffff })
	split := program.emit(RegexSplit{ prefer: 0xffffffff, other: 0xffffffff })
	assert jump == 0 && split == 1 && program.current_offset() == 2
	program.patch_jump(jump, 9)
	program.patch_jump(jump, 3)
	program.patch_jump(split, 7)
	assert program.instructions[0] == RegexInstruction(RegexJump{
		target: 3
	})
	assert program.instructions[1] == RegexInstruction(RegexSplit{
		prefer: 7
		other:  0xffffffff
	})
	program.patch_jump(split, 11)
	assert program.instructions[1] == RegexInstruction(RegexSplit{
		prefer: 7
		other:  11
	})
	other_only := program.emit(RegexSplit{ prefer: 5, other: 0xffffffff })
	program.patch_jump(other_only, 13)
	assert program.instructions[2] == RegexInstruction(RegexSplit{
		prefer: 5
		other:  13
	})
	// Patching to the sentinel leaves that arm unresolved, so the next patch
	// still targets prefer rather than advancing to other.
	both := program.emit(RegexSplit{ prefer: 0xffffffff, other: 0xffffffff })
	program.patch_jump(both, 0xffffffff)
	program.patch_jump(both, 17)
	assert program.instructions[3] == RegexInstruction(RegexSplit{
		prefer: 17
		other:  0xffffffff
	})
}

fn regex_bytecode_test_instructions() []RegexInstruction {
	left := RegexSimpleMatch(RegexBytecodeCharClass{
		ranges:  [RegexCharRange{ start: 0x41, end: 0x5a }]
		negated: true
	})
	right := RegexSimpleMatch(RegexLiteral{
		code_point: 0xd800
	})
	union_matcher := RegexSimpleMatch(RegexSimpleUnion{
		left:  box_regex_simple_match(left)
		right: box_regex_simple_match(right)
	})
	property := RegexUnicodePropertyData{
		negated:  true
		name:     'Script'
		value:    'Greek'
		resolved: RegexResolvedProperty{
			kind: .script
			id:   14
		}
	}
	return [RegexInstruction(RegexLiteral{
		code_point: 0x10ffff
	}), RegexCharNoCase{
		first:  0x41
		second: 0x61
	}, RegexAnyChar{ dot_all: true }, RegexBytecodeCharClass{
		ranges:  [
			RegexCharRange{
				start: 0
				end:   0xffff
			},
		]
		negated: true
	}, RegexBuiltinCharacterClass.non_digit, property, RegexJump{ target: 0xffffffff },
		RegexSplit{ prefer: 7, other: 0xffffffff }, RegexSave{ reg: 2 },
		RegexClearRegister{ reg: 3 }, RegexAssertStart{ multiline: true },
		RegexAssertEnd{ multiline: false }, RegexAssertWordBoundary{},
		RegexAssertNonWordBoundary{}, RegexMatch{}, RegexFail{},
		RegexIndexedBackreference{ index: 1 }, RegexNamedBackreference{ name: 'named' },
		RegexRepeatStart{ counter_reg: 4 }, RegexRepeatCheck{
			counter_reg: 4
			min:         3
			max:         u32(9)
			body:        12
			greedy:      false
		}, RegexLookStart{ positive: false, forward: false, end: 18 },
		RegexLookEnd{}, RegexPushModifiers{ ignore_case: false, multiline: true, dot_all: none },
		RegexPopModifiers{}, RegexNop{}, RegexStringPropertyMatch{
			strings:  [
				u32(2),
				0x61,
				0x1f600,
				1,
				0x62,
			]
			property: property
		}, RegexProgressCheck{
			reg:            5
			clear_captures: [
				u32(2),
				3,
				6,
				7,
			]
		}, RegexGreedyLoop{ matcher: union_matcher, min: 1, max: none },
		RegexLazyLoop{ matcher: RegexSimpleMatch(property), min: 0, max: u32(5) }]
}

fn test_regex_bytecode_preserves_all_instruction_and_simple_match_payloads() {
	instructions := regex_bytecode_test_instructions()
	assert instructions.len == 29
	for instruction in instructions {
		copy := instruction.clone()
		assert copy == instruction
	}
	property := RegexUnicodePropertyData{
		name:  'General_Category'
		value: 'Letter'
	}
	matchers := [RegexSimpleMatch(RegexAnyChar{
		dot_all: true
	}), RegexLiteral{
		code_point: 0xdc00
	}, RegexCharNoCase{ first: 0x61, second: 0x41 }, RegexBytecodeCharClass{
		ranges: [
			RegexCharRange{
				start: 0
				end:   9
			},
		]
	}, RegexBuiltinCharacterClass.word, property]
	for matcher in matchers {
		assert matcher.clone() == matcher
	}
	for value in 0 .. 256 {
		if kind := regex_property_kind_from_u8(u8(value)) {
			assert value < 4 && int(kind) == value
		} else {
			assert value >= 4
		}
	}
	assert RegexPushModifiers{
		ignore_case: false
	} != RegexPushModifiers{
		ignore_case: none
	}
	assert RegexUnicodePropertyData{
		value: ''
	} != RegexUnicodePropertyData{
		value: none
	}
}

fn test_regex_program_clone_owns_instruction_vectors_and_nested_matcher_boxes() {
	mut program := RegexProgram{
		instructions:   regex_bytecode_test_instructions()
		capture_count:  1
		register_count: 8
		unicode:        true
		unicode_sets:   true
		ignore_case:    true
		multiline:      true
		dot_all:        true
		named_groups:   [RegexNamedGroupEntry{ name: 'named', index: 1 }]
	}
	mut copy := program.clone()
	assert copy.instructions == program.instructions && copy.named_groups == program.named_groups
	assert copy.capture_count == 1 && copy.register_count == 8 && copy.unicode && copy.unicode_sets
	assert copy.ignore_case && copy.multiline && copy.dot_all
	copy.named_groups[0].index = 9
	mut packed := copy.instructions[25] as RegexStringPropertyMatch
	packed.strings[0] = 1
	mut progress := copy.instructions[26] as RegexProgressCheck
	progress.clear_captures[0] = 99
	mut greedy := copy.instructions[27] as RegexGreedyLoop
	mut union_matcher := greedy.matcher as RegexSimpleUnion
	original_greedy := program.instructions[27] as RegexGreedyLoop
	original_union := original_greedy.matcher as RegexSimpleUnion
	assert union_matcher == original_union
	assert voidptr(union_matcher.left) != voidptr(original_union.left)
	mut class := (*union_matcher.left) as RegexBytecodeCharClass
	class.ranges[0].start = 0
	original_class := (*original_union.left) as RegexBytecodeCharClass
	assert original_class.ranges[0].start == 0x41
	assert program.named_groups[0].index == 1
	assert (program.instructions[25] as RegexStringPropertyMatch).strings[0] == 2
	assert (program.instructions[26] as RegexProgressCheck).clear_captures[0] == 2
	program.instructions.clear()
	assert copy.instructions.len == 29
}

fn test_regex_wtf16_append_preserves_surrogates_and_rejects_out_of_range_without_writes() {
	mut output := [u16(0x61)]
	for value in [u32(0), 0x7f, 0x80, 0xd800, 0xdfff, 0xffff, 0x10000, 0x1f600, 0x10ffff] {
		regex_append_code_point_wtf16(mut output, value)?
	}
	assert output == [u16(0x61), 0, 0x7f, 0x80, 0xd800, 0xdfff, 0xffff, 0xd800, 0xdc00, 0xd83d,
		0xde00, 0xdbff, 0xdfff]
	before := output.clone()
	for value in [u32(0x110000), 0xffffffff] {
		if _ := regex_append_code_point_wtf16(mut output, value) { assert false
		 }
		assert output == before
	}
}

fn test_regex_program_invalid_patches_keep_the_source_panic_boundary() {
	mode := os.getenv('VOX2_REGEX_PATCH_PANIC')
	if mode != '' {
		mut program := RegexProgram.new()
		if mode == 'nop' { program.emit(RegexNop{}) }
		if mode == 'resolved' { program.emit(RegexSplit{ prefer: 1, other: 2 }) }
		program.patch_jump(0, 9)
		assert false
		return
	}
	for probe in ['nop', 'resolved', 'empty'] {
		mut environment := os.environ()
		environment['VOX2_REGEX_PATCH_PANIC'] = probe
		mut process := os.new_process(os.executable())
		process.set_environment(environment)
		process.set_redirect_stdio()
		process.run()
		process.wait()
		output := process.stdout_slurp() + process.stderr_slurp()
		assert process.code != 0, output
		if probe == 'empty' {
			assert output.contains('index'), output
		} else {
			assert output.contains('cannot patch non-jump instruction'), output
		}
		process.close()
	}
}
