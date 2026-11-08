module layout

import css
import dom
import html

fn compositor_geometry_retiring(document &dom.Document) int {
	for field in css.animation_sample_stats(document).split(' ') {
		if field.starts_with('samples_retiring=') { return field.all_after('=').int() }
	}
	return 0
}

fn compositor_geometry_paint_oracle(mut document dom.Document) {
	local := record_retained_display_list(mut document) or { panic('missing local paint') }
	before := local.dump()
	mut result := document_layout_result(document) or { panic('missing layout') }
	refresh_document_paint_tree(document, mut result, 320, 200)
	full := record_retained_display_list(mut document) or { panic('missing full paint') }
	assert full.dump() == before
	assert local.dump() == before
}

fn test_compositor_geometry_survives_repeated_sample_arena_rotation_with_a_live_scene() {
	mut document := html.parse_document('<!doctype html><style>html,body{margin:0}@keyframes slide{from{transform:translateX(0)}to{transform:translateX(100px)}}#target{width:73px;height:29px;background:linear-gradient(red,blue);filter:blur(1px);display:grid;grid-template-columns:20px 1fr;animation:slide 1s linear infinite alternate}#target::before{content:"";width:10px;height:10px;background:green;animation:slide 1s linear infinite alternate}</style><div id="target">retained</div>')
	defer { document.finalize() }
	_ = layout_document_typed_in_viewport(document, 320, 200)
	document.update_animations_and_send_events(17)
	document.update_layout(.html_event_loop_rendering_update)
	old := record_retained_display_list(mut document) or { panic('missing initial paint') }
	lease := retain_display_list_scene(old)
	defer { release_display_list_scene(lease) }
	old_dump := old.dump()
	old_commands := display_list_commands(old).map('${it.kind}:${it.text}:${it.transform}:${it.color}')
	mut frames := 0
	for frame in 2 .. 1002 {
		document.update_animations_and_send_events(f64(frame) * 17)
		document.update_layout(.html_event_loop_rendering_update)
		_ = record_retained_display_list(mut document) or { panic('missing frame') }
		assert old.dump() == old_dump
		assert display_list_commands(old).map('${it.kind}:${it.text}:${it.transform}:${it.color}') == old_commands
		frames++
		if frame % 40 == 0 { compositor_geometry_paint_oracle(mut document) }
		$if prealloc {
			if compositor_geometry_retiring(document) >= 2 { break }
		} $else {
			if frames >= 40 { break }
		}
	}
	$if prealloc {
		assert compositor_geometry_retiring(document) >= 2
	}
	compositor_geometry_paint_oracle(mut document)
	assert old.dump() == old_dump
}

fn test_mixed_geometry_animation_and_cancellation_restore_raw_size_and_transform() {
	mut document := html.parse_document('<!doctype html><style>html,body{margin:0}@keyframes slide{from{width:20px;transform:translateX(0)}to{width:100px;transform:translateX(100px)}}#target{width:73px;height:29px;transform:translateX(3px);animation:slide 1s linear forwards}#child{width:100%;height:20px;background:green}</style><div id="target"><div id="child"></div></div>')
	defer { document.finalize() }
	_ = layout_document_typed_in_viewport(document, 320, 200)
	target := document.get_element_by_id('target') or { panic('missing target') }
	child := document.get_element_by_id('child') or { panic('missing child') }
	for timestamp in [250, 750] {
		document.update_animations_and_send_events(timestamp)
		document.update_layout(.html_event_loop_rendering_update)
		assert target.get_bounding_client_rect().width == 20 + f64(timestamp) * 0.08
		assert child.get_bounding_client_rect().width == target.get_bounding_client_rect().width
		assert child.get_bounding_client_rect().x == f64(timestamp) * 0.1
		compositor_geometry_paint_oracle(mut document)
	}
	computer := css.css_style_computer_for(document)
	mut animation := computer.css_animation_for(dom.AbstractElement.new(target, none), 'slide') or { panic('missing animation') }
	animation.cancel()
	document.set_needs_animated_style_update()
	document.update_layout(.html_event_loop_rendering_update)
	assert target.get_bounding_client_rect().width == 73
	assert child.get_bounding_client_rect().x == 3
	assert (document.element_from_point(5, 10) or { panic('missing raw hit') }) == child
	compositor_geometry_paint_oracle(mut document)
}
