// SPDX-License-Identifier: BSD-2-Clause
// Translated from DOM/Document.cpp, HTML/HTMLElement.cpp and
// CSS/Invalidation/ElementStateInvalidator.cpp.
module dom

struct PreviousReadWriteState {
	element &Element
	value   bool
}

fn previous_read_write_states(root &Node) []PreviousReadWriteState {
	mut states := []PreviousReadWriteState{}
	states_ptr := &states
	root.visit_inclusive_subtree(fn [states_ptr] (node &Node) TraversalDecision {
		if element := node.as_element() {
			dom_ptr_push(states_ptr, PreviousReadWriteState{element, element.matches_read_write_pseudo_class()})
		}
		return .@continue
	})
	return states
}

// CSS imports DOM, so the shared selector predicate lives on Element. This is
// also the predicate used when capturing state before an editability change.
pub fn (element &Element) matches_read_write_pseudo_class() bool {
	if element.is_html_element() && element.local_name() in ['input', 'textarea'] {
		return !element.has_attribute('readonly') && element.matches_enabled_pseudo_class()
	}
	return element.as_node().is_editable_or_editing_host()
}

fn (mut element Element) invalidate_style_after_read_write_state_change(was_read_write bool) {
	if was_read_write == element.matches_read_write_pseudo_class() {
		return
	}
	mut node := element.as_node()
	if element.document().style_computer().invalidation_plan_callback == unsafe { nil } {
		node.invalidate_style(.other)
		return
	}
	node.invalidate_style_with_properties(.other, [
		InvalidationProperty{ type_: .pseudo_class, pseudo_class_name: 'read-only' },
		InvalidationProperty{ type_: .pseudo_class, pseudo_class_name: 'read-write' },
	], StyleInvalidationOptions{ invalidate_self: true })
}

fn invalidate_previous_read_write_states(states []PreviousReadWriteState) {
	for state in states {
		mut element := unsafe { &Element(state.element) }
		element.invalidate_style_after_read_write_state_change(state.value)
	}
}
