module layout

import dom
import painting

// A DOM DisplayList identifies one publication, never the layout result that
// happened to produce it. The scene owns the command storage and retains its
// paint-tree and document payloads. Consumers must retain that scene before
// keeping a list across invalidation, and release it when replay is finished.
@[heap]
struct DisplayListRecording {
	commands            []PaintCommand
	generation          u64
	scene               &DisplayListScene = unsafe { nil }
	visual_context_tree painting.AccumulatedVisualContextTree
	// Used only by current-list cache maintenance, never by replay or dump.
	document &dom.Document = unsafe { nil }
}

fn display_list_recording(display_list &dom.DisplayList) ?&DisplayListRecording {
	if display_list == unsafe { nil } || display_list.concrete_handle == unsafe { nil } {
		return none
	}
	return unsafe { &DisplayListRecording(display_list.concrete_handle) }
}

fn current_display_list_layout_result(display_list &dom.DisplayList) ?&DocumentLayoutResult {
	recording := display_list_recording(display_list)?
	if recording.document == unsafe { nil } { return none }
	result := document_layout_result(recording.document)?
	if voidptr(result.display_list) != voidptr(display_list) { return none }
	return result
}

// Compositor samples mutate the boxed transform/effect values in place. A
// cloned node vector alone would still share those sum-type payloads. The other
// variants are immutable and are replaced with their containing tree/node.
fn snapshot_display_list_visual_context_tree(tree &painting.AccumulatedVisualContextTree) painting.AccumulatedVisualContextTree {
	mut nodes := tree.nodes.clone()
	for index, node in nodes {
		match node.data {
			painting.TransformVisualData {
				nodes[index] = painting.AccumulatedVisualContextNode{
					...node
					data: painting.TransformVisualData{ ...node.data }
				}
			}
			painting.EffectsVisualData {
				nodes[index] = painting.AccumulatedVisualContextNode{
					...node
					data: painting.EffectsVisualData{ ...node.data }
				}
			}
			else {}
		}
	}
	return painting.AccumulatedVisualContextTree{ nodes: nodes }
}
