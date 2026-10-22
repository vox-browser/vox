module dom

// Event-handler map iteration order is unobservable. Keep normal V map storage
// behind one managed pointer rather than allocating an empty map for every node.
@[heap]
struct EventHandlerStorage {
mut:
	handlers map[string]&EventHandler_
}

pub fn (data &EventTargetData) event_handler(name string) ?&EventHandler_ {
	storage := data.event_handler_storage() or { return none }
	if name !in storage.handlers { return none }
	return unsafe { storage.handlers[name] }
}

pub fn (data &EventTargetData) has_event_handler(name string) bool {
	storage := data.event_handler_storage() or { return false }
	return name in storage.handlers
}

pub fn (data &EventTargetData) event_handler_count() int {
	storage := data.event_handler_storage() or { return 0 }
	return storage.handlers.len
}

fn (mut data EventTargetData) store_event_handler(name string, handler &EventHandler_) {
	mut storage := data.event_handler_storage() or {
		mut state := data.copy_cold_data()
		state.handler_storage = &EventHandlerStorage{}
		data.cold_data_ = state
		state.handler_storage
	}
	storage.handlers[name] = handler
}

fn (mut data EventTargetData) remove_event_handler(name string) {
	mut storage := data.event_handler_storage() or { return }
	storage.handlers.delete(name)
}
