// Copyright (c) 2026-present, the Ladybird developers.
// SPDX-License-Identifier: BSD-2-Clause
// LibRegex/Rust/src/regex.rs: bounded AST required-literal analysis.
module libjs

struct RegexRequiredAnalysis {
	exact ?[]u16
	runs  [][]u16
}

fn regex_compare_literal(a []u16, b []u16) int {
	length := if a.len < b.len { a.len } else { b.len }
	for index in 0 .. length {
		if a[index] < b[index] { return -1 }
		if a[index] > b[index] { return 1 }
	}
	return if a.len < b.len {
		-1
	} else if a.len > b.len {
		1
	} else {
		0
	}
}

fn regex_contains_literal(haystack []u16, needle []u16) bool {
	if needle.len > haystack.len { return false }
	for index in 0 .. haystack.len - needle.len + 1 {
		if haystack[index..index + needle.len] == needle { return true }
	}
	return false
}

fn regex_prune_required(runs [][]u16) [][]u16 {
	mut ordered := runs.filter(it.len > 0)
	ordered.sort_with_compare(fn (a &[]u16, b &[]u16) int {
		if a.len != b.len { return if a.len > b.len { -1 } else { 1 } }
		return regex_compare_literal(*a, *b)
	})
	mut pruned := [][]u16{}
	for run in ordered {
		mut contained := false
		for existing in pruned {
			if regex_contains_literal(existing, run) {
				contained = true
				break
			}
		}
		if contained { continue }
		pruned << run
		if pruned.len == 16 { break }
	}
	return pruned
}

fn regex_common_required(a []u16, b []u16) [][]u16 {
	shorter, longer := if a.len <= b.len { a, b } else { b, a }
	mut maximum := shorter.len
	if maximum > 64 { maximum = 64 }
	mut substrings := [][]u16{}
	for length := maximum; length > 0; length-- {
		mut windows := map[string]bool{}
		for offset in 0 .. shorter.len - length + 1 {
			windows[shorter[offset..offset + length].map(it.str()).join(',')] = true
		}
		mut matches := map[string][]u16{}
		for offset in 0 .. longer.len - length + 1 {
			window := longer[offset..offset + length]
			key := window.map(it.str()).join(',')
			if key in windows { matches[key] = window.clone() }
		}
		mut candidates := matches.values()
		candidates.sort_with_compare(fn (a &[]u16, b &[]u16) int {
			return regex_compare_literal(*a, *b)
		})
		for candidate in candidates {
			mut contained := false
			for existing in substrings {
				if regex_contains_literal(existing, candidate) {
					contained = true
					break
				}
			}
			if contained { continue }
			substrings << candidate
			if substrings.len == 16 { return substrings }
		}
	}
	return regex_prune_required(substrings)
}

fn regex_required_disjunction(body RegexDisjunction, flags RegexAstFlags) RegexRequiredAnalysis {
	if body.alternatives.len == 0 { return RegexRequiredAnalysis{ exact: []u16{} } }
	first := regex_required_alternative(body.alternatives[0], flags)
	mut exact := first.exact
	mut runs := first.runs.clone()
	for alternative in body.alternatives[1..] {
		analysis := regex_required_alternative(alternative, flags)
		if exact != analysis.exact { exact = none }
		mut common := [][]u16{}
		for left in runs {
			for right in analysis.runs { common << regex_common_required(left, right) }
		}
		runs = regex_prune_required(common)
		if runs.len == 0 && exact == none { break }
	}
	if literal := exact {
		if literal.len > 0 { runs << literal.clone() }
	}
	return RegexRequiredAnalysis{ exact: exact, runs: regex_prune_required(runs) }
}

fn regex_required_alternative(alternative RegexAlternative, flags RegexAstFlags) RegexRequiredAnalysis {
	mut exact := []u16{}
	mut has_exact := true
	mut current := []u16{}
	mut runs := [][]u16{}
	for term in alternative.terms {
		analysis := regex_required_term(term, flags)
		if literal := analysis.exact {
			if has_exact { exact << literal }
			current << literal
			continue
		}
		has_exact = false
		if current.len > 0 {
			runs << current
			current = []u16{}
		}
		runs << analysis.runs
	}
	if current.len > 0 { runs << current }
	if has_exact && exact.len > 0 { runs << exact.clone() }
	return RegexRequiredAnalysis{ exact: if has_exact { ?[]u16(exact) } else { ?[]u16(none) }, runs: regex_prune_required(runs) }
}

fn regex_repeat_required(literal []u16, count u32, exact bool) ?[]u16 {
	if exact && u64(literal.len) * count > 64 { return none }
	mut output := []u16{}
	if literal.len == 0 { return output }
	for _ in 0 .. count {
		for unit in literal {
			if output.len == 64 { return output }
			output << unit
		}
	}
	return output
}

fn regex_required_term(term RegexTerm, flags RegexAstFlags) RegexRequiredAnalysis {
	analysis := regex_required_atom(term.atom, flags)
	q := term.quantifier or { return analysis }
	if q.min == 0 { return RegexRequiredAnalysis{} }
	mut exact := ?[]u16(none)
	mut runs := analysis.runs.clone()
	if literal := analysis.exact {
		if repeated := regex_repeat_required(literal, q.min, false) {
			if repeated.len > 0 { runs << repeated }
		}
		if q.max == ?u32(q.min) { exact = regex_repeat_required(literal, q.min, true) }
	}
	return RegexRequiredAnalysis{ exact: exact, runs: regex_prune_required(runs) }
}

fn regex_required_atom(atom RegexAtom, flags RegexAstFlags) RegexRequiredAnalysis {
	match atom {
		RegexLiteral {
			if (flags.unicode || flags.unicode_sets) && atom.code_point >= 0xd800 && atom.code_point <= 0xdfff {
				return RegexRequiredAnalysis{}
			}
			mut literal := []u16{}
			regex_append_code_point_wtf16(mut literal, atom.code_point) or { return RegexRequiredAnalysis{} }
			return RegexRequiredAnalysis{ exact: literal.clone(), runs: [literal] }
		}
		RegexGroup { return regex_required_disjunction(atom.body, flags) }
		RegexNonCapturingGroup { return regex_required_disjunction(atom.body, flags) }
		RegexModifierGroup {
			if !atom.add_flags.ignore_case && !atom.remove_flags.ignore_case {
				return regex_required_disjunction(atom.body, flags)
			}
		}
		RegexAssertionKind, RegexLookaround { return RegexRequiredAnalysis{ exact: []u16{} } }
		else {}
	}
	return RegexRequiredAnalysis{}
}

fn regex_ast_required_hint(pattern RegexPatternAst, flags RegexAstFlags) ?RegexRequiredLiteralHint {
	analysis := regex_required_disjunction(pattern.disjunction, flags)
	mut literal := []u16{}
	for run in analysis.runs { if run.len >= literal.len { literal = run.clone() } }
	if literal.len == 0 { return none }
	if flags.ignore_case && (flags.unicode || flags.unicode_sets || literal.any(it > 0x7f)) {
		return none
	}
	return RegexRequiredLiteralHint{ literal: literal, ascii_case_insensitive: flags.ignore_case }
}
