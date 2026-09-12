module css

import dom

fn parsed_counter_property(property_id PropertyID, text string) ?StyleValue {
	return parse_css_value_logic(property_id, text)
}

fn test_reversed_counter_reset_parses_and_serializes() {
	for input, expected in {
		'reversed(sec)':          'reversed(sec)'
		'reversed(sec) 7':        'reversed(sec) 7'
		'reversed(sec) -3 foo 2': 'reversed(sec) -3 foo 2'
		'foo reversed(bar)':      'foo 0 reversed(bar)'
	} {
		value := parsed_counter_property(.counter_reset, input) or {
			panic('could not parse ${input}')
		}
		assert value.serialize(.normal) == expected
	}
}

fn test_reversed_counter_reset_rejects_invalid_names_and_values() {
	assert parsed_counter_property(.counter_reset, 'reversed(none)') == none
	assert parsed_counter_property(.counter_reset, 'reversed(sec) 1.5') == none
}

fn test_reversed_counters_are_only_valid_for_counter_reset() {
	assert parsed_counter_property(.counter_increment, 'reversed(sec)') == none
	assert parsed_counter_property(.counter_set, 'reversed(sec)') == none
}

fn counter_test_origin(id i64) CounterOriginatingElement {
	return CounterOriginatingElement{
		id: id
		tree_order_index: id
	}
}

fn test_counter_value_for_use_instantiates_missing_counter_at_zero() {
	mut counters := CountersSet{}
	origin := counter_test_origin(1)
	assert counters.counter_value_for_use('chapter', origin) == 0
	assert counters.counters().len == 1
	assert counters.last_counter_with_name('chapter') or { panic('missing counter') }.value or {
		-1
	} == 0
}

fn test_list_items_apply_implicit_increment_unless_explicitly_overridden() {
	origin := counter_test_origin(1)
	forward := resolve_counters(CounterElement{
		origin: origin
		is_list_item: true
	})
	assert (forward.counters_set or { panic('missing forward counter') }).last_counter_with_name('list-item') or {
		panic('missing list-item counter')
	}.value or { 0 } == 1

	reversed := resolve_counters(CounterElement{
		origin: origin
		is_list_item: true
		counter_reset: [CounterOperation{
			name: 'list-item'
			is_reversed: true
			value: 4
		}]
	})
	assert (reversed.counters_set or { panic('missing reversed counter') }).last_counter_with_name('list-item') or {
		panic('missing list-item counter')
	}.value or { 0 } == 3

	explicit := resolve_counters(CounterElement{
		origin: origin
		is_list_item: true
		counter_increment: [CounterOperation{
			name: 'list-item'
			value: 5
		}]
	})
	assert (explicit.counters_set or { panic('missing explicit counter') }).last_counter_with_name('list-item') or {
		panic('missing list-item counter')
	}.value or { 0 } == 5
}

fn test_reversed_counter_without_value_counts_implicit_list_item_scope() {
	mut document := dom.Document.create(dom.url_about_blank())
	mut scope := document.create_element_ns('http://www.w3.org/1999/xhtml', 'div')!
	scope.set_attribute_value('style', 'counter-reset: reversed(list-item)')
	mut document_node := unsafe { &dom.Node(document) }
	document_node.append_child(scope.as_node())!
	mut scope_node := scope.as_node()
	mut items := []&dom.Element{}
	for _ in 0 .. 3 {
		mut item := document.create_element_ns('http://www.w3.org/1999/xhtml', 'div')!
		item.set_attribute_value('style', 'display: list-item')
		scope_node.append_child(item.as_node())!
		items << item
	}

	computer := StyleComputer.new(document)
	scope_style := computer.compute_style(dom.AbstractElement.new(scope, none))
	_ = resolve_computed_values(scope_style)
	scope.set_computed_properties(none, computed_properties_to_dom(scope_style))
	for item in items {
		item_style := computer.compute_style(dom.AbstractElement.new(item, none))
		mut mutable_item := unsafe { &dom.Element(item) }
		mutable_item.set_computed_properties(none, computed_properties_to_dom(item_style))
	}
	mut abstract_scope := dom.AbstractElement.new(scope, none)
	assert reversed_counter_start_value('list-item', &abstract_scope, scope_style) == 4

	resolved := resolve_counters_for_layout(mut abstract_scope, scope_style, counter_test_origin(1), false, none, none, none) or { panic('missing resolved counters') }
	counter := resolved.last_counter_with_name('list-item') or { panic('missing reversed counter') }
	assert counter.reversed
	assert counter.value or { 0 } == 4
}
