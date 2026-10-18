module css

import dom

// Selector-matching entry points that the DOM needs (querySelector / matches / closest).
// These live in css because they need the selector parser and SelectorEngine. The callback bridge
// below lets the standard DOM APIs use them without creating a dom <-> css import cycle.

@[heap]
struct DocumentSelectorQueryState {
mut:
	parsed  map[string]SelectorList
	invalid map[string]bool
}

fn (mut state DocumentSelectorQueryState) parse(selector_text string) ?SelectorList {
	if selector_text in state.invalid {
		return none
	}
	if parsed := state.parsed[selector_text] {
		return parsed
	}
	parsed := parse_query_selector_list(selector_text) or {
		state.invalid[selector_text] = true
		return none
	}
	state.parsed[selector_text] = parsed
	return parsed
}

fn dom_selector_query_validate(target voidptr, selector_text string) bool {
	mut state := unsafe { &DocumentSelectorQueryState(target) }
	return state.parse(selector_text) != none
}

fn selector_list_contains_named_namespace(selectors SelectorList) bool {
	for selector in selectors.selectors {
		for compound_selector in selector.compound_selectors() {
			for simple_selector in compound_selector.simple_selectors {
				if simple_selector.type_ in [.tag_name, .universal]
					&& simple_selector.qualified_name().namespace_type == .named {
					return true
				}
				if simple_selector.type_ == .attribute
					&& simple_selector.attribute().qualified_name.namespace_type == .named {
					return true
				}
				if simple_selector.type_ == .pseudo_class
					&& selector_list_contains_named_namespace(simple_selector.pseudo_class().argument_selector_list) {
					return true
				}
			}
		}
	}
	return false
}

fn dom_selector_query_contains_named_namespace(target voidptr, selector_text string) bool {
	mut state := unsafe { &DocumentSelectorQueryState(target) }
	selectors := state.parse(selector_text) or { return false }
	return selector_list_contains_named_namespace(selectors)
}

fn dom_selector_query_matches(target voidptr, selector_text string, element &dom.Element, scoping_root &dom.ParentNode) bool {
	mut state := unsafe { &DocumentSelectorQueryState(target) }
	selectors := state.parse(selector_text) or { return false }
	for selector in selectors.selectors {
		mut context := MatchContext{has_result_cache: unsafe { nil }}
		if matches(selector, element, none, mut context, none, scoping_root, .normal, none) {
			return true
		}
	}
	return false
}

pub fn install_document_selector_query_hook(document &dom.Document) {
	if hook := document.selector_query_hook() {
		if hook.validate == dom_selector_query_validate
			&& hook.matches == dom_selector_query_matches
			&& hook.contains_named_namespace == dom_selector_query_contains_named_namespace {
			return
		}
	}
	state := &DocumentSelectorQueryState{
		parsed:  map[string]SelectorList{}
		invalid: map[string]bool{}
	}
	mut mutable_document := unsafe { &dom.Document(document) }
	mutable_document.set_selector_query_hook(dom.DocumentSelectorQueryHook{
		target:                   voidptr(state)
		validate:                 dom_selector_query_validate
		matches:                  dom_selector_query_matches
		contains_named_namespace: dom_selector_query_contains_named_namespace
	})
}

fn parse_query_selector_list(selector_text string) ?SelectorList {
	return parse_selector_with_parser(selector_text, map[string]bool{})
}

fn element_matches_any(element &dom.Element, selectors SelectorList) bool {
	for selector in selectors.selectors {
		if selector_matches(selector, element) {
			return true
		}
	}
	return false
}

// https://dom.spec.whatwg.org/#dom-element-matches
pub fn element_matches_selector(element &dom.Element, selector_text string) bool {
	install_document_selector_query_hook(element.document())
	selectors := parse_query_selector_list(selector_text) or { return false }
	return element_matches_any(element, selectors)
}

fn query_selector_first_in(node &dom.Node, selectors SelectorList) ?&dom.Element {
	for child in node.children {
		if element := child.as_element() {
			if element_matches_any(element, selectors) {
				return element
			}
		}
		if found := query_selector_first_in(child, selectors) {
			return found
		}
	}
	return none
}

fn query_selector_all_in(node &dom.Node, selectors SelectorList, mut results []&dom.Element) {
	for child in node.children {
		if element := child.as_element() {
			if element_matches_any(element, selectors) {
				results << element
			}
		}
		query_selector_all_in(child, selectors, mut results)
	}
}

// https://dom.spec.whatwg.org/#dom-parentnode-queryselector
// Returns the first descendant element of `root` (in tree order) that matches the selector.
pub fn query_selector(root &dom.Node, selector_text string) ?&dom.Element {
	install_document_selector_query_hook(root.document())
	selectors := parse_query_selector_list(selector_text) or { return none }
	if compounds := independent_query_compounds(selectors) {
		mut context := MatchContext{has_result_cache: unsafe { nil }}
		return independent_query_first_in(root, compounds, mut context)
	}
	return query_selector_first_in(root, selectors)
}

// https://dom.spec.whatwg.org/#dom-parentnode-queryselectorall
pub fn query_selector_all(root &dom.Node, selector_text string) []&dom.Element {
	mut results := []&dom.Element{}
	install_document_selector_query_hook(root.document())
	selectors := parse_query_selector_list(selector_text) or { return results }
	if compounds := independent_query_compounds(selectors) {
		mut context := MatchContext{has_result_cache: unsafe { nil }}
		independent_query_all_in(root, compounds, mut context, mut results)
		return results
	}
	query_selector_all_in(root, selectors, mut results)
	return results
}

// https://dom.spec.whatwg.org/#dom-element-closest
// Returns `element` or its nearest inclusive ancestor element that matches the selector.
pub fn closest_matching_selector(element &dom.Element, selector_text string) ?&dom.Element {
	install_document_selector_query_hook(element.document())
	selectors := parse_query_selector_list(selector_text) or { return none }
	mut current := ?&dom.Element(element)
	for {
		candidate := current or { break }
		if element_matches_any(candidate, selectors) {
			return candidate
		}
		current = candidate.as_node().parent_element()
	}
	return none
}
