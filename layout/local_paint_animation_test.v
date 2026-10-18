module layout

import html

// Color animations refresh their boxes in the retained paint tree, and only
// animated values that descendants can observe revisit them. Every frame must
// still match a recording made from a freshly built paint tree.
fn local_paint_animation_frames_match_fresh_recordings(markup string) {
	mut document := html.parse_document(markup)
	defer { document.finalize() }
	_ = layout_document_typed_in_viewport(document, 320, 200)
	_ = document.record_display_list() or { panic('missing paint') }
	for frame in 0 .. 10 {
		document.update_animations_and_send_events(f64(frame) * 41.0)
		document.update_layout(.html_event_loop_rendering_update)
		incremental := record_retained_display_list(mut document) or { panic('missing frame paint') }
		incremental_dump := incremental.dump()
		mut result := document_layout_result(document) or { panic('missing layout result') }
		result.paint_tree_needs_style_update = true
		result.paint_style_update_requires_full_refresh = true
		result.display_list = unsafe { nil }
		result.needs_repaint = true
		document.invalidate_display_list()
		fresh := record_retained_display_list(mut document) or { panic('missing fresh paint') }
		assert fresh.dump() == incremental_dump, 'frame ${frame}'
	}
}

fn test_background_color_samples_refresh_only_their_boxes() {
	local_paint_animation_frames_match_fresh_recordings('<!doctype html><style>html,body{margin:0}
@keyframes tint{from{background-color:red}to{background-color:blue}}
div{width:80px;height:20px;animation:tint 1s linear infinite}
</style><div>text <b>bold</b></div><div><span>child</span></div>')
}

fn test_color_samples_reach_descendants() {
	local_paint_animation_frames_match_fresh_recordings('<!doctype html><style>html,body{margin:0}
@keyframes ink{from{color:red}to{color:blue}}
div{width:80px;height:20px;animation:ink 1s linear infinite;border:1px solid currentColor}
</style><div>text <b>bold</b><span style="text-decoration:underline">line</span></div>')
}

fn test_non_inherited_samples_reach_children_that_inherit_them() {
	local_paint_animation_frames_match_fresh_recordings('<!doctype html><style>html,body{margin:0}
@keyframes tint{from{background-color:red}to{background-color:blue}}
#parent{width:80px;height:40px;animation:tint 1s linear infinite}
#child{width:40px;height:20px;background-color:inherit}
</style><div id="parent"><div id="child">x</div></div>')
}
