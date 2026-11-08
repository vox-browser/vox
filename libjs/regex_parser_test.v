module libjs

import encoding.hex

fn regex_parser_bit(value bool) string { return if value { '1' } else { '0' } }

fn regex_parser_optional_name(name ?string) string { return name or { '-' } }

fn regex_parser_property_text(property RegexUnicodeProperty) string {
	return 'P${regex_parser_bit(property.negated)}[${property.name}=${property.value or { '-' }}]'
}

fn regex_parser_class_text(class RegexCharacterClass) string {
	body := class.body
	mut text := ''
	if body is RegexClassRanges {
		mut values := []string{}
		for item in body.ranges {
			values << match item {
				RegexLiteral { 'L${item.code_point}' }
				RegexCharRange { 'R${item.start}:${item.end}' }
				RegexBuiltinCharacterClass { 'B${int(item)}' }
				RegexUnicodeProperty { regex_parser_property_text(item) }
			}
		}
		text = 'R(${values.join(',')})'
	} else if body is RegexClassSetExpression {
		text = regex_parser_set_text(body)
	}
	return 'C${regex_parser_bit(class.negated)}${text}'
}

fn regex_parser_set_text(expression RegexClassSetExpression) string {
	mut values := []string{}
	for item in expression.operands {
		values << match item {
			RegexLiteral { 'L${item.code_point}' }
			RegexCharRange { 'R${item.start}:${item.end}' }
			RegexBuiltinCharacterClass { 'B${int(item)}' }
			RegexUnicodeProperty { regex_parser_property_text(item) }
			RegexCharacterClass { regex_parser_class_text(item) }
			RegexClassStringLiteral { 'Q' + item.code_points.map(u32(it).str()).join(':') }
		}
	}
	tag := match expression {
		RegexClassSetUnion { 'U' }
		RegexClassSetIntersection { 'I' }
		RegexClassSetSubtraction { 'S' }
	}
	return '${tag}(${values.join(',')})'
}

fn regex_parser_modifier_bits(flags RegexModifierFlags) int {
	return (if flags.ignore_case { 1 } else { 0 }) | (if flags.multiline { 2 } else { 0 }) | (if flags.dot_all {
		4
	} else {
		0
	})
}

fn regex_parser_atom_text(atom RegexAtom) string {
	return match atom {
		RegexLiteral { 'L${atom.code_point}' }
		RegexDot { '.' }
		RegexBuiltinCharacterClass { 'B${int(atom)}' }
		RegexUnicodeProperty { regex_parser_property_text(atom) }
		RegexAssertionKind { 'E${int(atom)}' }
		RegexCharacterClass { regex_parser_class_text(atom) }
		RegexGroup {
			name := regex_parser_optional_name(atom.name)
			'G${atom.index}:${name}${regex_parser_body_text(atom.body)}'
		}
		RegexNonCapturingGroup { 'N${regex_parser_body_text(atom.body)}' }
		RegexLookaround { 'K${int(atom.kind)}${regex_parser_body_text(atom.body)}' }
		RegexBackreferenceAtom {
			ref := atom.reference
			match ref {
				RegexIndexedBackreference { 'X${ref.index}' }
				RegexNamedBackreference { 'Y${ref.name}' }
			}
		}
		RegexModifierGroup {
			'M${regex_parser_modifier_bits(atom.add_flags)}:${regex_parser_modifier_bits(atom.remove_flags)}${regex_parser_body_text(atom.body)}'
		}
	}
}

fn regex_parser_body_text(body RegexDisjunction) string {
	mut alternatives := []string{}
	for alternative in body.alternatives {
		mut terms := []string{}
		for term in alternative.terms {
			quantifier := if q := term.quantifier {
				'${q.min}:${if max := q.max { max.str() } else { '-' }}:${regex_parser_bit(q.greedy)}'
			} else {
				'-'
			}
			terms << 'T(${regex_parser_atom_text(term.atom)};${quantifier})'
		}
		alternatives << 'A(${terms.join(',')})'
	}
	return 'D(${alternatives.join('|')})'
}

fn test_regex_parser_preserves_complete_ast_and_errors_from_pinned_source() {
	rows := $embed_file('testdata/regex-parser.tsv').to_string().split_into_lines()
	mut count := 0
	for row in rows {
		if row.len == 0 || row.starts_with('#') { continue }
		fields := row.split('\t')
		assert fields.len == 3, row
		mode := fields[0].int()
		pattern := hex.decode(fields[1])!.bytestr()
		mut actual := ''
		if tree := parse_regex_ast(pattern, RegexAstFlags{ unicode: mode == 1, unicode_sets: mode == 2 }) {
			names := tree.named_groups.map('${it.name}@${it.index}').join(',')
			actual = '=${tree.capture_count}:${names}:${regex_parser_body_text(tree.disjunction)}'
		} else {
			actual = '!${err.msg()}'
		}
		assert actual == fields[2], 'mode=${mode} pattern=${pattern}'
		count++
	}
	assert count == 3018
}

fn test_regex_parser_bounds_deep_groups_and_nested_unicode_sets() {
	for pattern in ['('.repeat(130) + 'a' + ')'.repeat(130), '['.repeat(130) + 'a' + ']'.repeat(130)] {
		if _ := parse_regex_ast(pattern, RegexAstFlags{ unicode_sets: true }) {
			assert false
		} else {
			assert err.msg() == 'regular expression nesting limit exceeded'
		}
	}
}

fn test_regex_parser_records_are_independent_between_calls() {
	first := parse_regex_ast(r'(?<a>x)|(?<a>y)', RegexAstFlags{ unicode_sets: true })!
	assert first.capture_count == 2 && first.named_groups.len == 2
	for _ in 0 .. 8 {
		if _ := parse_regex_ast(r'(?<a>x)(?<a>y)', RegexAstFlags{ unicode_sets: true }) {
			assert false
		} else {
			assert err.msg() == "duplicate group name 'a'"
		}
	}
	last := parse_regex_ast(r'\1(a)', RegexAstFlags{ unicode: true })!
	assert last.capture_count == 1
	assert first.capture_count == 2 && first.named_groups.len == 2
}
