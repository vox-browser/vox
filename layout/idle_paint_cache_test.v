module layout

import dom
import html

#include "idle_paint_cache_test.h"

$if gcboehm ? {
	fn C.vox_idle_paint_watch(index u32, owner voidptr)
	fn C.vox_idle_paint_collect(depth u32)
	fn C.vox_idle_paint_run_worker(work fn ())
	fn C.vox_idle_paint_alive() u32
}

__global idle_paint_lifetime_list &dom.DisplayList

fn idle_paint_snapshot(commands []PaintCommand) []string {
	return commands.map('${it.kind}:${it.text}:${it.color}:${it.x}:${it.y}:${it.width}:${it.height}:${it.opacity}:${it.group_opacity}:${it.transform}:${it.svg().path_data}:${it.clip_x}:${it.clip_y}:${it.clip_width}:${it.clip_height}:${it.visual_layer()}')
}

fn idle_paint_assert_trimmed(result &DocumentLayoutResult) {
	assert result.record_scratch.recycled_commands.cap == 0
	assert result.record_scratch.memo_slots.cap == 0
	assert result.record_scratch.memo_contexts.cap == 0
	assert result.record_scratch.plan.cap == 0
	assert result.paint_phase_commands.cap == 0
	assert result.paint_phase_entry_valid.cap == 0
	assert result.paint_phase_command_count == 0
	assert !result.paint_phase_cache_valid
}

fn test_idle_trim_preserves_published_commands_and_hit_testing_without_rerecording() {
	mut document := html.parse_document('<!doctype html><style>html,body{margin:0}#target{width:100px;height:40px;background:green}</style><div id="target">kept</div>')
	defer { document.finalize() }
	_ = layout_document_typed_in_viewport(document, 320, 200)
	list := document.record_display_list() or { panic('missing paint') }
	result := document_layout_result(document) or { panic('missing layout') }
	target := document.get_element_by_id('target') or { panic('missing target') }
	assert (document.element_from_point(10, 10) or { panic('missing hit') }) == target
	commands := display_list_commands(list)
	snapshot := idle_paint_snapshot(commands)
	paint_order := result.paint_order.data
	paint_steps := result.paint_steps.data
	hit_steps := result.hit_test_steps.data
	hit_order := result.hit_test_order.data
	contexts := result.visual_context_tree.nodes.data
	assert result.paint_phase_cache_valid
	assert result.record_scratch.plan.len > 0
	release_unused_display_list_caches(list)
	idle_paint_assert_trimmed(result)
	assert result.display_list == list
	assert result.display_list_commands.data == commands.data
	assert idle_paint_snapshot(commands) == snapshot
	assert result.paint_order.data == paint_order
	assert result.paint_steps.data == paint_steps
	assert result.hit_test_steps.data == hit_steps
	assert result.hit_test_order.data == hit_order
	assert result.visual_context_tree.nodes.data == contexts
	assert result.hit_test_display_list_is_valid
	assert result.stacking_context_tree_is_valid
	assert !result.needs_repaint
	assert (document.element_from_point(10, 10) or { panic('lost hit') }) == target
	assert (document.record_display_list() or { panic('lost cached list') }) == list
	assert display_list_commands(list).data == commands.data
	release_unused_display_list_caches(list)
	idle_paint_assert_trimmed(result)
}

fn test_idle_trim_ignores_stale_lists_and_pending_recordings() {
	mut document := html.parse_document('<!doctype html><p>two recordings</p>')
	defer { document.finalize() }
	_ = layout_document_typed_in_viewport(document, 320, 200)
	first := document.record_display_list() or { panic('missing first paint') }
	document.set_needs_repaint_with_invalidation(.paint_commands)
	second := document.record_display_list() or { panic('missing second paint') }
	result := document_layout_result(document) or { panic('missing layout') }
	phase_storage := result.paint_phase_commands.data
	release_unused_display_list_caches(first)
	assert result.paint_phase_cache_valid
	assert result.paint_phase_commands.data == phase_storage
	document.set_needs_repaint_with_invalidation(.paint_commands)
	release_unused_display_list_caches(second)
	assert result.needs_repaint
	assert result.paint_phase_commands.data == phase_storage
	release_unused_display_list_caches(unsafe { nil })
	release_unused_display_list_caches(&dom.DisplayList{})
}

