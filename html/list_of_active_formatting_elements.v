module html

import dom

// Translation of Libraries/LibWeb/HTML/Parser/ListOfActiveFormattingElements.{h,cpp}.
// https://html.spec.whatwg.org/multipage/parsing.html#list-of-active-formatting-elements

const noahs_ark_capacity = 3

pub struct ActiveFormattingElement {
pub mut:
	// A null element marks a "marker" entry.
	element ?&dom.Element
	token   ?&HTMLToken
}

pub fn (e &ActiveFormattingElement) is_marker() bool {
	return e.element == none
}

// Upstream names the nested record Entry; the V port gives it a descriptive
// module-level name because V has no nested types.
pub fn entry_is_marker(entry &ActiveFormattingElement) bool {
	return entry.is_marker()
}

pub struct ListOfActiveFormattingElements {
pub mut:
	entries []ActiveFormattingElement
}

pub fn (l &ListOfActiveFormattingElements) is_empty() bool {
	return l.entries.len == 0
}

pub fn (l &ListOfActiveFormattingElements) entries() []ActiveFormattingElement {
	return l.entries
}

pub fn (l &ListOfActiveFormattingElements) contains(element &dom.Element) bool {
	for entry in l.entries {
		if el := entry.element {
			if same_element(el, element) {
				return true
			}
		}
	}
	return false
}

// A fresh HTMLToken carrying only the type, tag name, and attributes of `token` (as required by the
// spec: the attributes must be compared as they were when created by the parser).
fn create_own_token(token &HTMLToken) &HTMLToken {
	mut new_token := &HTMLToken{
		type_: token.type_
		attributes: []Attribute{cap: token.attributes.len}
	}
	new_token.tag_name = token.tag_name
	for attribute in token.attributes {
		new_token.attributes << unsafe { attribute }
	}
	return new_token
}

pub fn (list &ListOfActiveFormattingElements) create_own_token(token &HTMLToken) &HTMLToken {
	_ = list
	return create_own_token(token)
}

// https://html.spec.whatwg.org/multipage/parsing.html#push-onto-the-list-of-active-formatting-elements
pub fn (mut l ListOfActiveFormattingElements) add(element &dom.Element, token &HTMLToken) {
	l.ensure_noahs_ark_clause(element)
	l.entries << ActiveFormattingElement{
		element: element
		token:   create_own_token(token)
	}
}

pub fn (mut l ListOfActiveFormattingElements) add_marker() {
	l.entries << ActiveFormattingElement{
		element: none
		token:   none
	}
}

pub fn (mut l ListOfActiveFormattingElements) insert_at(index int, element &dom.Element, token &HTMLToken) {
	l.entries.insert(index, ActiveFormattingElement{
		element: element
		token:   create_own_token(token)
	})
}

pub fn (mut l ListOfActiveFormattingElements) replace(to_remove &dom.Element, to_add &dom.Element, token &HTMLToken) {
	for i, entry in l.entries {
		if el := entry.element {
			if same_element(el, to_remove) {
				l.entries[i].element = to_add
				l.entries[i].token = create_own_token(token)
				break
			}
		}
	}
}

pub fn (mut l ListOfActiveFormattingElements) remove(element &dom.Element) {
	for i, entry in l.entries {
		if el := entry.element {
			if same_element(el, element) {
				l.entries.delete(i)
				return
			}
		}
	}
}

pub fn (l &ListOfActiveFormattingElements) last_element_with_tag_name_before_marker(tag_name string) ?&dom.Element {
	for i := l.entries.len - 1; i >= 0; i-- {
		entry := l.entries[i]
		if entry.is_marker() {
			return none
		}
		if el := entry.element {
			if el.local_name() == tag_name {
				return el
			}
		}
	}
	return none
}

pub fn (mut l ListOfActiveFormattingElements) clear_up_to_the_last_marker() {
	for l.entries.len > 0 {
		entry := l.entries.pop()
		if entry.is_marker() {
			break
		}
	}
}

pub fn (l &ListOfActiveFormattingElements) find_index(element &dom.Element) ?int {
	for i, entry in l.entries {
		if el := entry.element {
			if same_element(el, element) {
				return i
			}
		}
	}
	return none
}

// The Noah's Ark clause: if there are already three entries after the last marker with the same
// tag name, namespace, and attributes as `element`, remove the earliest such entry.
fn (mut l ListOfActiveFormattingElements) ensure_noahs_ark_clause(element &dom.Element) {
	// Candidates match on tag name, namespace, and attribute count. Collected in reverse order, so
	// the indices are descending (the last one is the earliest entry).
	mut candidate_indices := []int{}
	for i := l.entries.len - 1; i >= 0; i-- {
		entry := l.entries[i]
		if entry.is_marker() {
			break
		}
		el := entry.element or { continue }
		tok := entry.token or { continue }
		if el.local_name() == element.local_name() && (el.namespace_uri() or { '' }) == (element.namespace_uri() or {
			''
		}) && tok.attribute_count() == element.attribute_list_size() {
			candidate_indices << i
		}
	}

	if candidate_indices.len < noahs_ark_capacity {
		return
	}

	// Keep only candidates whose token has every one of `element`'s attributes with equal values
	// (counts already matched, so equal-or-superset means equal).
	names := element.get_attribute_names()
	mut kept := []int{}
	for idx in candidate_indices {
		tok := l.entries[idx].token or { continue }
		mut all_match := true
		for name in names {
			value := element.get_attribute(name) or { '' }
			token_value := tok.attribute(name) or {
				all_match = false
				break
			}
			if token_value != value {
				all_match = false
				break
			}
		}
		if all_match {
			kept << idx
		}
	}

	if kept.len < noahs_ark_capacity {
		return
	}

	// Remove the earliest matching entry (smallest index; last in the descending list).
	earliest_index := kept[kept.len - 1]
	if el := l.entries[earliest_index].element {
		l.remove(el)
	}
}
