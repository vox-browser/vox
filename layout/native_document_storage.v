module layout

// Capture the layout handle before navigation deactivates the old Document.
// Consumers retain their scenes/geometry; closing the pools releases spare
// arenas immediately and makes the final consumer release the live arenas.
pub fn retire_native_document_layout(handle voidptr) {
	if handle == unsafe { nil } { return }
	mut result := unsafe { &DocumentLayoutResult(handle) }
	// An untracked host can still hold copied paint payloads. Match the
	// conservative borrowing policy used by scene and tree-slot retirement.
	if result.document != unsafe { nil } && result.document.paint_borrowed_by_host { return }
	mut scene_pool := result.scene_pool
	if scene_pool != unsafe { nil } {
		scene_pool.retired = true
		scene_pool.document = unsafe { nil }
		for mut scene in scene_pool.free { scene.arena.release() }
		scene_pool.free.clear()
	}
	mut tree_pool := result.paint_tree_pool
	if tree_pool != unsafe { nil } {
		tree_pool.retired = true
		tree_pool.document = unsafe { nil }
		for mut tree in tree_pool.free { tree.arena.release() }
		tree_pool.free.clear()
	}
	result.retire_display_list_scene()
	result.retire_paint_tree_storage()
}
