module dom

// Keep listener membership inline: its mutable vector deliberately reuses its
// capacity during dispatch and listener churn. Only optional hooks and the live
// event-handler map move out of ordinary EventTargets.
@[heap]
struct EventTargetColdData {
mut:
	changed_target  voidptr
	changed_hook    fn (voidptr)         = unsafe { nil }
	handler_storage &EventHandlerStorage = unsafe { nil }
	parent_context voidptr
	parent_algorithm fn (voidptr, &Event) ?&EventTarget = unsafe { nil }
}

fn (data &EventTargetData) copy_cold_data() &EventTargetColdData {
	if data.cold_data_ == unsafe { nil } { return &EventTargetColdData{} }
	old := data.cold_data_
	return &EventTargetColdData{
		changed_target:  old.changed_target
		changed_hook:    old.changed_hook
		handler_storage: old.handler_storage
		parent_context: old.parent_context
		parent_algorithm: old.parent_algorithm
	}
}

// Non-node interfaces, including IndexedDB requests and transactions, define
// their own DOM "get the parent" algorithm. Ordinary EventTargets have none.
pub fn (mut target EventTarget) set_parent_algorithm(context voidptr, algorithm fn (voidptr, &Event) ?&EventTarget) {
	mut state := target.data.copy_cold_data()
	state.parent_context = context
	state.parent_algorithm = algorithm
	target.data.cold_data_ = state
}

fn (data &EventTargetData) event_handler_storage() ?&EventHandlerStorage {
	if data.cold_data_ == unsafe { nil } || data.cold_data_.handler_storage == unsafe { nil } {
		return none
	}
	return data.cold_data_.handler_storage
}

pub fn (mut data EventTargetData) set_listener_list_changed_hook(target voidptr, hook fn (voidptr)) {
	mut state := data.copy_cold_data()
	state.changed_target = target
	state.changed_hook = hook
	data.cold_data_ = state
}
