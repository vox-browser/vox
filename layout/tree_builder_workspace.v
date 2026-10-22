module layout

import css
import platform

// Tree-order history is consumed only by this build. The counter snapshots
// installed on DOM elements are created before entering this workspace.
fn new_tree_builder_state() TreeBuilderState {
	$if prealloc {
		mut workspace := platform.new_arena('layout tree builder history')
		entry := workspace.enter()
		state := TreeBuilderState{ workspace: workspace }
		workspace.leave(entry)
		return state
	}
	return TreeBuilderState{}
}

fn (mut state TreeBuilderState) remember_counters(key i64, counters ?css.CountersSet, parent_key i64) {
	mut workspace := state.workspace
	entry := if workspace != unsafe { nil } { workspace.enter() } else { platform.ArenaEntry{} }
	defer { if workspace != unsafe { nil } { workspace.leave(entry) } }
	if snapshot := counters {
		state.counter_sets[key] = snapshot
	} else {
		state.counter_sets.delete(key)
	}
	if parent_key >= 0 { state.last_child_by_parent[parent_key] = key }
}

fn (mut state TreeBuilderState) finish() {
	if state.workspace != unsafe { nil } {
		state.workspace.release()
		state.workspace = unsafe { nil }
	}
}
