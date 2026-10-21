module layout

import dom
import html
import http
import loader

#include "idle_paint_cache_test.h"

$if gcboehm ? {
	fn C.vox_idle_paint_watch(index u32, owner voidptr)
	fn C.vox_idle_paint_collect(depth u32)
	fn C.vox_idle_paint_run_worker(work fn ())
	fn C.vox_idle_paint_alive() u32
}

__global idle_paint_lifetime_list &dom.DisplayList

fn idle_paint_snapshot(commands []PaintCommand) []string {
	mut output := []string{cap: commands.len}
	for command in commands {
		layer := command.visual_layer()
		clip := layer.mask_clip
		mut mask_operations := []string{}
		for operation in clip.mask_operations {
			mask_operations << '${operation.kind}:${operation.opacity}:${operation.image_url}:${operation.image_rect}:${operation.image_position_x}:${operation.image_position_y}:${operation.image_rendering}:${operation.path_data}:${operation.path_even_odd}:${operation.transform}:${operation.fill_color}:${operation.stroke_color}:${operation.fill_linear_gradient}:${operation.stroke_linear_gradient}:${operation.fill_radial_gradient}:${operation.stroke_radial_gradient}:${operation.has_fill}:${operation.has_stroke}:${operation.fill_opacity}:${operation.stroke_opacity}:${operation.stroke_width}:${operation.stroke_linecap}:${operation.stroke_linejoin}:${operation.stroke_miterlimit}:${operation.stroke_first}'
		}
		// Snapshot rendered values rather than recursively formatting image
		// paintables, whose ownership graph reaches the complete DOM.
		output << '${command.kind}:${command.text}:${command.color}:${command.x}:${command.y}:${command.width}:${command.height}:${command.opacity}:${command.group_opacity}:${command.transform}:${command.svg().path_data}:${command.clip_x}:${command.clip_y}:${command.clip_width}:${command.clip_height}:${layer.kind}:${layer.scope_id}:${layer.opacity}:${layer.blend_mode}:${layer.clip_rect}:${layer.filter}:${clip.rect}:${clip.corner_radii}:${clip.is_path}:${clip.is_svg_mask}:${clip.is_svg_content_mask}:${clip.path_data}:${clip.path_even_odd}:${clip.path_components}:${clip.cache_key}:${clip.scope_id}:${clip.mask_luminance}:${clip.transform}:${mask_operations}'
	}
	return output
}

// Evaluate assertions as booleans before entering V's diagnostic formatter.
// Formatting a whole retained DOM/paint graph on failure is prohibitively large.
fn idle_paint_expect(condition bool) { assert condition }

fn idle_paint_assert_trimmed(result &DocumentLayoutResult) {
	idle_paint_expect(result.record_scratch.recycled_commands.cap == 0)
	idle_paint_expect(result.record_scratch.memo_slots.cap == 0)
	idle_paint_expect(result.record_scratch.memo_contexts.cap == 0)
	idle_paint_expect(result.record_scratch.plan.cap == 0)
	idle_paint_expect(result.paint_phase_commands.cap == 0)
	idle_paint_expect(result.paint_phase_entry_valid.cap == 0)
	idle_paint_expect(result.paint_phase_command_count == 0)
	idle_paint_expect(!result.paint_phase_cache_valid)
}

