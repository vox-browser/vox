module dom

// Published records are immutable. A Node value copy keeps its old membership
// and slot state, while registered observers and slots remain live DOM objects.
@[heap]
struct NodeColdData {
mut:
	registered_observers   []&RegisteredObserver
	slottable_name         string
	assigned_slot          ?&HTMLSlotElement
	manual_slot_assignment ?&HTMLSlotElement
}

fn (node &Node) copy_cold_data() &NodeColdData {
	if node.cold_data_ == unsafe { nil } { return &NodeColdData{} }
	old := node.cold_data_
	return &NodeColdData{
		registered_observers:   old.registered_observers
		slottable_name:         old.slottable_name
		assigned_slot:          old.assigned_slot
		manual_slot_assignment: old.manual_slot_assignment
	}
}

fn (node &Node) registered_observers() []&RegisteredObserver {
	if node.cold_data_ == unsafe { nil } { return []&RegisteredObserver{} }
	return node.cold_data_.registered_observers
}

fn (mut node Node) remove_registered_observer_at(index int) {
	mut state := node.copy_cold_data()
	state.registered_observers = state.registered_observers.clone()
	state.registered_observers.delete(index)
	node.cold_data_ = state
}

fn (mut node Node) clear_registered_observers() {
	if node.registered_observers().len == 0 { return }
	mut state := node.copy_cold_data()
	state.registered_observers = []&RegisteredObserver{}
	node.cold_data_ = state
}
