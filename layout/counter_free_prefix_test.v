module layout

import css
import dom
import html

fn test_counter_free_prefix_clears_old_snapshots_and_preserves_the_first_creator_and_later_inheritance() {
	mut document := html.parse_document('<!doctype html><main id="scope">' +
		'<p class="plain">empty</p>'.repeat(64) +
		'<p id="creator" style="counter-reset:n 7"></p><div id="branch"><p id="inherited"></p></div><p id="increment" style="counter-increment:n 2"></p></main>')
	defer { document.finalize() }
	_ = layout_document_typed_in_viewport(document, 320, 200)
	creator := document.get_element_by_id('creator')?
	creator_target := dom.AbstractElement.new(creator, none)
	stale := css.counters_set_for_abstract_element(&creator_target)?
	plain := css.query_selector_all(document.as_node(), '.plain')
	mut builder := TreeBuilderState{}
	for element in plain {
		mut target := dom.AbstractElement.new(element, none)
		css.set_counters_set_for_abstract_element(mut target, stale)
		resolve_layout_counters(mut builder, target, css.computed_properties_for_element(element)?)
		assert css.counters_set_for_abstract_element(&target) == none
	}
	assert builder.counter_tree_order_index == plain.len
	assert builder.counter_sets.len == 0
	last_plain := dom.AbstractElement.new(plain.last(), none)
	assert builder.last_processed_key == abstract_element_counter_key(&last_plain)
	style := css.computed_properties_for_element(creator)?
	resolve_layout_counters(mut builder, creator_target, style)
	actual := css.counters_set_for_abstract_element(&creator_target)?
	parent := abstract_element_counter_parent(&creator_target)?
	mut reference_target := creator_target
	expected := css.resolve_counters_for_layout(mut reference_target, style, css.CounterOriginatingElement{
		id: abstract_element_counter_id(&creator_target)
		parent_id: abstract_element_counter_id(&parent)
		tree_order_index: i64(plain.len + 1)
		debug_description: creator_target.debug_description()
	}, true, none, none, none)?
	assert actual.dump() == expected.dump()
	for id in ['branch', 'inherited', 'increment'] {
		element := document.get_element_by_id(id)?
		target := dom.AbstractElement.new(element, none)
		resolve_layout_counters(mut builder, target, css.computed_properties_for_element(element)?)
		values := css.counters_set_for_abstract_element(&target)?
		assert values.last_counter_with_name('n')?.value? == if id == 'increment' { 9 } else { 7 }
	}
	assert builder.counter_tree_order_index == plain.len + 4
}
