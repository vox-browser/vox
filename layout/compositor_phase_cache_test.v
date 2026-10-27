module layout

import html

fn compositor_phase_bucket_with_color(result &DocumentLayoutResult, color string) int {
	for index, bucket in result.paint_phase_commands {
		if bucket.any(it.color == color) { return index }
	}
	panic('missing phase color ${color}')
}

fn compositor_command_snapshot(commands []PaintCommand) []string {
	return commands.map('${it.kind}:${it.text}:${it.opacity}:${it.group_opacity}:${it.transform}:${it.svg().path_data}:${it.points}:${it.clip_x}:${it.clip_y}:${it.clip_width}:${it.clip_height}')
}

fn test_compositor_frames_retain_unrelated_border_paths_and_match_full_recordings() {
	mut document :=
		html.parse_document('<!doctype html><style>html,body{margin:0}@keyframes turn{from{transform:rotate(0deg)}to{transform:rotate(180deg)}}@keyframes slide{from{transform:translateX(0)}to{transform:translateX(50px)}}#target{display:block;width:40px;height:20px;opacity:.5;animation:turn 1s linear infinite alternate}#skeleton::before{content:"";display:block;width:20px;height:20px;background:blue;animation:slide 1s linear infinite alternate}#unrelated{width:80px;height:30px;border:3px solid rgb(71 72 73);border-radius:7px}</style><svg id="target" viewBox="0 0 40 20"><path d="M0 0H40V20H0Z" fill="green"/></svg><div id="skeleton"></div><div id="unrelated">retained text</div>')
	defer { document.finalize() }
	_ = layout_document_typed_in_viewport(document, 320, 200)
	mut result := document_layout_result(document) or { panic('missing layout') }
	initial := record_retained_display_list(mut document) or { panic('missing initial recording') }
	initial_commands := display_list_commands(initial)
	initial_snapshot := compositor_command_snapshot(initial_commands)
	for timestamp in [250, 500, 1000, 1500] {
		bucket := compositor_phase_bucket_with_color(result, 'rgb(71 72 73)')
		phase_storage := result.paint_phase_commands.data
		border_storage := result.paint_phase_commands[bucket].data
		path_storage := result.paint_phase_commands[bucket][0].svg().path_data.data
		cached_count := result.paint_phase_command_count
		document.update_animations_and_send_events(timestamp)
		document.update_layout(.html_event_loop_rendering_update)
		local := record_retained_display_list(mut document) or { panic('missing sampled recording') }
		assert result.paint_phase_commands.data == phase_storage
		assert result.paint_phase_commands[bucket].data == border_storage
		assert result.paint_phase_commands[bucket][0].svg().path_data.data == path_storage
		assert result.paint_phase_command_count == cached_count
		assert compositor_command_snapshot(initial_commands) == initial_snapshot
		local_dump := local.dump()
		local_commands := display_list_commands(local)
		local_snapshot := compositor_command_snapshot(local_commands)
		refresh_document_paint_tree(document, mut result, 320, 200)
		assert (record_retained_display_list(mut document) or { panic('missing full recording') }).dump() == local_dump
		assert compositor_command_snapshot(local_commands) == local_snapshot
	}
}

