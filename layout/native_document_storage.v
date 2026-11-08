module layout

// Capture the layout handle before navigation deactivates the old Document.
// Consumers retain their scenes/geometry; closing the pools releases spare
// arenas immediately and makes the final consumer release the live arenas.
pub fn retire_native_document_layout(handle voidptr) {
	if handle == unsafe { nil } { return }
	mut result := unsafe { &DocumentLayoutResult(handle) }
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
	// Phase caches and published scenes are independent consumers of hosted
	// recordings. Retire both publishers; retained parent frames keep only the
	// child scenes their immutable command streams actually reference.
	clear_phase_command_storage(mut result.paint_phase_commands)
	result.paint_phase_cache_valid = false
	result.paint_phase_command_count = 0
	result.retire_display_list_scene()
	result.retire_paint_tree_storage()
}
