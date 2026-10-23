module layout

import dom
import platform

fn test_callback_installation_borrows_stable_paintables_without_snapshot_allocations() {
	node := &dom.LayoutNode{paintables_:[]&dom.Paintable{len:4096, init:&dom.Paintable{}}}
	result := &DocumentLayoutResult{}
	mut bindings := []&dom.Paintable{cap:4096}
	before := platform.thread_arena_usage().used
	install_layout_paintable_repaint_callbacks(node, result, mut bindings)
	$if prealloc { assert platform.thread_arena_usage().used - before < 4096 }
	assert bindings.len == 4096
	for index, paintable in bindings {
		assert voidptr(paintable) == voidptr(node.paintables_[index])
		assert paintable.repaint_callback_target == voidptr(result)
		assert voidptr(paintable.callbacks) == voidptr(layout_paintable_callbacks)
		assert paintable.callbacks.set_needs_repaint_callback != unsafe { nil }
		assert paintable.callbacks.image_contents_changed_callback != unsafe { nil }
	}
	// The public snapshot contract continues to permit independent mutation.
	mut snapshot := node.paintables()
	snapshot[0] = &dom.Paintable{}
	assert voidptr(snapshot[0]) != voidptr(node.paintables_[0])
	assert node.paintables_[0].repaint_callback_target == voidptr(result)
}
