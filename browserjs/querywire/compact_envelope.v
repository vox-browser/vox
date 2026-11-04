module querywire

// The native query bridge receives this JSON.stringify envelope frequently.
// Strings in the result are owned by the caller, independent of input storage.
pub struct CompactEnvelope {
pub:
	key string
	action string
	selector string
}

struct StringSpan {
	start int
	end int
}

fn ascii_field(input string, position int, marker string) ?StringSpan {
	if position < 0 || position + marker.len >= input.len { return none }
	if unsafe { input.substr_unsafe(position, position + marker.len) } != marker { return none }
	quote := position + marker.len
	if input[quote] != `"` { return none }
	start := quote + 1
	for index := start; index < input.len; index++ {
		value := input[index]
		if value == `"` { return StringSpan{start: start, end: index} }
		// The general decoder owns JSON escapes, Unicode and unusual forms.
		if value == `\\` || value < 0x20 || value >= 0x7f { return none }
	}
	return none
}

// Accept only the complete, ordered three-string envelope. Rejection means
// "use the general JSON decoder", including its existing syntax/type behavior.
pub fn parse_compact_envelope(input string) ?CompactEnvelope {
	key := ascii_field(input, 0, '{"key":') or { return none }
	action := ascii_field(input, key.end + 1, ',"action":') or { return none }
	selector := ascii_field(input, action.end + 1, ',"selector":') or { return none }
	if selector.end + 2 != input.len || input[input.len - 1] != `}` { return none }
	return CompactEnvelope{
		key: unsafe { input.substr_unsafe(key.start, key.end) }.clone()
		action: unsafe { input.substr_unsafe(action.start, action.end) }.clone()
		selector: unsafe { input.substr_unsafe(selector.start, selector.end) }.clone()
	}
}
