module css

import dom

// Selector-matching entry points that the DOM needs (querySelector / matches / closest).
// These live in the css module, not dom, because they need the CSS selector parser and
// SelectorEngine, and dom cannot import css (that would be a module cycle: css imports dom).
// This mirrors upstream, where SelectorEngine is part of CSS. The dom-side
// Element.query_selector methods remain stubs; use these functions instead.
//
// FIXME: `:scope` and relative selectors are matched without a scoping root here, so they
// behave as if unscoped. The common selectors (type / #id / .class / attribute / combinators
// / pseudo-classes) work.

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
	selectors := parse_query_selector_list(selector_text) or { return none }
	return query_selector_first_in(root, selectors)
}

// https://dom.spec.whatwg.org/#dom-parentnode-queryselectorall
pub fn query_selector_all(root &dom.Node, selector_text string) []&dom.Element {
	mut results := []&dom.Element{}
	selectors := parse_query_selector_list(selector_text) or { return results }
	query_selector_all_in(root, selectors, mut results)
	return results
}

// https://dom.spec.whatwg.org/#dom-element-closest
// Returns `element` or its nearest inclusive ancestor element that matches the selector.
pub fn closest_matching_selector(element &dom.Element, selector_text string) ?&dom.Element {
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