fn test_idle_trim_preserves_published_commands_and_hit_testing_without_rerecording() {
	mut document := html.parse_document('<!doctype html><style>html,body{margin:0}#target{width:100px;height:40px;background:green}</style><div id="target">kept</div>')
	defer { document.finalize() }
	_ = layout_document_typed_in_viewport(document, 320, 200)
	list := document.record_display_list() or { panic('missing paint') }
	result := document_layout_result(document) or { panic('missing layout') }
	target := document.get_element_by_id('target') or { panic('missing target') }
	idle_paint_expect(voidptr(document.element_from_point(10, 10) or { panic('missing hit') }) == voidptr(target))
	commands := display_list_commands(list)
	snapshot := idle_paint_snapshot(commands)
	paint_order := result.paint_order.data
	paint_steps := result.paint_steps.data
	hit_steps := result.hit_test_steps.data
	hit_order := result.hit_test_order.data
	contexts := result.visual_context_tree.nodes.data
	idle_paint_expect(result.paint_phase_cache_valid)
	idle_paint_expect(result.record_scratch.plan.len > 0)
	release_unused_display_list_caches(list)
	idle_paint_assert_trimmed(result)
	idle_paint_expect(voidptr(result.display_list) == voidptr(list))
	idle_paint_expect(result.display_list_commands.data == commands.data)
	idle_paint_expect(idle_paint_snapshot(commands) == snapshot)
	idle_paint_expect(result.paint_order.data == paint_order)
	idle_paint_expect(result.paint_steps.data == paint_steps)
	idle_paint_expect(result.hit_test_steps.data == hit_steps)
	idle_paint_expect(result.hit_test_order.data == hit_order)
	idle_paint_expect(result.visual_context_tree.nodes.data == contexts)
	idle_paint_expect(result.hit_test_display_list_is_valid)
	idle_paint_expect(result.stacking_context_tree_is_valid)
	idle_paint_expect(!result.needs_repaint)
	idle_paint_expect(voidptr(document.element_from_point(10, 10) or { panic('lost hit') }) == voidptr(target))
	idle_paint_expect(voidptr(document.record_display_list() or { panic('lost cached list') }) == voidptr(list))
	idle_paint_expect(display_list_commands(list).data == commands.data)
	release_unused_display_list_caches(list)
	idle_paint_assert_trimmed(result)
}

fn test_idle_trim_ignores_stale_lists_and_pending_recordings() {
	mut document := html.parse_document('<!doctype html><p>two recordings</p>')
	defer { document.finalize() }
	_ = layout_document_typed_in_viewport(document, 320, 200)
	first := document.record_display_list() or { panic('missing first paint') }
	// A native scene must remain leased while this test passes its old list
	// back to the stale-list guard after the next recording replaces it.
	first_lease := retain_display_list_scene(first)
	defer { release_display_list_scene(first_lease) }
	document.set_needs_repaint_with_invalidation(.paint_commands)
	second := document.record_display_list() or { panic('missing second paint') }
	result := document_layout_result(document) or { panic('missing layout') }
	phase_storage := result.paint_phase_commands.data
	release_unused_display_list_caches(first)
	idle_paint_expect(result.paint_phase_cache_valid)
	idle_paint_expect(result.paint_phase_commands.data == phase_storage)
	document.set_needs_repaint_with_invalidation(.paint_commands)
	release_unused_display_list_caches(second)
	idle_paint_expect(result.needs_repaint)
	idle_paint_expect(result.paint_phase_commands.data == phase_storage)
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
	idle_paint_expect(display_list_commands(hovered).any(it.color == 'rgb(0 0 255)'))
	mut result := document_layout_result(document) or { panic('missing layout') }
	idle_paint_expect(result.paint_phase_cache_valid)
	idle_paint_expect(result.paint_phase_entry_valid.all(it))
	idle_paint_expect(idle_paint_snapshot(old_commands) == old_snapshot)
	hover_snapshot := idle_paint_snapshot(display_list_commands(hovered))
	release_unused_display_list_caches(hovered)
	document.set_needs_repaint_with_invalidation(.paint_commands)
	idle_paint_expect(idle_paint_snapshot(display_list_commands(document.record_display_list() or { panic('missing rebuilt paint') })) == hover_snapshot)
	release_unused_display_list_caches(result.display_list)
	viewport := document.viewport_rect()
	document.set_viewport_rect(dom.Rect{viewport.x, 25, viewport.width, viewport.height})
	scrolled := document.record_display_list() or { panic('missing scrolled paint') }
	idle_paint_expect(result.paint_phase_cache_valid)
	idle_paint_expect(idle_paint_snapshot(display_list_commands(scrolled)) != hover_snapshot)
	idle_paint_expect(idle_paint_snapshot(old_commands) == old_snapshot)
	local := idle_paint_snapshot(display_list_commands(scrolled))
	refresh_document_paint_tree(document, mut result, 320, 120)
	idle_paint_expect(idle_paint_snapshot(display_list_commands(document.record_display_list() or { panic('missing full paint') })) == local)
}

