module css

import dom
import platform

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
	// The document keeps parsed selectors for its lifetime. The first query
	// for a selector can come from a temporary scope, such as select sizing
	// inside a flex item's intrinsic layout probe: parse and grow both maps
	// outside it, from a persistent copy of the text the selector may slice.
	persistent := platform.enter_persistent()
	defer { platform.leave_persistent(persistent) }
	key := selector_text.clone()
	parsed := parse_query_selector_list(key) or {
		state.invalid[key] = true
		return none
	}
	state.parsed[key] = parsed
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
	scratch := platform.begin_thread_scratch('DOM selector namespace check')
	defer { scratch.finish() }
	return selector_list_contains_named_namespace(selectors)
}

// These compounds only read element names and attributes. Their matching
// vectors cannot escape the callback; parsed selectors keep document storage.
fn independent_element_matches(element &dom.Element, selectors SelectorList) ?bool {
	scratch := platform.begin_thread_scratch('independent element match')
	defer { scratch.finish() }
	compounds := independent_query_compounds(selectors) or { return none }
	mut context := MatchContext{has_result_cache: unsafe { nil }}
	return independent_query_matches(element, compounds, mut context)
}

fn dom_selector_query_matches(target voidptr, selector_text string, element &dom.Element, scoping_root &dom.ParentNode) bool {
	mut state := unsafe { &DocumentSelectorQueryState(target) }
	selectors := state.parse(selector_text) or { return false }
	if result := independent_element_matches(element, selectors) { return result }
	return general_query_matches(element, selectors, scoping_root)
}

// Parse/cache ownership is established by the caller before entering this
// workspace. A one-shot query publishes only its boolean; relational matching
// contexts and :has() memoization do not belong to the document's lifetime.
fn general_query_matches(element &dom.Element, selectors SelectorList,
	scoping_root ?&dom.ParentNode) bool {
	scratch := platform.begin_thread_scratch('general element match')
	defer { scratch.finish() }
	for selector in selectors.selectors {
		mut context := MatchContext{has_result_cache: unsafe { nil }}
		if matches(selector, element, none, mut context, none, scoping_root, .normal, none) {
			return true
		}
	}
	return false
}

fn dom_selector_scope_query(target voidptr, selector_text string, root &dom.ParentNode,
	first bool) ?[]&dom.Node {
	mut state := unsafe { &DocumentSelectorQueryState(target) }
	selectors := state.parse(selector_text) or { return none }
	// Parsed selectors are document-owned. Only the independent matching walk
	// and its temporary vectors belong to this synchronous workspace.
	scratch := platform.begin_thread_scratch('independent DOM query')
	defer { scratch.finish() }
	compounds := independent_query_compounds(selectors) or { return none }
	if !independent_query_may_match_document(root.as_node(), compounds) {
		scratch.leave()
		return []&dom.Node{}
	}
	mut context := MatchContext{has_result_cache: unsafe { nil }}
	mut nodes := []&dom.Node{}
	if first {
		if element := independent_query_first_in(root.as_node(), compounds, mut context) {
			nodes << element.as_node()
		}
	} else {
		mut elements := []&dom.Element{}
		independent_query_all_in(root.as_node(), compounds, mut context, mut elements)
		for element in elements { nodes << element.as_node() }
	}
	scratch.leave()
	return nodes.clone()
}

pub fn install_document_selector_query_hook(document &dom.Document) {
	if hook := document.selector_query_hook() {
		if hook.validate == dom_selector_query_validate
			&& hook.matches == dom_selector_query_matches
			&& hook.contains_named_namespace == dom_selector_query_contains_named_namespace
			&& hook.scope_query == dom_selector_scope_query {
			return
		}
	}
	persistent := platform.enter_persistent()
	state := &DocumentSelectorQueryState{
		parsed:  map[string]SelectorList{}
		invalid: map[string]bool{}
	}
	platform.leave_persistent(persistent)
	mut mutable_document := unsafe { &dom.Document(document) }
	mutable_document.set_selector_query_hook(dom.DocumentSelectorQueryHook{
		target:                   voidptr(state)
		validate:                 dom_selector_query_validate
		matches:                  dom_selector_query_matches
		contains_named_namespace: dom_selector_query_contains_named_namespace
		scope_query:              dom_selector_scope_query
	})
}

fn parse_query_selector_list(selector_text string) ?SelectorList {
	return parse_selector_with_parser(selector_text, map[string]bool{})
}

// CSS-side callers and the DOM callback bridge belong to the same document.
// Share their immutable parsed selectors, while each match still reads live
// element state and creates its own relational matching context.
fn document_query_selector_list(document &dom.Document, selector_text string) ?SelectorList {
	install_document_selector_query_hook(document)
	hook := document.selector_query_hook() or { return none }
	mut state := unsafe { &DocumentSelectorQueryState(hook.target) }
	return state.parse(selector_text)
}

fn element_matches_any(element &dom.Element, selectors SelectorList) bool {
	if result := independent_element_matches(element, selectors) { return result }
	return general_query_matches(element, selectors, none)
}

// https://dom.spec.whatwg.org/#dom-element-matches
pub fn element_matches_selector(element &dom.Element, selector_text string) bool {
	selectors := document_query_selector_list(element.document(), selector_text) or { return false }
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
	selectors := document_query_selector_list(root.document(), selector_text) or { return none }
	scratch := platform.begin_thread_scratch('independent DOM query')
	if compounds := independent_query_compounds(selectors) {
		if !independent_query_may_match_document(root, compounds) {
			scratch.finish()
			return none
		}
		mut context := MatchContext{has_result_cache: unsafe { nil }}
		found := independent_query_first_in(root, compounds, mut context)
		scratch.finish()
		return found
	}
	scratch.finish()
	return query_selector_first_in(root, selectors)
}

// https://dom.spec.whatwg.org/#dom-parentnode-queryselectorall
pub fn query_selector_all(root &dom.Node, selector_text string) []&dom.Element {
	// The universal selector matches every element in any namespace. Native
	// script hosts index whole documents this way, so skip the matcher.
	if selector_text == '*' {
		mut elements := []&dom.Element{}
		collect_descendant_elements(root, mut elements)
		return elements
	}
	selectors := document_query_selector_list(root.document(), selector_text) or { return []&dom.Element{} }
	scratch := platform.begin_thread_scratch('independent DOM query')
	if compounds := independent_query_compounds(selectors) {
		if !independent_query_may_match_document(root, compounds) {
			scratch.finish()
			return []&dom.Element{}
		}
		mut context := MatchContext{has_result_cache: unsafe { nil }}
		mut results := []&dom.Element{}
		independent_query_all_in(root, compounds, mut context, mut results)
		scratch.leave()
		owned := results.clone()
		scratch.finish()
		return owned
	}
	scratch.finish()
	mut results := []&dom.Element{}
	query_selector_all_in(root, selectors, mut results)
	return results
}

fn collect_descendant_elements(root &dom.Node, mut elements []&dom.Element) {
	for child in root.children {
		if element := child.as_element() { elements << element }
		if child.children.len > 0 { collect_descendant_elements(child, mut elements) }
	}
}

// https://dom.spec.whatwg.org/#dom-element-closest
// Returns `element` or its nearest inclusive ancestor element that matches the selector.
pub fn closest_matching_selector(element &dom.Element, selector_text string) ?&dom.Element {
	selectors := document_query_selector_list(element.document(), selector_text) or { return none }
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
