module main

import browserjs
import dom
import x.json2

fn javascript_replay_state(encoded string, mut messages []string) ?map[string]json2.Any {
	value := json2.decode[json2.Any](encoded) or {
		messages << 'JavaScript bridge result: ${err.msg()}'
		return none
	}
	if value !is map[string]json2.Any { return none }
	return value as map[string]json2.Any
}

fn compact_replay_node_keys(value json2.Any, mut keys map[string]bool) {
	if value !is map[string]json2.Any { return }
	state := value as map[string]json2.Any
	if key := json_string_property(state, 'bridgeKey') {
		if key != '' { keys[key] = true }
	}
	if children := state['children'] {
		if children is []json2.Any {
			for child in children as []json2.Any { compact_replay_node_keys(child, mut keys) }
		}
	}
}

fn compact_replay_element_keys(state map[string]json2.Any) []string {
	mut keys := map[string]bool{}
	if elements := state['elements'] {
		if elements is map[string]json2.Any {
			for key, value in elements as map[string]json2.Any {
				if key != '' { keys[key] = true }
				compact_replay_node_keys(value, mut keys)
			}
		}
	}
	if operations := state['operations'] {
		if operations is []json2.Any {
			for value in operations as []json2.Any {
				if value !is map[string]json2.Any { continue }
				operation := value as map[string]json2.Any
				for property in ['target', 'reference', 'endTarget', 'child'] {
					if key := json_string_property(operation, property) {
						if key != '' { keys[key] = true }
					}
				}
				if child := operation['child'] { compact_replay_node_keys(child, mut keys) }
			}
		}
	}
	return keys.keys()
}

fn apply_javascript_runtime_state(document &dom.Document, encoded string,
	runtime &browserjs.Runtime, mut messages []string) ?string {
	state := javascript_replay_state(encoded, mut messages) or { return none }
	note_compact_replay_effects(state, runtime)
	elements := runtime.canvas_elements_for_keys(compact_replay_element_keys(state))
	return apply_decoded_javascript_state(document, state, elements, mut messages)
}

fn note_compact_replay_effects(state map[string]json2.Any, runtime &browserjs.Runtime) {
	mut has_effects := json_bool_property(state, 'bodyHTMLDirty') || json_bool_property(state, 'bodyTextDirty')
	if elements := state['elements'] {
		if elements is map[string]json2.Any { has_effects = has_effects || elements.len > 0 }
	}
	if operations := state['operations'] {
		if operations is []json2.Any { has_effects = has_effects || operations.len > 0 }
	}
	if has_effects {
		mut mutable_runtime := unsafe { &browserjs.Runtime(runtime) }
		mutable_runtime.mark_document_replay_effects()
	}
}