fn test_idle_trim_rebuilds_hover_style_and_scroll_while_preserving_old_vectors() {
	mut document := html.parse_document('<!doctype html><style>html,body{margin:0}#target{width:100px;height:40px;background:green}#target:hover{background:blue}.space{height:200px}</style><div id="target">kept</div><div class="space"></div>')
	defer { document.finalize() }
	_ = layout_document_typed_in_viewport(document, 320, 120)
	initial := document.record_display_list() or { panic('missing initial paint') }
	old_commands := display_list_commands(initial)
	old_snapshot := idle_paint_snapshot(old_commands)
	target := document.get_element_by_id('target') or { panic('missing target') }
	release_unused_display_list_caches(initial)
	document.set_hovered_node(target.as_node())
	document.update_layout(.event_handler_handle_mouse_move)
	hovered := document.record_display_list() or { panic('missing hovered paint') }
	assert display_list_commands(hovered).any(it.color == 'rgb(0 0 255)')
	mut result := document_layout_result(document) or { panic('missing layout') }
	assert result.paint_phase_cache_valid
	assert result.paint_phase_entry_valid.all(it)
	assert idle_paint_snapshot(old_commands) == old_snapshot
	hover_snapshot := idle_paint_snapshot(display_list_commands(hovered))
	release_unused_display_list_caches(hovered)
	document.set_needs_repaint_with_invalidation(.paint_commands)
	assert idle_paint_snapshot(display_list_commands(document.record_display_list() or { panic('missing rebuilt paint') })) == hover_snapshot
	release_unused_display_list_caches(result.display_list)
	viewport := document.viewport_rect()
	document.set_viewport_rect(dom.Rect{viewport.x, 25, viewport.width, viewport.height})
	scrolled := document.record_display_list() or { panic('missing scrolled paint') }
	assert result.paint_phase_cache_valid
	assert idle_paint_snapshot(display_list_commands(scrolled)) != hover_snapshot
	assert idle_paint_snapshot(old_commands) == old_snapshot
	local := idle_paint_snapshot(display_list_commands(scrolled))
	refresh_document_paint_tree(document, mut result, 320, 120)
	assert idle_paint_snapshot(display_list_commands(document.record_display_list() or { panic('missing full paint') })) == local
}

fn test_idle_trim_rebuilds_svg_mask_clip_and_transparency_commands() {
	mut document := html.parse_document('<!doctype html><style>html,body{margin:0}svg{display:block;opacity:.5;filter:saturate(50%)}</style><svg width="120" height="80"><defs><clipPath id="clip"><rect width="70" height="60"/></clipPath><mask id="fade" mask-type="alpha"><rect width="120" height="80" fill="white"/></mask></defs><g mask="url(#fade)" clip-path="url(#clip)"><rect width="120" height="80" fill="red"/></g></svg>')
	defer { document.finalize() }
	_ = layout_document_typed_in_viewport(document, 320, 200)
	list := document.record_display_list() or { panic('missing SVG paint') }
	commands := display_list_commands(list)
	assert commands.any(it.kind == 'begin_svg_mask_layer')
	assert commands.any(it.kind == 'begin_css_filter_layer')
	assert commands.any(it.has_clip)
	snapshot := idle_paint_snapshot(commands)
	release_unused_display_list_caches(list)
	document.set_needs_repaint_with_invalidation(.paint_commands)
	rebuilt := document.record_display_list() or { panic('missing rebuilt SVG paint') }
	assert idle_paint_snapshot(display_list_commands(rebuilt)) == snapshot
	assert idle_paint_snapshot(commands) == snapshot
}

