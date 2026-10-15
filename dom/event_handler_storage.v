module dom

// Event-handler map iteration order is unobservable. Keep normal V map storage
// behind one managed pointer rather than allocating an empty map for every node.
@[heap]
struct EventHandlerStorage {
mut:
	handlers map[string]&EventHandler_
}

pub fn (data &EventTargetData) event_handler(name string) ?&EventHandler_ {
	if data.handler_storage_ == unsafe { nil } || name !in data.handler_storage_.handlers {
		return none
	}
	return unsafe { data.handler_storage_.handlers[name] }
}

pub fn (data &EventTargetData) has_event_handler(name string) bool {
	return data.handler_storage_ != unsafe { nil } && name in data.handler_storage_.handlers
}

pub fn (data &EventTargetData) event_handler_count() int {
	if data.handler_storage_ == unsafe { nil } { return 0 }
	return data.handler_storage_.handlers.len
}

fn (mut data EventTargetData) store_event_handler(name string, handler &EventHandler_) {
	if data.handler_storage_ == unsafe { nil } {
		data.handler_storage_ = &EventHandlerStorage{}
	}
	data.handler_storage_.handlers[name] = handler
}

fn (mut data EventTargetData) remove_event_handler(name string) {
	if data.handler_storage_ == unsafe { nil } { return }
	data.handler_storage_.handlers.delete(name)
}