fn test_idle_trim_rebuilds_svg_mask_clip_and_transparency_commands() {
	mut document := html.parse_document('<!doctype html><style>html,body{margin:0}svg{display:block;opacity:.5;filter:saturate(50%)}</style><svg width="120" height="80"><defs><clipPath id="clip"><rect width="70" height="60"/></clipPath><mask id="fade" mask-type="alpha"><rect width="120" height="80" fill="white"/></mask></defs><g mask="url(#fade)" clip-path="url(#clip)"><rect width="120" height="80" fill="red"/></g></svg>')
	defer { document.finalize() }
	_ = layout_document_typed_in_viewport(document, 320, 200)
	list := document.record_display_list() or { panic('missing SVG paint') }
	lease := retain_display_list_scene(list)
	defer { release_display_list_scene(lease) }
	commands := display_list_commands(list)
	idle_paint_expect(commands.any(it.kind == 'begin_svg_mask_layer'))
	idle_paint_expect(commands.any(it.kind == 'begin_css_filter_layer'))
	idle_paint_expect(commands.any(it.has_clip))
	snapshot := idle_paint_snapshot(commands)
	release_unused_display_list_caches(list)
	document.set_needs_repaint_with_invalidation(.paint_commands)
	rebuilt := document.record_display_list() or { panic('missing rebuilt SVG paint') }
	idle_paint_expect(idle_paint_snapshot(display_list_commands(rebuilt)) == snapshot)
	idle_paint_expect(idle_paint_snapshot(commands) == snapshot)
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
	idle_paint_expect(first_caret.len == 1)
	release_unused_display_list_caches(first)
	selection.collapse(text, 4) or { panic(err) }
	second := document.record_display_list() or { panic('missing moved caret') }
	second_caret := display_list_commands(second).filter(it.kind == 'fill_rect' && it.color == 'rgb(13 14 15)')
	idle_paint_expect(second_caret.len == 1)
	idle_paint_expect(second_caret[0].x > first_caret[0].x)
	release_unused_display_list_caches(second)
	document.update_animations_and_send_events(500)
	document.update_layout(.html_event_loop_rendering_update)
	sampled := document.record_display_list() or { panic('missing animation paint') }
	moved := display_list_commands(sampled).filter(it.color == 'rgb(71 72 73)')
	idle_paint_expect(moved.len == 1)
	idle_paint_expect(normalized_affine(moved[0].transform)[4] == 50)
	idle_paint_expect(idle_paint_snapshot(old_commands) == old_snapshot)
	mut result := document_layout_result(document) or { panic('missing layout') }
	local := idle_paint_snapshot(display_list_commands(sampled))
	refresh_document_paint_tree(document, mut result, 320, 200)
	idle_paint_expect(idle_paint_snapshot(display_list_commands(document.record_display_list() or { panic('missing full paint') })) == local)
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
		idle_paint_expect(C.vox_idle_paint_alive() == 255)
		C.vox_idle_paint_run_worker(idle_paint_lifetime_trim)
		C.vox_idle_paint_collect(8)
		C.vox_idle_paint_collect(8)
		idle_paint_expect(C.vox_idle_paint_alive() == 128)
	} $else {
		idle_paint_lifetime_prepare()
		idle_paint_lifetime_trim()
	}
	idle_paint_expect(display_list_commands(idle_paint_lifetime_list).any(it.text == 'owned scratch and published output'))
	idle_paint_lifetime_list = unsafe { nil }
}