fn test_idle_trim_preserves_compositor_animation_and_caret_invalidation() {
	mut document := html.parse_document('<!doctype html><style>html,body,p{margin:0}@keyframes slide{from{transform:translateX(0)}to{transform:translateX(100px)}}#target{width:30px;height:30px;background:rgb(71 72 73);animation:slide 1s linear forwards}p{caret-color:rgb(13 14 15)}</style><div id="target"></div><p id="editor" contenteditable>hello</p>')
	defer { document.finalize() }
	host := &dom.Navigable{active_document_: document}
	mut navigable := html.NavigableModel.create(host, none) or { panic(err) }
	navigable.set_focused(true)
	document.set_cached_navigable(host)
	_ = layout_document_typed_in_viewport(document, 320, 200)
	editor := document.get_element_by_id('editor') or { panic('missing editor') }
	text := editor.as_node().first_child() or { panic('missing text') }
	document.set_focused_area(editor.as_node())
	mut selection := document.get_selection() or { panic('missing selection') }
	selection.collapse(text, 1) or { panic(err) }
	first := document.record_display_list() or { panic('missing first paint') }
	old_commands := display_list_commands(first)
	old_snapshot := idle_paint_snapshot(old_commands)
	first_caret := old_commands.filter(it.kind == 'fill_rect' && it.color == 'rgb(13 14 15)')
	assert first_caret.len == 1
	release_unused_display_list_caches(first)
	selection.collapse(text, 4) or { panic(err) }
	second := document.record_display_list() or { panic('missing moved caret') }
	second_caret := display_list_commands(second).filter(it.kind == 'fill_rect' && it.color == 'rgb(13 14 15)')
	assert second_caret.len == 1
	assert second_caret[0].x > first_caret[0].x
	release_unused_display_list_caches(second)
	document.update_animations_and_send_events(500)
	document.update_layout(.html_event_loop_rendering_update)
	sampled := document.record_display_list() or { panic('missing animation paint') }
	moved := display_list_commands(sampled).filter(it.color == 'rgb(71 72 73)')
	assert moved.len == 1
	assert normalized_affine(moved[0].transform)[4] == 50
	assert idle_paint_snapshot(old_commands) == old_snapshot
	mut result := document_layout_result(document) or { panic('missing layout') }
	local := idle_paint_snapshot(display_list_commands(sampled))
	refresh_document_paint_tree(document, mut result, 320, 200)
	assert idle_paint_snapshot(display_list_commands(document.record_display_list() or { panic('missing full paint') })) == local
}

fn idle_paint_lifetime_prepare() {
	mut document := html.parse_document('<!doctype html><style>html,body{margin:0}p{transform:translateX(3px);background:green}</style><p>owned scratch and published output</p>')
	_ = layout_document_typed_in_viewport(document, 320, 200)
	first := document.record_display_list() or { panic('missing first paint') }
	previous := display_list_commands(first)
	document.set_needs_repaint_with_invalidation(.paint_commands)
	current := document.record_display_list() or { panic('missing current paint') }
	recycle_display_list_commands(current, previous)
	idle_paint_lifetime_list = current
	result := document_layout_result(document) or { panic('missing layout') }
	$if gcboehm ? {
		C.vox_idle_paint_watch(0, result.record_scratch.recycled_commands.data)
		C.vox_idle_paint_watch(1, result.record_scratch.memo_slots.data)
		C.vox_idle_paint_watch(2, result.record_scratch.memo_contexts.data)
		C.vox_idle_paint_watch(3, result.record_scratch.plan.data)
		C.vox_idle_paint_watch(4, result.paint_phase_commands.data)
		C.vox_idle_paint_watch(5, result.paint_phase_entry_valid.data)
		for bucket in result.paint_phase_commands {
			if bucket.len > 0 { C.vox_idle_paint_watch(6, bucket.data); break }
		}
		C.vox_idle_paint_watch(7, result.display_list_commands.data)
	}
}

fn idle_paint_lifetime_trim() {
	release_unused_display_list_caches(idle_paint_lifetime_list)
}

fn test_idle_trim_releases_unpublished_backing_storage_after_worker_unwind() {
	$if gcboehm ? {
		C.vox_idle_paint_run_worker(idle_paint_lifetime_prepare)
		C.vox_idle_paint_collect(8)
		assert C.vox_idle_paint_alive() == 255
		C.vox_idle_paint_run_worker(idle_paint_lifetime_trim)
		C.vox_idle_paint_collect(8)
		C.vox_idle_paint_collect(8)
		assert C.vox_idle_paint_alive() == 128
	} $else {
		idle_paint_lifetime_prepare()
		idle_paint_lifetime_trim()
	}
	assert display_list_commands(idle_paint_lifetime_list).any(it.text == 'owned scratch and published output')
	idle_paint_lifetime_list = unsafe { nil }
}
