module css

import dom

// These selectors read only the candidate element. Establish the compound
// boundaries and matching context once per query rather than for every node.
// Keep the existing simple-selector matcher for namespaces, attribute operators,
// HTML/XML case rules and quirks-mode ID/class matching.
fn independent_query_compounds(selectors SelectorList) ?[]CompoundSelector {
	if selectors.selectors.len == 0 { return none }
	mut result := []CompoundSelector{cap: selectors.selectors.len}
	for selector in selectors.selectors {
		compounds := selector.compound_selectors()
		if compounds.len != 1 || compounds[0].combinator != .no_combinator
			|| compounds[0].simple_selectors.len == 0 { return none }
		for simple in compounds[0].simple_selectors {
			match simple.type_ {
				.tag_name, .universal, .id, .class, .attribute {}
				else { return none }
			}
		}
		result << compounds[0]
	}
	return result
}

fn independent_query_matches(element &dom.Element, compounds []CompoundSelector,
	mut context MatchContext) bool {
	for compound in compounds {
		if fast_matches_compound_selector(compound, element, none, mut context) {
			return true
		}
	}
	return false
}

fn independent_query_first_in(root &dom.Node, compounds []CompoundSelector,
	mut context MatchContext) ?&dom.Element {
	for child in root.children {
		if element := child.as_element() {
			if independent_query_matches(element, compounds, mut context) { return element }
		}
		if found := independent_query_first_in(child, compounds, mut context) { return found }
	}
	return none
}

fn independent_query_all_in(root &dom.Node, compounds []CompoundSelector,
	mut context MatchContext, mut result []&dom.Element) {
	for child in root.children {
		if element := child.as_element() {
			if independent_query_matches(element, compounds, mut context) { result << element }
		}
		independent_query_all_in(child, compounds, mut context, mut result)
	}
}
