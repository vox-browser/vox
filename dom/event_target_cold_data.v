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
}

fn (data &EventTargetData) copy_cold_data() &EventTargetColdData {
	if data.cold_data_ == unsafe { nil } { return &EventTargetColdData{} }
	old := data.cold_data_
	return &EventTargetColdData{
		changed_target:  old.changed_target
		changed_hook:    old.changed_hook
		handler_storage: old.handler_storage
	}
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
