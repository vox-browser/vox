module css

import os

const disable_simple_selector_construction = os.getenv('VOX_DISABLE_SIMPLE_SELECTOR_CONSTRUCTION') != ''

fn selector_ascii_name_start(byte u8) bool {
	return (byte >= `a` && byte <= `z`) || (byte >= `A` && byte <= `Z`) || byte in [u8(`-`), `_`]
}

fn selector_ascii_name_continue(byte u8) bool {
	return selector_ascii_name_start(byte) || (byte >= `0` && byte <= `9`)
}

// Plain ASCII compounds need no escaping, nested selector graphs or recovery
// builders. Construct their final owned graph directly; every other spelling
// keeps the complete parser and its scratch/publication boundary.
fn simple_owned_selector(input string) ?Selector {
	text := input.trim_space()
	if disable_simple_selector_construction || text.len == 0 { return none }
	mut starts := [16]int{}
	mut ends := [16]int{}
	mut kinds := [16]SimpleSelectorType{}
	mut count := 0
	mut i := 0
	for i < text.len {
		if count == 16 { return none }
		mut kind := SimpleSelectorType.tag_name
		if text[i] == `.` { kind = .class; i++ }
		else if text[i] == `#` { kind = .id; i++ }
		else if count != 0 { return none }
		if i >= text.len || !selector_ascii_name_start(text[i]) { return none }
		if text[i] == `-` && (i + 1 >= text.len || !selector_ascii_name_start(text[i + 1])) { return none }
		starts[count] = i
		kinds[count] = kind
		i++
		for i < text.len && selector_ascii_name_continue(text[i]) { i++ }
		ends[count] = i
		count++
	}
	mut simple := []SimpleSelector{cap:count}
	for index in 0 .. count {
		name := SelectorName.new(text[starts[index]..ends[index]].clone())
		if kinds[index] == .tag_name {
			simple << SimpleSelector.with_qualified_name(.tag_name, SelectorQualifiedName{name:name})
		} else {
			simple << SimpleSelector.with_name(kinds[index], name)
		}
	}
	return create_selector(input.clone(), [CompoundSelector{simple_selectors:simple}])
}
