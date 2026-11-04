module css

import dom

fn selector_ascii_lowercase_hash(value string) u32 {
	mut hash := u32(2166136261)
	for byte in value {
		lower := if byte >= `A` && byte <= `Z` { byte + u8(32) } else { byte }
		hash = (hash ^ u32(lower)) * u32(16777619)
	}
	return hash
}

// Visit hashes synchronously. Class spans are borrowed only while hashing;
// neither an intermediate token vector nor folded strings escape this call.
fn (mut filter CountingBloomFilter) update_element_hashes(element &dom.Element, adding bool) {
	filter.update_element_hashes_with_cache(element, adding)
}

fn (mut filter CountingBloomFilter) update_element_hashes_uncached(element &dom.Element, adding bool) {
	filter.update_element_hash(selector_ascii_lowercase_hash(element.local_name()), adding)
	quirks := element.document() != unsafe { nil } && element.document().in_quirks_mode()
	if id := element.id() {
		filter.update_element_hash(if quirks { selector_ascii_lowercase_hash(id) } else { selector_string_hash(id) }, adding)
	}
	if classes := element.get_attribute('class') {
		mut position := 0
		for position < classes.len {
			// Preserve the current fields() delimiters exactly, including its
			// treatment of CR/form-feed as ordinary bytes.
			for position < classes.len && (classes[position] == ` ` || classes[position] == `\t` || classes[position] == `\n`) { position++ }
			start := position
			for position < classes.len && classes[position] != ` ` && classes[position] != `\t` && classes[position] != `\n` { position++ }
			if position == start { break }
			name := unsafe { classes.substr_unsafe(start, position) }
			filter.update_element_hash(if quirks { selector_ascii_lowercase_hash(name) } else { selector_string_hash(name) }, adding)
		}
	}
	if attributes := element.attribute_list() {
		for index in 0 .. attributes.length() {
			if attribute := attributes.item(index) {
				filter.update_element_hash(selector_ascii_lowercase_hash(attribute.name()), adding)
			}
		}
	}
}
