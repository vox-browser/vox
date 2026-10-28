module html

// Named character reference matching for the HTML tokenizer.
//
// Ladybird (C++) uses a generated DAFSA (deterministic acyclic finite state automaton) to match
// named character references one code point at a time while tracking the longest complete match
// and how many code points were "overconsumed" past it (so the tokenizer can backtrack, e.g.
// `&notit` backtracks to `&not`). The generated, sorted fixed table stores
// each name and its one or two code points without runtime maps or vectors.

fn named_char_ref_lower_bound(name string) int {
	mut first := 0
	mut end := named_char_ref_data.len
	for first < end {
		middle := first + (end - first) / 2
		if named_char_ref_data[middle].name < name {
			first = middle + 1
		} else {
			end = middle
		}
	}
	return first
}

$if test {
	fn named_char_ref_has_prefix(prefix string) bool {
		index := named_char_ref_lower_bound(prefix)
		return index < named_char_ref_data.len && named_char_ref_data[index].name.starts_with(prefix)
	}
}

struct NamedCharacterReferenceMatcher {
mut:
	// The characters consumed so far (always ASCII; try_consume rejects code points > 0x7F).
	consumed string
	// The longest prefix of `consumed` that is itself a complete entity name, or '' if none.
	last_match       string
	last_match_index int = -1
}

fn (mut m NamedCharacterReferenceMatcher) reset() {
	m.consumed = ''
	m.last_match = ''
	m.last_match_index = -1
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
	index := named_char_ref_lower_bound(candidate)
	if index == named_char_ref_data.len || !named_char_ref_data[index].name.starts_with(candidate) {
		return false
	}
	m.consumed = candidate
	if named_char_ref_data[index].name == candidate {
		m.last_match = named_char_ref_data[index].name
		m.last_match_index = index
	}
	return true
}

// The code points associated with the last (longest) complete match, if any.
fn (m NamedCharacterReferenceMatcher) code_points() ?NamedCharacterReferenceData {
	if m.last_match_index < 0 || m.last_match_index >= named_char_ref_data.len {
		return none
	}
	return named_char_ref_data[m.last_match_index]
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
	index := named_char_ref_lower_bound(key)
	if index == named_char_ref_data.len || named_char_ref_data[index].name != key {
		return none
	}
	code_points := named_char_ref_data[index]
	mut value := []rune{cap: 2}
	value << rune(code_points.first)
	if code_points.second != 0 {
		value << rune(code_points.second)
	}
	return value.string()
}
