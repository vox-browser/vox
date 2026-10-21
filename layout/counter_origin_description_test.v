module layout

import css
import dom
import html

fn test_counter_origin_labels_are_retained_only_when_an_operation_can_create_a_counter() {
	mut document := html.parse_document('<!doctype html><div id="scope" style="counter-reset:n 5"><p id="plain">inherited</p><p id="reset" style="counter-reset:m 3"></p><p id="increment" style="counter-increment:n 2"></p><p id="set" style="counter-set:m 9"></p><p id="hidden" style="display:none;counter-reset:n 99"></p><ol><li id="item">implicit</li></ol></div>')
	defer { document.finalize() }
	_ = layout_document_typed_in_viewport(document, 300, 200)
	parent := dom.AbstractElement.new(document.get_element_by_id('scope')?, none)
	inherited := css.counters_set_for_abstract_element(&parent)?
	for id in ['plain', 'reset', 'increment', 'set', 'hidden', 'item'] {
		element := document.get_element_by_id(id)?
		mut target := dom.AbstractElement.new(element, none)
		style := css.computed_properties_for_element(element)?
		description := counter_origin_description(target, style)
		if id in ['plain', 'hidden'] { assert description == '' }
		else { assert description == target.debug_description() }
		full_origin := css.CounterOriginatingElement{
			id: abstract_element_counter_id(target)
			parent_id: abstract_element_counter_id(parent)
			tree_order_index: 10
			debug_description: target.debug_description()
		}
		full := css.resolve_counters_for_layout(mut target, style, full_origin, true, inherited, none, inherited)?
		actual := css.resolve_counters_for_layout(mut target, style,
			css.CounterOriginatingElement{...full_origin, debug_description: description},
			true, inherited, none, inherited)?
		// Compare creator identity and diagnostic strings as well as values.
		assert actual.counters() == full.counters(), id
		assert actual.dump() == full.dump(), id
	}
}
