module css

import platform

fn resolution_workspace_origin(id i64, parent ?i64) CounterOriginatingElement {
	return CounterOriginatingElement{id: id, parent_id: parent, tree_order_index: id,
		debug_description: 'creator ${id}'}
}

fn test_counter_workspace_preserves_creators_reversal_operations_and_neighbor_sources() {
	root := resolution_workspace_origin(1, none)
	parent := CountersSet{counters_: [Counter{name:'chapter', originating_element:root, value:4},
		Counter{name:'reverse', originating_element:root, reversed:true, value:12}]}
	sibling := CountersSet{counters_: [Counter{name:'sibling', originating_element:root, value:7}]}
	previous := CountersSet{counters_: [Counter{name:'chapter', originating_element:root, value:9}]}
	for has_parent in [false, true] {
		for generates_box in [false, true] {
			for list_item in [false, true] {
				element := CounterElement{origin: resolution_workspace_origin(2, 1),
					parent_counters:parent, previous_sibling_in_tree_order:sibling,
					previous_element_in_tree_order:previous, has_parent_element:has_parent,
					generates_box:generates_box, is_list_item:list_item,
					counter_reset:[CounterOperation{name:'nested', value:6},
						CounterOperation{name:'reverse', is_reversed:true, value:8}],
					counter_increment:[CounterOperation{name:'chapter', value:2}],
					counter_set:[CounterOperation{name:'sibling', value:3}]}
				expected := resolve_counters(element).counters_set
				actual := resolve_retained_counter_state(element)
				assert actual == expected
				// A later workspace reset must not destroy the published vector.
				for _ in 0 .. 3 { _ = resolve_retained_counter_state(element) }
				assert actual == expected
			}
		}
	}
}

fn test_counter_resolution_retires_intermediate_vectors_before_publication() {
	$if !prealloc { return }
	mut operations := []CounterOperation{}
	for index in 0 .. 64 { operations << CounterOperation{name:'counter ${index}', value:i32(index)} }
	element := CounterElement{origin: resolution_workspace_origin(2, 1), has_parent_element:true,
		counter_reset:operations, counter_increment:operations, counter_set:operations}
	mut reference_storage := platform.new_arena('counter original retained allocations')
	entry := reference_storage.enter()
	expected := resolve_counters(element).counters_set or { panic('missing original counters') }
	reference_storage.leave(entry)
	mut target := platform.new_arena('counter final retained allocations')
	target_entry := target.enter()
	actual := resolve_retained_counter_state(element) or { panic('missing retained counters') }
	target.leave(target_entry)
	assert actual == expected
	assert actual.counters_.len == 64
	// One exact final vector, owned strings and the workspace descriptor survive.
	assert target.usage().used <= 64 * (sizeof(Counter) + 64) + 512
	assert target.usage().used * 4 < reference_storage.usage().used * 3,
		'${target.usage().used} retained versus ${reference_storage.usage().used}'
	reference_storage.release()
	for index, counter in actual.counters_ {
		assert counter.value? == i32(index)
		assert counter.originating_element.debug_description == 'creator 2'
	}
	target.release()
}
