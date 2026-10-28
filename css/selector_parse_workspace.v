module css

$if prealloc {
	import platform
}

// Parsing only constructs a selector graph: it publishes no DOM, stylesheet or
// global cache state. Retain its final graph, not identifier builders, rejected
// arguments and growing compound/selector vectors.
fn parse_owned_selector(text string) Selector {
	$if prealloc {
		scratch := platform.begin_thread_scratch('selector graph')
		parsed := selector_from_text_impl(text)
		mut copy := ParsedSelectorCopy{}
		copy.prepare(parsed)
		scratch.leave()
		owned := copy.selector(parsed)
		scratch.finish()
		return owned
	}
	return selector_from_text_impl(text)
}

struct ParsedSelectorCopy {
mut:
	selectors map[voidptr]&ParsedSelectorCopyEntry
}

struct ParsedSelectorCopyEntry {
mut:
	data &SelectorData = unsafe { nil }
}

// Reserve memo entries in temporary storage. Publication changes only those
// entries' pointees, so map growth cannot leak into the retained owner. Preserve
// shared SelectorData identities; the freshly parsed graph is acyclic.
fn (mut copy ParsedSelectorCopy) prepare(source Selector) {
	if source.data_ == unsafe { nil } || voidptr(source.data_) in copy.selectors { return }
	copy.selectors[voidptr(source.data_)] = &ParsedSelectorCopyEntry{}
	for compound_index in 0 .. source.data_.compound_selectors.len {
		compound := unsafe { &source.data_.compound_selectors[compound_index] }
		for index in 0 .. compound.simple_selectors.len {
			copy.prepare_simple(unsafe { &compound.simple_selectors[index] })
		}
	}
}

fn (mut copy ParsedSelectorCopy) prepare_pseudo_class(source PseudoClassSelector) {
	for selector in source.argument_selector_list.selectors { copy.prepare(selector) }
}

fn (mut copy ParsedSelectorCopy) prepare_pseudo_element(source PseudoElementSelector) {
	if selector := source.compound_selector { copy.prepare(selector) }
}

fn (mut copy ParsedSelectorCopy) prepare_simple(source &SimpleSelector) {
	match source.payload_kind_ {
		.pseudo_class { copy.prepare_pseudo_class(source.pseudo_class()) }
		.pseudo_element { copy.prepare_pseudo_element(source.pseudo_element()) }
		.expanded {
			copy.prepare_pseudo_class(unsafe { source.payload_.expanded.pseudo_class })
			copy.prepare_pseudo_element(unsafe { source.payload_.expanded.pseudo_element })
		}
		else {}
	}
}

fn own_parsed_selector_name(source SelectorName) SelectorName {
	return SelectorName{ name: source.name.clone(), lowercase_name: source.lowercase_name.clone() }
}

fn own_parsed_qualified_name(source SelectorQualifiedName) SelectorQualifiedName {
	return SelectorQualifiedName{ ...source, namespace_: source.namespace_.clone(), name: own_parsed_selector_name(source.name) }
}

fn own_parsed_selector_attribute(source SelectorAttribute) SelectorAttribute {
	return SelectorAttribute{ ...source, qualified_name: own_parsed_qualified_name(source.qualified_name), value: source.value.clone() }
}

fn own_parsed_selector_strings(source []string) []string {
	mut result := []string{cap: source.len}
	for value in source { result << value.clone() }
	return result
}

fn (mut copy ParsedSelectorCopy) pseudo_class(source PseudoClassSelector) PseudoClassSelector {
	mut selectors := []Selector{cap: source.argument_selector_list.selectors.len}
	for selector in source.argument_selector_list.selectors { selectors << copy.selector(selector) }
	mut ident := ?PseudoClassIdent(none)
	if value := source.ident {
		ident = PseudoClassIdent{ ...value, string_value: value.string_value.clone() }
	}
	return PseudoClassSelector{
		...source
		argument_selector_list: SelectorList{ selectors: selectors }
		languages:              own_parsed_selector_strings(source.languages)
		ident:                  ident
		levels:                 source.levels.clone()
	}
}

fn (mut copy ParsedSelectorCopy) pseudo_element(source PseudoElementSelector) PseudoElementSelector {
	mut compound := ?Selector(none)
	if value := source.compound_selector { compound = copy.selector(value) }
	return PseudoElementSelector{
		...source
		name:              source.name.clone()
		pt_name_selector:  PseudoElementPTNameSelector{ ...source.pt_name_selector, value: source.pt_name_selector.value.clone() }
		compound_selector: compound
		ident_list:        own_parsed_selector_strings(source.ident_list)
	}
}

fn (mut copy ParsedSelectorCopy) simple(source &SimpleSelector) SimpleSelector {
	match source.payload_kind_ {
		.empty { return SimpleSelector{ type_: source.type_ } }
		.name {
			return SimpleSelector.with_name(source.type_, own_parsed_selector_name(source.name()))
		}
		.qualified_name {
			return SimpleSelector.with_qualified_name(source.type_, own_parsed_qualified_name(source.qualified_name()))
		}
		.attribute {
			return SimpleSelector.with_attribute(source.type_, own_parsed_selector_attribute(source.attribute()))
		}
		.pseudo_class {
			return SimpleSelector.with_pseudo_class(source.type_, copy.pseudo_class(source.pseudo_class()))
		}
		.pseudo_element {
			return SimpleSelector.with_pseudo_element(source.type_, copy.pseudo_element(source.pseudo_element()))
		}
		.invalid_text {
			return SimpleSelector.with_invalid_text(source.type_, source.invalid_text().clone())
		}
		.expanded {
			fields := unsafe { source.payload_.expanded }
			return SimpleSelector.create(SimpleSelectorInit{
				type_:          source.type_
				name:           own_parsed_selector_name(fields.name)
				qualified_name: own_parsed_qualified_name(fields.qualified_name)
				attribute:      own_parsed_selector_attribute(fields.attribute)
				pseudo_class:   copy.pseudo_class(fields.pseudo_class)
				pseudo_element: copy.pseudo_element(fields.pseudo_element)
				invalid_text:   fields.invalid_text.clone()
			})
		}
	}
}

fn (mut copy ParsedSelectorCopy) selector(source Selector) Selector {
	if source.data_ == unsafe { nil } { return Selector{} }
	mut entry := copy.selectors[voidptr(source.data_)] or { panic('unprepared parsed selector') }
	if entry.data != unsafe { nil } { return Selector{ data_: entry.data } }
	mut compounds := []CompoundSelector{cap: source.data_.compound_selectors.len}
	for compound_index in 0 .. source.data_.compound_selectors.len {
		compound := unsafe { &source.data_.compound_selectors[compound_index] }
		mut simple := []SimpleSelector{cap: compound.simple_selectors.len}
		for index in 0 .. compound.simple_selectors.len {
			simple << copy.simple(unsafe { &compound.simple_selectors[index] })
		}
		compounds << CompoundSelector{ combinator: compound.combinator, simple_selectors: simple }
	}
	// Recompute the derived pseudo-element snapshot from the owned graph, so its
	// nested selector/ident vectors cannot point back into construction storage.
	mut result := create_selector(source.data_.text.clone(), compounds)
	result.data_.specificity = source.data_.specificity
	result.data_.sibling_invalidation_distance = source.data_.sibling_invalidation_distance
	entry.data = result.data_
	return result
}
