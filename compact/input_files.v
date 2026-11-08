module main

import browserjs
import dom
import platform
import x.json2

fn (mut binding CompactElementQueryBinding) input_files(key string, state string, write bool, value voidptr) !voidptr {
	mut allocation := platform.RetainedArenaScope{}
	mut storage := binding.document.native_storage()
	if storage != unsafe { nil } { allocation = storage.enter_nested() }
	defer { allocation.finish() }
	owned_key := key.clone()
	encoded := if state == '' { json2.Any(json2.Null{}) } else { json2.decode[json2.Any](state.clone())! }
	node := binding.equality_node(owned_key, encoded)!
	element := node.as_element() or { return error('TypeError: Invalid HTMLInputElement receiver') }
	if !element.is_html_element() || element.local_name() != 'input' {
		return error('TypeError: Invalid HTMLInputElement receiver')
	}
	input := unsafe { &dom.HTMLInputElement(element) }
	mut runtime := unsafe { &browserjs.Runtime(binding.runtime) }
	if write {
		runtime.set_javascript_input_files(input, value)!
		runtime.mark_document_state_dirty()
		runtime.mark_document_replay_effects()
	}
	return runtime.javascript_input_files(input)
}