fn test_fading_context_refreshes_descendant_alpha_but_keeps_other_phase_storage() {
	mut document :=
		html.parse_document('<!doctype html><style>html,body{margin:0}@keyframes fade{from{opacity:.8}to{opacity:.2}}#target{width:80px;height:30px;background:rgb(51 52 53);animation:fade 1s linear infinite alternate}#child{width:20px;height:20px;background:rgb(61 62 63);opacity:.5}#unrelated{width:80px;height:30px;background:rgb(71 72 73)}</style><div id="target"><div id="child"></div></div><div id="unrelated"></div>')
	defer { document.finalize() }
	_ = layout_document_typed_in_viewport(document, 320, 200)
	mut result := document_layout_result(document) or { panic('missing layout') }
	initial := record_retained_display_list(mut document) or { panic('missing initial recording') }
	initial_commands := display_list_commands(initial)
	initial_snapshot := compositor_command_snapshot(initial_commands)
	for timestamp in [250, 1000, 2000] {
		bucket := compositor_phase_bucket_with_color(result, 'rgb(71 72 73)')
		unrelated_storage := result.paint_phase_commands[bucket].data
		phase_storage := result.paint_phase_commands.data
		document.update_animations_and_send_events(timestamp)
		document.update_layout(.html_event_loop_rendering_update)
		local := record_retained_display_list(mut document) or { panic('missing fading recording') }
		assert result.paint_phase_commands.data == phase_storage
		assert result.paint_phase_commands[bucket].data == unrelated_storage
		commands := display_list_commands(local)
		parent_commands := commands.filter(it.color == 'rgb(51 52 53)')
		child_commands := commands.filter(it.color == 'rgb(61 62 63)')
		assert parent_commands.len == 1 && child_commands.len == 1
		assert child_commands[0].opacity == parent_commands[0].opacity * 0.5
		assert parent_commands[0].opacity != 0.8 || timestamp == 2000
		assert compositor_command_snapshot(initial_commands) == initial_snapshot
		local_dump := local.dump()
		local_commands := display_list_commands(local)
		local_snapshot := compositor_command_snapshot(local_commands)
		refresh_document_paint_tree(document, mut result, 320, 200)
		assert (record_retained_display_list(mut document) or { panic('missing full fading recording') }).dump() == local_dump
		assert compositor_command_snapshot(local_commands) == local_snapshot
	}
}

fn test_singular_compositor_frames_recover_retained_phases_and_fixed_background_contexts() {
	mut document :=
		html.parse_document('<!doctype html><style>html,body{margin:0}@keyframes shrink{from{transform:scaleX(1)}to{transform:scaleX(0)}}#target{width:80px;height:30px;transform-origin:0 0;animation:shrink 1s linear infinite alternate}#fixed{width:20px;height:20px;background:linear-gradient(red,blue) fixed}#unrelated{width:80px;height:30px;background:rgb(71 72 73)}</style><div id="target"><div id="fixed"></div></div><div id="unrelated"></div>')
	defer { document.finalize() }
	_ = layout_document_typed_in_viewport(document, 320, 200)
	mut result := document_layout_result(document) or { panic('missing layout') }
	initial := record_retained_display_list(mut document) or { panic('missing initial recording') }
	initial_commands := display_list_commands(initial)
	initial_snapshot := compositor_command_snapshot(initial_commands)
	target := document.get_element_by_id('target') or { panic('missing target') }
	for timestamp in [500, 1000, 2000] {
		bucket := compositor_phase_bucket_with_color(result, 'rgb(71 72 73)')
		unrelated_storage := result.paint_phase_commands[bucket].data
		phase_storage := result.paint_phase_commands.data
		document.update_animations_and_send_events(timestamp)
		document.update_layout(.html_event_loop_rendering_update)
		local := record_retained_display_list(mut document) or { panic('missing transformed recording') }
		assert result.paint_phase_commands.data == phase_storage
		assert result.paint_phase_commands[bucket].data == unrelated_storage
		assert display_list_commands(local).any(it.gradient != none) == (timestamp != 1000)
		if timestamp == 1000 {
			assert (document.element_from_point(1, 1) or { panic('missing background hit') }) != target
		} else {
			assert target.get_bounding_client_rect().width > 0
		}
		assert compositor_command_snapshot(initial_commands) == initial_snapshot
		local_dump := local.dump()
		local_commands := display_list_commands(local)
		local_snapshot := compositor_command_snapshot(local_commands)
		refresh_document_paint_tree(document, mut result, 320, 200)
		assert (record_retained_display_list(mut document) or { panic('missing full transformed recording') }).dump() == local_dump
		assert compositor_command_snapshot(local_commands) == local_snapshot
	}
}