fn test_idle_trim_discards_relayout_snapshots_and_rebuilds_identical_resized_output() {
	source := '<!doctype html><style>html,body{margin:0}#flow{display:flow-root;width:75%;background:green}p{margin:0}</style><div id="flow"><p>retained lines must remain available for painting and selection after idle cleanup</p></div>'
	mut document := html.parse_document(source)
	defer { document.finalize() }
	_ = layout_document_typed_in_viewport(document, 320, 200)
	first := document.record_display_list() or { panic('missing first paint') }
	result := document_layout_result(document) or { panic('missing layout') }
	idle_paint_expect(result.state.block_layouts_.len + result.state.inline_layouts_.len > 0)
	flow := document.get_element_by_id('flow') or { panic('missing flow') }
	hit := document.element_from_point(5, 5) or { panic('missing flow hit') }
	paragraph := flow.as_node().first_child() or { panic('missing paragraph') }
	paragraph_element := paragraph.as_element() or { panic('paragraph is not an element') }
	idle_paint_expect(voidptr(hit) == voidptr(paragraph_element))
	commands := idle_paint_snapshot(display_list_commands(first))
	root := result.root
	state := result.state
	release_unused_display_list_caches(first)
	idle_paint_expect(result.state.block_layouts_.len == 0)
	idle_paint_expect(result.state.inline_layouts_.len == 0)
	idle_paint_expect(result.state.block_paint_owners_.len == 0)
	idle_paint_expect(voidptr(result.root) == voidptr(root))
	idle_paint_expect(voidptr(result.state) == voidptr(state))
	root.for_each_in_inclusive_subtree(fn (node &Node) dom.TraversalDecision {
		idle_paint_expect(voidptr(node.ordinary_paint_box_) == unsafe { nil })
		idle_paint_expect(voidptr(node.flow_validation_cache_) == unsafe { nil })
		return .@continue
	})
	cached := document.record_display_list() or { panic('missing cached paint') }
	idle_paint_expect(idle_paint_snapshot(display_list_commands(cached)) == commands)
	_ = layout_document_typed_in_viewport(document, 180, 200)
	resized_list := document.record_display_list() or { panic('missing resized paint') }
	resized := idle_paint_snapshot(display_list_commands(resized_list))
	idle_paint_expect(resized != commands)
	mut reference := html.parse_document(source)
	defer { reference.finalize() }
	_ = layout_document_typed_in_viewport(reference, 180, 200)
	reference_list := reference.record_display_list() or { panic('missing reference paint') }
	idle_paint_expect(resized == idle_paint_snapshot(display_list_commands(reference_list)))
	idle_paint_expect(idle_paint_snapshot(display_list_commands(first)) == commands)
}

fn test_idle_trim_reaches_shared_svg_image_document_without_discarding_its_live_list() {
	address := 'https://idle-svg.test/shared.svg'
	mut resources := if loader.is_initialized() { loader.ResourceLoader.the() } else { loader.initialize() }
	resources.register_network_response(address, loader.NetworkResponse{
		data: '<svg xmlns="http://www.w3.org/2000/svg" width="20" height="10"><path d="M0 0H20V10H0Z" fill="green"/></svg>'.bytes()
		headers: [http.Header{name: 'Content-Type', value: 'image/svg+xml'}]
	})
	mut document := html.parse_document('<!doctype html><style>div{width:20px;height:10px;background:url(${address})}</style><div id="one"></div><div></div>')
	defer { document.finalize() }
	root := layout_document_typed_in_viewport(document, 100, 100)
	element := document.get_element_by_id('one') or { panic('missing SVG host') }
	box := root.find_box(i64(element.as_node().unique_id())) or { panic('missing SVG box') }
	mut isolated := box.background_images[0].svg_document or { panic('missing SVG document') }
	_ = run_document_layout(isolated, 20, 10) or { panic('missing SVG layout') }
	image_list := isolated.record_display_list() or { panic('missing SVG paint') }
	image_result := document_layout_result(isolated) or { panic('missing SVG result') }
	idle_paint_expect(image_result.paint_phase_cache_valid)
	image_commands := idle_paint_snapshot(display_list_commands(image_list))
	list := document.record_display_list() or { panic('missing host paint') }
	release_unused_display_list_caches(list)
	idle_paint_assert_trimmed(image_result)
	cached_image_list := isolated.record_display_list() or { panic('missing cached SVG paint') }
	idle_paint_expect(voidptr(cached_image_list) == voidptr(image_list))
	idle_paint_expect(idle_paint_snapshot(display_list_commands(image_list)) == image_commands)
	isolated.set_needs_repaint_with_invalidation(.paint_commands)
	rebuilt_image_list := isolated.record_display_list() or { panic('missing rebuilt SVG paint') }
	idle_paint_expect(idle_paint_snapshot(display_list_commands(rebuilt_image_list)) == image_commands)
}
