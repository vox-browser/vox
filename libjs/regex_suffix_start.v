module libjs

// Bound the consumed prefix before a mandatory end-anchored character run.
// An unbounded repetition contributes zero only when a literal required by
// every iteration is absent from the whole input. Otherwise the ordinary
// search starts at its original position. The VM still performs every match
// and writes the captures; this plan only skips impossible starting positions.
struct RegexConditionalWidth {
	maximum         u64
	absent_literals []RegexRequiredLiteralHint
}

struct RegexSuffixStartAlternative {
	start_anchor bool
	first        ?RegexSimpleMatch
	tail         ?RegexSimpleMatch
	minimum      u32
	maximum      ?u32
	prefix       RegexConditionalWidth
}

@[heap]
struct RegexSuffixStartPlan {
	alternatives []RegexSuffixStartAlternative
}

pub struct RegexSuffixStartActivity {
pub:
	searches          u64
	skipped_positions u64
	rejections        u64
}

const regex_width_limit = u64(0xffffffffffffffff)

$if test {
	__global regex_suffix_starts_disabled bool
	__global regex_suffix_starts_diagnostics bool
	__global regex_suffix_searches u64
	__global regex_suffix_skipped_positions u64
	__global regex_suffix_rejections u64
	pub fn set_regex_suffix_starts_for_testing(enabled bool) {
		regex_suffix_starts_disabled = !enabled
	}
	pub fn diagnose_regex_suffix_starts_for_testing(enabled bool) RegexSuffixStartActivity {
		previous := RegexSuffixStartActivity{regex_suffix_searches, regex_suffix_skipped_positions, regex_suffix_rejections}
		regex_suffix_searches = 0
		regex_suffix_skipped_positions = 0
		regex_suffix_rejections = 0
		regex_suffix_starts_diagnostics = enabled
		return previous
	}
}

fn use_regex_suffix_starts() bool {
	$if test {
		if regex_suffix_starts_disabled { return false }
	}
	return true
}

fn regex_width_add(left u64, right u64) u64 {
	return if right > regex_width_limit - left { regex_width_limit } else { left + right }
}

fn regex_width_multiply(width u64, count u32) u64 {
	if count == 0 { return 0 }
	return if width > regex_width_limit / u64(count) {
		regex_width_limit
	} else {
		width * u64(count)
	}
}

fn regex_suffix_width_body(body RegexDisjunction) ?RegexConditionalWidth {
	mut width := u64(0)
	mut guards := []RegexRequiredLiteralHint{}
	for alternative in body.alternatives {
		part := regex_suffix_width_alternative(alternative)?
		if part.maximum > width { width = part.maximum }
		guards << part.absent_literals
	}
	return RegexConditionalWidth{ maximum: width, absent_literals: guards }
}

fn regex_suffix_width_alternative(alternative RegexAlternative) ?RegexConditionalWidth {
	mut width := u64(0)
	mut guards := []RegexRequiredLiteralHint{}
	for term in alternative.terms {
		part := regex_suffix_width_term(term)?
		width = regex_width_add(width, part.maximum)
		guards << part.absent_literals
	}
	return RegexConditionalWidth{ maximum: width, absent_literals: guards }
}

fn regex_suffix_width_atom(atom RegexAtom) ?RegexConditionalWidth {
	match atom {
		RegexLiteral {
			return RegexConditionalWidth{ maximum: if atom.code_point > 0xffff {
				u64(2)
			} else {
				u64(1)
			} }
		}
		RegexDot, RegexBuiltinCharacterClass { return RegexConditionalWidth{ maximum: 1 } }
		RegexCharacterClass, RegexUnicodeProperty {
			compiler := RegexBytecodeCompiler{}
			if _ := compiler.simple(atom) { return RegexConditionalWidth{ maximum: 1 } }
			return none
		}
		RegexAssertionKind, RegexLookaround { return RegexConditionalWidth{} }
		RegexGroup { return regex_suffix_width_body(atom.body) }
		RegexNonCapturingGroup { return regex_suffix_width_body(atom.body) }
		else { return none }
	}
}

