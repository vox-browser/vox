module page

import dom

// Platform editing dispatches beforeinput before changing the selected text.
// Scripted value setters and execCommand do not pass through this boundary.
pub fn dispatch_editing_beforeinput(document &dom.Document, input_type string, data ?string) bool {
	mut target_ranges := []&dom.StaticRange{}
	if document.active_input_events_target(none) != none {
		input_target := document.active_input_events_target(none) or { return true }
		if input_target.text_control_selection() == none {
			if selection := document.get_selection() {
				if range := selection.range() {
					target_ranges << dom.StaticRange.new(range.start_container(), range.start_offset(),
						range.end_container(), range.end_offset())
				}
			}
		}
	}
	target := document.focused_area() or {
		if body := document.body() { body.as_node() } else { unsafe { &dom.Node(document) } }
	}
	mut event := dom.InputEvent.create_from_platform_event('beforeinput', dom.InputEventInit{
		data: data
		input_type: input_type
	}, target_ranges, dom.current_event_timestamp())
	event.view_ = node_view(target)
	return dom.event_target_dispatch_event(unsafe { &dom.EventTarget(target) }, unsafe { &dom.Event(event) })
}
