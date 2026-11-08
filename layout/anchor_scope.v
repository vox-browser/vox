module layout

import css
import dom

fn anchor_scope_owner(element &dom.Element, name string) ?&dom.Element {
	mut node := ?&dom.Node(element.as_node())
	for node != none {
		current := node or { break }
		if owner := current.as_element() {
			if mirror := owner.computed_properties_for_pseudo(none) {
				if mirror.css_handle != unsafe { nil } {
					computed := unsafe { &css.ComputedProperties(mirror.css_handle) }
					if value := computed.property(.anchor_scope,.yes) {
						if value.css_text == 'all' || value.css_text.split(',').any(it.trim_space() == name) { return owner }
					}
				}
			}
		}
		node = current.parent()
	}
	return none
}

fn anchor_name_scopes_match(candidate &dom.Element, query &Node, name string) bool {
	element := anchor_query_element(query) or { return false }
	candidate_scope := anchor_scope_owner(candidate,name)
	query_scope := if query.pseudo_element_generator() != none { anchor_scope_owner(element,name) }
		else { if parent := element.as_node().parent_element() { anchor_scope_owner(parent,name) } else { none } }
	return voidptr(candidate_scope or { unsafe { nil } }) == voidptr(query_scope or { unsafe { nil } })
}

fn anchor_query_element(node &Node) ?&dom.Element {
	if generator := node.pseudo_element_generator() { return generator }
	return (node.dom_node() or { return none }).as_element()
}
