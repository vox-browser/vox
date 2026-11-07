module main

import browserjs
import dom
import platform
import x.json2

struct CompactReplaySnapshot {
	state map[string]json2.Any
	workspace platform.ThreadScratchScope
}

// Replay consumes the JSON containers synchronously. String values installed
// into DOM/control records, diagnostics or navigation keep the document owner.
// Attribute names read directly from map keys are copied by the write boundary.
fn retain_compact_replay_strings(value json2.Any) json2.Any {
	match value {
		string { return json2.Any(value.clone()) }
		[]json2.Any {
			mut items := unsafe { value }
			for index in 0 .. items.len { items[index] = retain_compact_replay_strings(items[index]) }
			return json2.Any(items)
		}
		map[string]json2.Any {
			mut fields := unsafe { value }
			for key, item in fields { fields[key] = retain_compact_replay_strings(item) }
			return json2.Any(fields)
		}
		else { return value }
	}
}

fn compact_query_replay_snapshot(document &dom.Document, encoded string,
	mut messages []string) ?CompactReplaySnapshot {
	$if prealloc {
		if document.native_storage() != unsafe { nil } {
			work := platform.begin_thread_scratch('compact query replay snapshot')
			value := json2.decode[json2.Any](encoded) or {
				work.leave()
				messages << 'JavaScript bridge result: ${err.msg()}'
				work.finish()
				return none
			}
			work.leave()
			if value !is map[string]json2.Any {
				work.finish()
				return none
			}
			retained := retain_compact_replay_strings(value)
			return CompactReplaySnapshot{state: retained as map[string]json2.Any, workspace: work}
		}
	}
	state := javascript_replay_state(encoded, mut messages) or { return none }
	return CompactReplaySnapshot{state: state}
}

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
	mut storage := document.native_storage()
	mut owner := platform.RetainedArenaScope{}
	if storage != unsafe { nil } { owner = storage.enter_nested() }
	defer { owner.finish() }
	replay := compact_query_replay_snapshot(document, encoded, mut messages) or { return none }
	defer { replay.workspace.finish() }
	state := replay.state
	note_compact_replay_effects(state, runtime)
	elements := runtime.canvas_elements_for_keys(compact_replay_element_keys(state))
	navigation := apply_decoded_javascript_state(document, state, elements, mut messages)
	// Deliver reactions queued by this replay; callback writes mark the
	// runtime's document state dirty for the next task replay.
	mut reaction_document := unsafe { &dom.Document(document) }
	reaction_document.invoke_custom_element_reactions()
	return navigation
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
