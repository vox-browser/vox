module css

import dom

fn empty_counter_style_fixture(style_text string) (&dom.Document, dom.AbstractElement, &ComputedProperties) {
	mut document := dom.Document.create(dom.url_about_blank())
	mut element := document.create_element_ns(dom.namespace_html_uri, 'div') or { panic(err) }
	element.set_attribute_value('style', style_text)
	mut node := unsafe { &dom.Node(document) }
	node.append_child(element.as_node()) or { panic(err) }
	computer := StyleComputer.new(document)
	style := computer.compute_style(dom.AbstractElement.new(element, none))
	_ = resolve_computed_values(style)
	element.set_computed_properties(none, computed_properties_to_dom(style))
	return document, dom.AbstractElement.new(element, none), style
}

fn empty_counter_test_set(value i32) CountersSet {
	return CountersSet{counters_: [Counter{name:'n', originating_element:CounterOriginatingElement{id:1,tree_order_index:1}, value:value}]}
}

fn test_absent_counter_sources_clear_stale_dom_values_without_importing_previous_tree_history() {
	for display in ['block', 'none', 'contents'] {
		mut document, mut owner, style := empty_counter_style_fixture('display:' + display)
		defer { document.finalize() }
		for has_parent in [false, true] {
			for explicit_empty in [false, true] {
				incoming := if explicit_empty { ?CountersSet(CountersSet{}) } else { ?CountersSet(none) }
				previous := empty_counter_test_set(27)
				set_counters_set_for_abstract_element(mut owner, previous)
				assert owner.has_non_empty_counters_set()
				full := resolve_counters(CounterElement{has_parent_element:has_parent,
					generates_box:display!='none',parent_counters:incoming,
					previous_sibling_in_tree_order:incoming,previous_element_in_tree_order:previous})
				actual := resolve_counters_for_layout(mut owner, style, CounterOriginatingElement{id:2},
					has_parent, incoming, incoming, previous)
				assert actual == full.counters_set && actual == none
				assert owner.counters_set() == none
			}
		}
	}
}

fn test_counter_resolution_keeps_incoming_scopes_creators_operations_and_list_numbering() {
	for style_text, expected in {
		'display:block': 9,
		'display:none': 9,
		'display:block;counter-increment:n 3': 12,
		'display:block;counter-set:n 4': 4,
		'display:block;counter-reset:n 6': 6,
	} {
		mut document, mut owner, style := empty_counter_style_fixture(style_text)
		defer { document.finalize() }
		for from_sibling in [false, true] {
			incoming := empty_counter_test_set(5)
			previous := empty_counter_test_set(9)
			parent := if from_sibling { ?CountersSet(none) } else { ?CountersSet(incoming) }
			sibling := if from_sibling { ?CountersSet(incoming) } else { ?CountersSet(none) }
			resolved := resolve_counters_for_layout(mut owner, style,
				CounterOriginatingElement{id:2,tree_order_index:2}, true, parent, sibling, previous)?
			counter := resolved.last_counter_with_name('n')?
			assert counter.value? == expected, style_text
			assert (counter.originating_element.id == 2) == style_text.contains('counter-reset')
		}
	}
	mut document, mut owner, style := empty_counter_style_fixture('display:list-item')
	defer { document.finalize() }
	resolved := resolve_counters_for_layout(mut owner, style, CounterOriginatingElement{id:2},
		true, none, none, none)?
	assert resolved.last_counter_with_name('list-item')?.value? == 1
}
