module page

import dom

// The compact script bridge and editing default actions share the actual
// platform event. A listener can cancel it before the control is changed.
fn (handler &EventHandler) dispatch_keyboard_event(name string,target ?InputTarget,key int,
	code_point u32,modifiers u32,repeat bool) bool {
	value := target or { return true }
	node := value.node or { return true }
	mut event := dom.KeyboardEvent.create_from_platform_event(name,unsafe { dom.KeyCode(key) },modifiers,code_point,repeat)
	event.view_ = node_view(node)
	return dom.event_target_dispatch_event(unsafe { &dom.EventTarget(node) },unsafe { &dom.Event(event) })
}
