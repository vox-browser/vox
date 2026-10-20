module html

// Named character reference matching for the HTML tokenizer.
//
// Ladybird (C++) uses a generated DAFSA (deterministic acyclic finite state automaton) to match
// named character references one code point at a time while tracking the longest complete match
// and how many code points were "overconsumed" past it (so the tokenizer can backtrack, e.g.
// `&notit` backtracks to `&not`). The generated code-point map provides the
// complete matches. A sorted index of its existing names answers prefix queries
// without retaining a second hash table containing every partial entity name.

const named_char_ref_names = build_named_char_ref_names()

fn build_named_char_ref_names() []string {
	mut names := named_char_ref_codepoints.keys()
	names.sort()
	return names
}

fn named_char_ref_has_prefix(prefix string) bool {
	mut first := 0
	mut end := named_char_ref_names.len
	for first < end {
		middle := first + (end - first) / 2
		if named_char_ref_names[middle] < prefix {
			first = middle + 1
		} else {
			end = middle
		}
	}
	return first < named_char_ref_names.len && named_char_ref_names[first].starts_with(prefix)
}

struct NamedCharacterReferenceMatcher {
mut:
	// The characters consumed so far (always ASCII; try_consume rejects code points > 0x7F).
	consumed string
	// The longest prefix of `consumed` that is itself a complete entity name, or '' if none.
	last_match string
}

fn (mut m NamedCharacterReferenceMatcher) reset() {
	m.consumed = ''
	m.last_match = ''
}

// If `c` is the code point of a child of the current node, advances and returns true.
fn (mut m NamedCharacterReferenceMatcher) try_consume_code_point(c rune) bool {
	if c > 0x7F {
		return false
	}
	return m.try_consume_ascii_char(u8(c))
}

fn (mut m NamedCharacterReferenceMatcher) try_consume_ascii_char(c u8) bool {
	candidate := m.consumed + c.ascii_str()
	if !named_char_ref_has_prefix(candidate) {
		return false
	}
	m.consumed = candidate
	if candidate in named_char_ref_codepoints {
		m.last_match = candidate
	}
	return true
}

// The code points associated with the last (longest) complete match, if any.
fn (m &NamedCharacterReferenceMatcher) code_points() ?[]u32 {
	if m.last_match == '' {
		return none
	}
	return named_char_ref_codepoints[m.last_match]
}

fn (m &NamedCharacterReferenceMatcher) last_match_ends_with_semicolon() bool {
	return m.last_match.ends_with(';')
}

// How many code points were consumed past the end of the longest complete match.
fn (m &NamedCharacterReferenceMatcher) overconsumed_code_points() int {
	return m.consumed.len - m.last_match.len
}

// XMLDocumentBuilder's LibXML callback resolves only complete, semicolon-
// terminated named HTML references. Expose the generated table without
// exposing the tokenizer's incremental matcher.
pub fn resolve_named_character_reference(name string) ?string {
	key := if name.ends_with(';') { name } else { name + ';' }
	code_points := named_char_ref_codepoints[key] or { return none }
	mut value := []rune{cap: code_points.len}
	for code_point in code_points {
		value << rune(code_point)
	}
	return value.string()
}
