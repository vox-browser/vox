module layout

import dom
import html
import platform

#include "@DIR/../platform/arena_page_retirement_test.h"
fn C.vox_arena_test_resident_bytes(start voidptr, bytes uint) uint
fn C.vox_arena_test_unused_resident_bytes(start voidptr, bytes uint) uint

fn test_idle_paint_page_trim_keeps_live_scenes_and_trees_and_refills_spares() {
	$if !prealloc { return }
	mut document := dom.Document.create(dom.url_about_blank())
	document.enable_native_storage()
	enable_native_paint_tree_storage(document)
	mut result := &DocumentLayoutResult{document:document}
	mut pool := result.scene_pool_()
	mut live_scene := pool.acquire()
	result.scene = live_scene
	warm := live_scene.arena.enter()
	warm_bytes := []u8{len:200 * 1024, init:61}
	assert warm_bytes[0] == 61
	live_scene.arena.leave(warm)
	live_scene.arena.reset()
	entry := live_scene.arena.enter()
	live_bytes := []u8{len:128 * 1024, init:23}
	live_scene.arena.leave(entry)
	mut spare_scene := pool.acquire()
	spare_entry := spare_scene.arena.enter()
	spare_bytes := []u8{len:128 * 1024, init:71}
	spare_scene.arena.leave(spare_entry)
	spare_scene.release()
	mut live_tree := result.acquire_paint_tree_storage(document)
	result.paint_tree_storage = live_tree
	warm_tree := live_tree.arena.enter()
	warm_tree_bytes := []u8{len:200 * 1024, init:67}
	assert warm_tree_bytes[0] == 67
	live_tree.arena.leave(warm_tree)
	live_tree.arena.reset()
	tree_entry := live_tree.arena.enter()
	live_tree_bytes := []u8{len:128 * 1024, init:43}
	live_tree.arena.leave(tree_entry)
	mut spare_tree := result.acquire_paint_tree_storage(document)
	spare_tree_entry := spare_tree.arena.enter()
	spare_tree_bytes := []u8{len:128 * 1024, init:89}
	spare_tree.arena.leave(spare_tree_entry)
	spare_tree.release()
	scene_usage := live_scene.arena.usage()
	tree_usage := live_tree.arena.usage()
	trim_spare_paint_pages(result)
	assert live_scene.arena.usage().used == scene_usage.used
	assert live_scene.arena.usage().capacity == scene_usage.capacity
	assert live_tree.arena.usage().used == tree_usage.used
	assert live_tree.arena.usage().capacity == tree_usage.capacity
	assert C.vox_arena_test_unused_resident_bytes(voidptr(uint(live_bytes.data) + uint(live_bytes.len)), 64 * 1024) == 0
	assert C.vox_arena_test_unused_resident_bytes(voidptr(uint(live_tree_bytes.data) + uint(live_tree_bytes.len)), 64 * 1024) == 0
	assert live_bytes[0] == 23 && live_bytes[live_bytes.len - 1] == 23
	assert live_tree_bytes[0] == 43 && live_tree_bytes[live_tree_bytes.len - 1] == 43
	if !platform.arenas_poisoned() {
		assert C.vox_arena_test_resident_bytes(spare_bytes.data, 128 * 1024) == 0
		assert C.vox_arena_test_resident_bytes(spare_tree_bytes.data, 128 * 1024) == 0
	}
	mut refill := pool.acquire()
	refill_entry := refill.arena.enter()
	replacement := []u8{len:128 * 1024, init:17}
	assert replacement[0] == 17 && replacement[replacement.len - 1] == 17
	refill.arena.leave(refill_entry)
	refill.release()
	retire_native_document_layout(voidptr(result))
	document.finalize()
	document.release_native_storage()
}

fn test_arena_page_trim_preserves_published_commands_cache_and_hit_testing() {
	url := dom.URL{value:'https://idle-trim.test/'}
	mut document := html.create_navigation_document(url, url.origin(), none)!
	document.enable_native_storage()
	mut payload := document.enter_native_storage()
	html.parse_html_from_a_string(document, '<!doctype html><style>html,body{margin:0}div{width:100px;height:40px;background:green}</style><div id="target">kept paint</div>')
	payload.finish()
	enable_native_paint_tree_storage(document)
	_ = layout_document_typed_in_viewport(document, 320, 200)
	list := document.record_display_list()?
	lease := retain_display_list_scene(list)
	commands := display_list_commands(list)
	result := document_layout_result(document)?
	assert result.paint_phase_cache_valid
	trim_unused_layout_pages(list)
	assert result.paint_phase_cache_valid
	assert voidptr(result.display_list) == voidptr(list)
	assert display_list_commands(list).data == commands.data
	assert commands.any(it.text == 'kept paint')
	assert document.element_from_point(5, 5)?.id()? == 'target'
	document.set_needs_repaint_with_invalidation(.paint_commands)
	rebuilt := document.record_display_list()?
	assert display_list_commands(rebuilt).any(it.text == 'kept paint')
	assert commands.any(it.text == 'kept paint')
	release_display_list_scene(lease)
	handle := document.layout_engine_handle()
	document.destroy_a_document_and_its_descendants()
	document.finalize()
	retire_native_document_layout(handle)
	document.release_native_storage()
}
