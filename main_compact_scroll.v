module main

import browserjs
import dom
import platform
import x.json2

struct CompactElementScrollQuery {
	name  string
	value f64
}

// The shared query boundary replays pending DOM/style writes before native
// scrolling, which owns clamping, scroll snapping, events and paint invalidation.
fn compact_element_set_scroll(root &dom.Node, source string, runtime &browserjs.Runtime) !string {
	mut element := root.as_element() or { return error('TypeError: Invalid Element receiver') }
	query := json2.decode[CompactElementScrollQuery](source)!
	mut storage := element.document().native_storage()
	mut allocation_scope := platform.RetainedArenaScope{}
	if storage != unsafe { nil } { allocation_scope = storage.enter_nested() }
	defer { allocation_scope.finish() }
	previous_x := element.scroll_left()
	previous_y := element.scroll_top()
	match query.name {
		'scrollLeft' { element.set_scroll_left(query.value) }
		'scrollTop' { element.set_scroll_top(query.value) }
		else { return error('Invalid element scroll property') }
	}
	if runtime != unsafe { nil }
		&& (previous_x != element.scroll_left() || previous_y != element.scroll_top()) {
		mut mutable_runtime := unsafe { &browserjs.Runtime(runtime) }
		mutable_runtime.mark_document_state_dirty()
		mutable_runtime.mark_document_replay_effects()
	}
	return 'null'
}
