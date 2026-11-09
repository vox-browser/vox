module main

import browserjs
import dom
import platform

// Native host APIs use the same pending-state handoff as compact queries.
// Console output and navigation remain queued for the task owner. A replay
// failure rejects the host operation instead of letting it read stale DOM.
fn flush_compact_dom_mutations(document &dom.Document, runtime &browserjs.Runtime) ! {
	state := runtime.evaluate_host_temporary_text('__ladybirdFinalize(true)')!
	defer { state.finish() }
	mut messages := []string{}
	apply_javascript_runtime_state(document, state.value, runtime, mut messages)
	if messages.len != 0 { return error(messages.join('\n')) }
}

// Reactions may reenter JavaScript and enqueue another compact batch. Settle
// those writes before the next native read or paint, without consuming logs or
// repeatedly replaying canvas transport. Each batch is detached before replay.
fn settle_compact_dom_reactions(document &dom.Document, runtime &browserjs.Runtime,
	mut messages []string) ! {
	mut owner := unsafe { &dom.Document(document) }
	if !owner.has_pending_custom_element_reactions() { return }
	mut storage := document.native_storage()
	mut scope := if storage != unsafe { nil } {
		storage.enter_nested()
	} else {
		platform.RetainedArenaScope{}
	}
	persistent := platform.enter_persistent_if(storage == unsafe { nil } && platform.transient_arena_entered())
	defer {
		platform.leave_persistent(persistent)
		scope.finish()
	}
	for {
		owner.invoke_custom_element_reactions()
		state := runtime.evaluate_host_temporary_text('__ladybirdTakePendingDOMMutations()')!
		if state.value == 'null' {
			state.finish()
			return
		}
		replay_compact_dom_snapshot(document, state.value, runtime, mut messages)
		state.finish()
	}
}

struct CompactDOMTaskCommit {
	navigation ?string
}

struct CompactDOMTaskOutput {
	logs     []string
	navigate string
}

// Observe task output after reactions settle: a reentrant navigation supersedes
// the earlier request, and its logs must be collected before the realm retires.
fn apply_compact_dom_task(document &dom.Document, encoded string, runtime &browserjs.Runtime,
	mut messages []string) !CompactDOMTaskCommit {
	// Diagnostics and navigation outlive the caller's frame scratch, just as
	// values installed by native query replay do.
	mut storage := document.native_storage()
	mut scope := if storage != unsafe { nil } {
		storage.enter_nested()
	} else {
		platform.RetainedArenaScope{}
	}
	persistent := platform.enter_persistent_if(storage == unsafe { nil } && platform.transient_arena_entered())
	defer {
		platform.leave_persistent(persistent)
		scope.finish()
	}
	apply_javascript_runtime_state(document, encoded, runtime, mut messages)
	state := runtime.evaluate_host_temporary_text('__ladybirdTakeTaskOutput()')!
	defer { state.finish() }
	output := compact_decode_query[CompactDOMTaskOutput](state.value)!
	for entry in output.logs { messages << entry.clone() }
	return CompactDOMTaskCommit{
		navigation: if output.navigate != '' { ?string(output.navigate.clone()) } else { none }
	}
}

// The task owner consumes output once. Capturing a batch never clears edits
// produced by native callbacks while that batch is being replayed.
fn commit_compact_dom_task(document &dom.Document, runtime &browserjs.Runtime,
	mut messages []string) !CompactDOMTaskCommit {
	state := runtime.evaluate_host_temporary_text('__ladybirdFinalize()')!
	defer { state.finish() }
	return apply_compact_dom_task(document, state.value, runtime, mut messages)
}
