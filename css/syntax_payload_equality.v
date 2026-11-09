module css

// Syntax payloads own separate headers, but component equality remains a
// comparison of syntax values, including token spelling and source positions.
// In particular, exporting a graph must not change its equality.
pub fn (a ComponentValue) == (b ComponentValue) bool {
	if a.attr_tainted != b.attr_tainted { return false }
	if a.value is &Token {
		if b.value is &Token { return *a.value == *b.value }
		return false
	}
	if a.value is &Function {
		if b.value is &Function { return *a.value == *b.value }
		return false
	}
	if a.value is &SimpleBlock {
		if b.value is &SimpleBlock { return *a.value == *b.value }
		return false
	}
	if a.value is RawComponentValue {
		if b.value is RawComponentValue { return a.value.text == b.value.text }
		return false
	}
	return b.value is GuaranteedInvalidValue
}
