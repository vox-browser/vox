module css

fn test_child_counter_operations_preserve_parent_and_previous_snapshots() {
	root := CounterOriginatingElement{id: 1, tree_order_index: 1}
	parent := CountersSet{counters_: [Counter{name: 'n', originating_element: root, value: 5}]}
	previous := CountersSet{counters_: [Counter{name: 'n', originating_element: root, value: 7}]}
	for _ in 0 .. 3 {
		child := resolve_retained_counter_state(CounterElement{
			origin: CounterOriginatingElement{id: 2, parent_id: 1, tree_order_index: 2}
			has_parent_element: true
			parent_counters: parent
			previous_element_in_tree_order: previous
			counter_increment: [CounterOperation{name: 'n', value: 2}]
		})?
		assert child.counters_[0].value? == 9
		assert parent.counters_[0].value? == 5
		assert previous.counters_[0].value? == 7
	}
}

fn test_non_box_counter_inheritance_has_independent_value_storage() {
	root := CounterOriginatingElement{id: 1, tree_order_index: 1}
	parent := CountersSet{counters_: [Counter{name: 'n', originating_element: root, value: 5}]}
	mut child := inherit_counters(CounterElement{
		origin: CounterOriginatingElement{id: 2, parent_id: 1, tree_order_index: 2}
		has_parent_element: true
		generates_box: false
		parent_counters: parent
	}).counters_set?
	child.counters_[0].value = 13
	assert parent.counters_[0].value? == 5
}
