module libjs

fn test_regex_simple_match_paths_preserve_literal_case_rules_and_second_nocase_operand() {
	literal := RegexSimpleMatch(RegexLiteral{
		code_point: 0x53
	})
	nocase := RegexSimpleMatch(RegexCharNoCase{
		first:  0x53
		second: 0x17f
	})
	modifiers := RegexActiveModifiers{
		ignore_case: true
	}
	assert !regex_match_simple_match(literal, 0x73)
	assert regex_match_simple_with_modifiers(literal, 0x73, modifiers)
	assert !regex_match_simple_with_modifiers(literal, 0x17f, modifiers)
	assert regex_match_simple_match(nocase, 0x17f)
	assert !regex_match_simple_match(nocase, 0x73)
	assert regex_match_simple_with_modifiers(nocase, 0x73, RegexActiveModifiers{})
	assert !regex_match_simple_with_modifiers(nocase, 0x17f, modifiers)
	for unicode in [false, true] {
		program := &RegexProgram{
			unicode:     unicode
			ignore_case: true
		}
		mut scratch := RegexVmScratch.new()
		vm := RegexVm.new(program, RegexUtf16Input{}, 0, mut scratch)
		assert vm.match_simple(0x17f, literal) == unicode
		assert vm.match_simple(0x17f, nocase) == unicode
		assert vm.match_simple(0x73, nocase)
		assert vm.pos == 0 && vm.pc == 0 && vm.steps == 0
	}
}

fn test_regex_simple_match_paths_keep_dot_class_and_builtin_modifier_rules() {
	dot := RegexSimpleMatch(RegexAnyChar{})
	class := RegexSimpleMatch(RegexBytecodeCharClass{
		ranges: [RegexCharRange{ start: 0x41, end: 0x5a }]
	})
	assert !regex_match_simple_match(dot, 0xa)
	assert regex_match_simple_with_modifiers(dot, 0xa, RegexActiveModifiers{ dot_all: true })
	assert regex_match_simple_match(RegexAnyChar{ dot_all: true }, 0x2028)
	assert !regex_match_simple_match(class, 0x61)
	assert regex_match_simple_with_modifiers(class, 0x61, RegexActiveModifiers{ ignore_case: true })
	assert !regex_match_simple_with_modifiers(class, 0x212a, RegexActiveModifiers{ ignore_case: true })
	assert !regex_match_simple_with_modifiers(RegexBuiltinCharacterClass.word, 0x212a, RegexActiveModifiers{
		ignore_case: true
	})
	mut scratch := RegexVmScratch.new()
	mut vm := RegexVm.new(&RegexProgram{ unicode: true, ignore_case: true }, RegexAsciiInput{}, 0, mut
		scratch)
	assert vm.match_simple(0x212a, class)
	assert vm.match_simple(0x212a, RegexBuiltinCharacterClass.word)
	assert !vm.match_simple(0xa, dot)
	vm.handle_push_modifiers(false, none, true)
	assert !vm.match_simple(0x212a, class)
	assert !vm.match_simple(0x212a, RegexBuiltinCharacterClass.word)
	assert vm.match_simple(0xa, dot)
	vm.handle_pop_modifiers()
	assert vm.match_simple(0x212a, class)
	assert !vm.match_simple(0xa, dot)
}

fn test_regex_simple_match_negated_property_retains_unicode_and_unicode_sets_difference() {
	positive := RegexSimpleMatch(RegexUnicodePropertyData{
		name: 'Lowercase'
	})
	negative := RegexSimpleMatch(RegexUnicodePropertyData{
		name:    'Lowercase'
		negated: true
	})
	for unicode_sets in [false, true] {
		mut scratch := RegexVmScratch.new()
		vm := RegexVm.new(&RegexProgram{
			unicode:      true
			unicode_sets: unicode_sets
			ignore_case:  true
		}, RegexUtf16Input{}, 0, mut scratch)
		for point in [u32(0x41), 0x61, 0x212a, 0x4b, 0x6b] {
			assert vm.match_simple(point, positive)
			assert vm.match_simple(point, negative) == !unicode_sets
		}
		assert !vm.match_simple(0x31, positive)
		assert vm.match_simple(0x31, negative)
	}
	assert !regex_match_simple_match(positive, 0x41)
	assert regex_match_simple_match(negative, 0x41)
	assert !regex_match_simple_with_modifiers(positive, 0x41, RegexActiveModifiers{
		ignore_case: true
	})
	assert !regex_match_simple_with_modifiers(negative, 0x61, RegexActiveModifiers{
		ignore_case: true
	})
}

fn test_regex_simple_property_resolved_id_overrides_names_except_vm_case_closure_path() {
	resolved := RegexResolvedProperty{
		kind: .binary_property
		id:   78
	}
	property := RegexSimpleMatch(RegexUnicodePropertyData{
		name:     'unknown'
		value:    ''
		resolved: resolved
	})
	assert regex_match_unicode_property_resolved(0x41, 'unknown', '', resolved)
	assert !regex_match_unicode_property_resolved(0x100, 'ASCII', none, resolved)
	assert !regex_match_unicode_property_resolved(0x41, 'unknown', none, none)
	assert regex_match_simple_match(property, 0x41)
	assert regex_match_simple_with_modifiers(property, 0x41, RegexActiveModifiers{ ignore_case: true })
	for unicode in [false, true] {
		mut scratch := RegexVmScratch.new()
		mut vm := RegexVm.new(&RegexProgram{ unicode: unicode, ignore_case: true }, RegexUtf16Input{},
			0, mut scratch)
		assert vm.match_simple(0x41, property) == !unicode
		vm.modifiers.ignore_case = false
		assert vm.match_simple(0x41, property)
	}
}

fn test_regex_simple_union_recurses_with_the_same_predicate_and_active_flags() {
	left := RegexSimpleMatch(RegexLiteral{
		code_point: 0x53
	})
	right := RegexSimpleMatch(RegexUnicodePropertyData{
		name:  'gc'
		value: 'Nd'
	})
	inner := RegexSimpleMatch(RegexSimpleUnion{
		left:  &left
		right: &right
	})
	dot := RegexSimpleMatch(RegexAnyChar{
		dot_all: true
	})
	outer := RegexSimpleMatch(RegexSimpleUnion{
		left:  &inner
		right: &dot
	})
	assert !regex_match_simple_match(inner, 0x73)
	assert regex_match_simple_match(inner, 0x31)
	assert regex_match_simple_with_modifiers(inner, 0x73, RegexActiveModifiers{ ignore_case: true })
	assert regex_match_simple_match(outer, 0xa)
	mut scratch := RegexVmScratch.new()
	vm := RegexVm.new(&RegexProgram{ unicode: true, ignore_case: true }, RegexUtf16Input{}, 0, mut
		scratch)
	assert vm.match_simple(0x17f, inner)
	assert vm.match_simple(0x31, inner)
	assert vm.match_simple(0xa, outer)
}