fn regex_suffix_width_term(term RegexTerm) ?RegexConditionalWidth {
	if quantifier := term.quantifier {
		if maximum := quantifier.max {
			if maximum == 0 { return RegexConditionalWidth{} }
			part := regex_suffix_width_atom(term.atom)?
			return RegexConditionalWidth{ maximum: regex_width_multiply(part.maximum, maximum), absent_literals: part.absent_literals }
		}
		if regex_compiler_atom_zero_width(term.atom) { return RegexConditionalWidth{} }
		analysis := regex_required_atom(term.atom, RegexAstFlags{})
		mut longest := []u16{}
		for literal in analysis.runs { if literal.len > longest.len { longest = literal.clone() } }
		if longest.len == 0 { return none }
		return RegexConditionalWidth{ absent_literals: [RegexRequiredLiteralHint{ literal: longest }] }
	}
	return regex_suffix_width_atom(term.atom)
}

fn regex_suffix_is_anchor(term RegexTerm, anchor RegexAssertionKind) bool {
	atom := term.atom
	return term.quantifier == none && atom is RegexAssertionKind && atom == anchor
}

fn regex_engine_suffix_start_plan(pattern RegexPatternAst, flags RegexAstFlags) ?&RegexSuffixStartPlan {
	if !use_regex_suffix_starts() || flags.unicode || flags.unicode_sets || flags.ignore_case || flags.multiline || flags.sticky {
		return none
	}
	compiler := RegexBytecodeCompiler{ dot_all: flags.dot_all }
	mut alternatives := []RegexSuffixStartAlternative{}
	mut has_suffix := false
	for alternative in pattern.disjunction.alternatives {
		terms := alternative.terms
		if terms.len > 0 && regex_suffix_is_anchor(terms[0], .start_of_input) {
			mut first := ?RegexSimpleMatch(none)
			if terms.len > 1 {
				quantifier := terms[1].quantifier or { RegexQuantifier{ min: 1, max: u32(1), greedy: true } }
				if quantifier.min > 0 {
					if matcher := compiler.simple(terms[1].atom) {
						first = regex_resolve_simple(matcher)
					}
				}
			}
			alternatives << RegexSuffixStartAlternative{ start_anchor: true, first: first }
			continue
		}
		if terms.len < 2 || !regex_suffix_is_anchor(terms.last(), .end_of_input) { return none }
		tail := terms[terms.len - 2]
		quantifier := tail.quantifier or { RegexQuantifier{ min: 1, max: u32(1), greedy: true } }
		if quantifier.min == 0 { return none }
		matcher := compiler.simple(tail.atom) or { return none }
		prefix := regex_suffix_width_alternative(RegexAlternative{ terms: terms[..terms.len - 2] }) or { return none }
		alternatives << RegexSuffixStartAlternative{ tail: regex_resolve_simple(matcher), minimum: quantifier.min, maximum: quantifier.max, prefix: prefix }
		has_suffix = true
	}
	if !has_suffix { return none }
	return &RegexSuffixStartPlan{ alternatives: alternatives }
}

fn (engine &RegexEngine) suffix_start_candidate(input RegexInput, start uint, plan &RegexSuffixStartPlan) ?uint {
	length := input.len()
	if start > length { return none }
	modifiers := RegexActiveModifiers{ dot_all: engine.flags.dot_all }
	mut earliest := ?uint(none)
	for alternative in plan.alternatives {
		if alternative.start_anchor {
			if start > 0 { continue }
			if first := alternative.first {
				if length == 0 || !regex_match_simple_with_modifiers(first, u32(input.code_unit(0)), modifiers) {
					continue
				}
			}
			return 0
		}
		tail := alternative.tail or { return start }
		mut count := uint(0)
		for count < length {
			if maximum := alternative.maximum {
				if count >= uint(maximum) { break }
			}
			if !regex_match_simple_with_modifiers(tail, u32(input.code_unit(length - count - 1)), modifiers) {
				break
			}
			count++
		}
		if count < uint(alternative.minimum) { continue }
		for guard in alternative.prefix.absent_literals {
			if !regex_fails_required_literal_hint(input, 0, RegexPatternHints{ required_literal: guard }) {
				return start
			}
		}
		tail_start := length - count
		mut bound := if u64(tail_start) > alternative.prefix.maximum {
			uint(u64(tail_start) - alternative.prefix.maximum)
		} else {
			uint(0)
		}
		if bound < start { bound = start }
		if previous := earliest {
			if bound < previous { earliest = bound }
		} else {
			earliest = bound
		}
	}
	return earliest
}
