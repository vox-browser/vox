module libjs

fn test_regex_ast_quantifier_factories_and_builtin_complements_preserve_source_values() {
	for greedy in [false, true] {
		star := RegexQuantifier.zero_or_more(greedy)
		plus := RegexQuantifier.one_or_more(greedy)
		optional := RegexQuantifier.zero_or_one(greedy)
		assert star.min == 0 && star.max == none && star.greedy == greedy
		assert plus.min == 1 && plus.max == none && plus.greedy == greedy
		assert optional.min == 0 && optional.max? == 1 && optional.greedy == greedy
	}
	classes := [RegexBuiltinCharacterClass.digit, .non_digit, .word, .non_word, .whitespace,
		.non_whitespace]
	for index, class in classes {
		assert int(class) == index
		assert class.negated() == classes[index ^ 1]
		assert class.negated().negated() == class
	}
	assert RegexAstFlags{} == RegexAstFlags{
		global:       false
		ignore_case:  false
		multiline:    false
		dot_all:      false
		unicode:      false
		unicode_sets: false
		sticky:       false
		has_indices:  false
	}
	assert RegexModifierFlags{} == RegexModifierFlags{
		ignore_case: false
		multiline:   false
		dot_all:     false
	}
}

fn regex_ast_test_body() RegexDisjunction {
	return RegexDisjunction{
		alternatives: [
			RegexAlternative{
				terms: [
					RegexTerm{
						atom:       RegexLiteral{
							code_point: 0xd800
						}
						quantifier: RegexQuantifier{
							min:    2
							max:    u32(7)
							greedy: true
						}
					},
				]
			},
		]
	}
}

fn test_regex_ast_represents_every_atom_and_class_variant_without_losing_payloads() {
	body := regex_ast_test_body()
	property := RegexUnicodeProperty{
		negated: true
		name:    'Script'
		value:   'Greek'
	}
	ranges := RegexClassRanges{
		ranges: [RegexCharacterClassRange(RegexLiteral{
			code_point: 0xdc00
		}), RegexCharRange{
			start: 0x10000
			end:   0x10ffff
		}, RegexBuiltinCharacterClass.word, property]
	}
	class := RegexCharacterClass{
		negated: true
		body:    ranges
	}
	operands := [RegexClassSetOperand(RegexLiteral{
		code_point: 0
	}), RegexCharRange{
		start: 0x41
		end:   0x5a
	}, class, RegexBuiltinCharacterClass.whitespace, property, RegexClassStringLiteral{ code_points: [
		`a`,
		`😀`,
	] }]
	for expression in [
		RegexClassSetExpression(RegexClassSetUnion{
			operands: operands
		}),
		RegexClassSetIntersection{
			operands: operands
		},
		RegexClassSetSubtraction{
			operands: operands
		},
	] {
		cloned := expression.clone()
		assert cloned == expression
	}
	atoms := [RegexAtom(RegexLiteral{
		code_point: 0x10ffff
	}), RegexDot{}, class,
		RegexBuiltinCharacterClass.non_word, property, RegexGroup{
			index: 1
			name:  'named'
			body:  body
		}, RegexNonCapturingGroup{ body: body }, RegexLookaround{
			kind: .lookbehind_negative
			body: body
		}, RegexBackreferenceAtom{
			reference: RegexNamedBackreference{
				name: 'named'
			}
		}, RegexAssertionKind.non_word_boundary, RegexModifierGroup{
			add_flags:    RegexModifierFlags{
				ignore_case: true
			}
			remove_flags: RegexModifierFlags{
				multiline: true
			}
			body:         body
		}]
	mut pattern := RegexPatternAst{
		disjunction:   RegexDisjunction{
			alternatives: [RegexAlternative{
				terms: atoms.map(RegexTerm{ atom: it })
			}]
		}
		flags:         RegexAstFlags{
			unicode_sets: true
			sticky:       true
		}
		capture_count: 1
		named_groups:  [RegexNamedGroup{ name: 'named', index: 1 }]
	}
	copy := pattern.clone()
	assert copy == pattern
	pattern.named_groups[0].index = 99
	pattern.disjunction.alternatives[0].terms[0].atom = RegexDot{}
	assert copy.named_groups[0].index == 1
	assert copy.disjunction.alternatives[0].terms[0].atom is RegexLiteral
	assert copy != pattern
	assert RegexBackreference(RegexIndexedBackreference{
		index: 1
	}) != RegexBackreference(RegexIndexedBackreference{
		index: 2
	})
	for kind in [RegexLookaroundKind.lookahead_positive, .lookahead_negative, .lookbehind_positive,
		.lookbehind_negative] {
		look := RegexLookaround{
			kind: kind
			body: body
		}
		assert look.clone() == look
	}
}

fn test_regex_ast_clones_nested_capture_modifier_and_unicode_set_arrays_independently() {
	mut group := RegexGroup{
		index: 1
		name:  ''
		body:  regex_ast_test_body()
	}
	group_copy := group.clone()
	group.body.alternatives[0].terms[0].quantifier = none
	assert group_copy.body.alternatives[0].terms[0].quantifier != none
	assert group_copy.name? == ''
	class_union := RegexClassSetUnion{
		operands: [
			RegexClassSetOperand(RegexCharacterClass{
				body: RegexClassSetExpression(RegexClassSetSubtraction{
					operands: [
						RegexClassSetOperand(RegexClassStringLiteral{
							code_points: [`x`, `😀`]
						}),
					]
				})
			}),
		]
	}
	mut copied := class_union.clone()
	mut nested := copied.operands[0] as RegexCharacterClass
	mut subtraction := nested.body as RegexClassSetExpression
	mut difference := subtraction as RegexClassSetSubtraction
	mut literal := difference.operands[0] as RegexClassStringLiteral
	literal.code_points[0] = `y`
	original_class := class_union.operands[0] as RegexCharacterClass
	original_expression := original_class.body as RegexClassSetExpression
	original_difference := original_expression as RegexClassSetSubtraction
	original_literal := original_difference.operands[0] as RegexClassStringLiteral
	assert original_literal.code_points == [`x`, `😀`]
	ranges := RegexClassRanges{
		ranges: [RegexCharacterClassRange(RegexLiteral{
			code_point: 0xdfff
		})]
	}
	mut ranges_copy := ranges.clone()
	ranges_copy.ranges[0] = RegexLiteral{
		code_point: 0
	}
	assert ranges.ranges[0] == RegexCharacterClassRange(RegexLiteral{
		code_point: 0xdfff
	})
	modifier := RegexModifierGroup{
		add_flags: RegexModifierFlags{
			dot_all: true
		}
		body:      regex_ast_test_body()
	}
	mut modifier_copy := modifier.clone()
	modifier_copy.body.alternatives[0].terms.clear()
	assert modifier.body.alternatives[0].terms.len == 1
}
