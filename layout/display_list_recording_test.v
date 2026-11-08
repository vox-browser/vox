module layout

import dom
import html
import painting

// Compare replay values without formatting payload owners that reach the DOM.
fn recording_snapshot(commands []PaintCommand) []string {
	return commands.map('${it.kind}:${it.text}:${it.color}:${it.x}:${it.y}:${it.width}:${it.height}:${it.transform}:${it.opacity}:${it.group_opacity}:${it.visual_layer().opacity}')
}

fn test_retained_recording_keeps_commands_count_and_scene_across_viewport_recordings() {
	mut document := html.parse_document('<!doctype html><style>html,body{margin:0}div{height:100px;background:green}</style><div>first</div><div>middle</div><div>last</div>')
	defer { document.finalize() }
	_ = layout_document_typed_in_viewport(document, 320, 100)
	first := document.record_display_list()?
	first_scene := retain_display_list_scene(first)
	defer { release_display_list_scene(first_scene) }
	first_commands := display_list_commands(first)
	first_snapshot := recording_snapshot(first_commands)
	first_dump := first.dump()
	first_count := first.command_count()
	first_generation := first.generation()
	assert first_generation > 0
	result := document_layout_result(document)?
	cached := document.record_display_list()?
	assert voidptr(cached) == voidptr(first)
	assert cached.generation() == first_generation
	assert first_count == first_commands.len

	viewport := document.record_viewport_display_list()?
	viewport_scene := retain_display_list_scene(viewport)
	defer { release_display_list_scene(viewport_scene) }
	assert voidptr(document_layout_result(document)?) == voidptr(result)
	assert voidptr(viewport) != voidptr(first)
	assert viewport.generation() > first_generation
	assert viewport.command_count() < first_count
	assert display_list_commands(viewport).len == viewport.command_count()
	assert display_list_commands(first).len == first_count
	assert display_list_commands(first).data == first_commands.data
	assert recording_snapshot(display_list_commands(first)) == first_snapshot
	assert first.dump() == first_dump

	// Acquiring another reader later must retain the original recording.
	another_reader := retain_display_list_scene(first)
	defer { release_display_list_scene(another_reader) }
	assert another_reader == first_scene
	assert another_reader != viewport_scene

	document.set_viewport_rect(dom.Rect{0, 200, 320, 100})
	scrolled := document.record_viewport_display_list()?
	assert scrolled.generation() > viewport.generation()
	assert first.generation() == first_generation
	assert display_list_commands(scrolled).any(it.text == 'last')
	assert !display_list_commands(scrolled).any(it.text == 'first')
	assert display_list_commands(first).len == first_count
	assert recording_snapshot(display_list_commands(first)) == first_snapshot
	assert first.dump() == first_dump
}

fn test_recording_dump_snapshots_mutable_compositor_context_values() {
	mut document := html.parse_document('<!doctype html><style>html,body{margin:0}div{opacity:.5;transform:translateX(3px);width:100px;height:40px;background:green}</style><div>stable diagnostics</div>')
	defer { document.finalize() }
	_ = layout_document_typed_in_viewport(document, 320, 200)
	first := document.record_display_list()?
	first_scene := retain_display_list_scene(first)
	defer { release_display_list_scene(first_scene) }
	first_snapshot := recording_snapshot(display_list_commands(first))
	first_dump := first.dump()
	mut result := document_layout_result(document)?
	mut effect_index := -1
	for index, node in result.visual_context_tree.nodes {
		if node.data is painting.EffectsVisualData {
			effect_index = index
			break
		}
	}
	assert effect_index > 0
	assert result.visual_context_tree.set_compositor_opacity(effect_index, 0.25)
	// The compositor mutates the variant payload itself, so cloning only the
	// tree's node vector is insufficient to preserve the published dump.
	assert first.dump() == first_dump
	result.needs_repaint = true
	document.invalidate_display_list()
	second := document.record_display_list()?
	assert voidptr(document_layout_result(document)?) == voidptr(result)
	assert second.dump() != first_dump
	assert recording_snapshot(display_list_commands(second)) != first_snapshot
	assert recording_snapshot(display_list_commands(first)) == first_snapshot
	assert first.dump() == first_dump
}

fn test_recycling_a_shell_vector_preserves_an_independent_recording_reader() {
	mut document := html.parse_document('<!doctype html><style>html,body{margin:0}div{height:40px;background:green}</style><div></div><div></div><div>retained capture</div>')
	defer { document.finalize() }
	_ = layout_document_typed_in_viewport(document, 320, 200)
	first := document.record_display_list()?
	capture_scene := retain_display_list_scene(first)
	defer { release_display_list_scene(capture_scene) }
	shell_scene := retain_display_list_scene(first)
	first_commands := display_list_commands(first)
	first_snapshot := recording_snapshot(first_commands)
	first_dump := first.dump()

	document.set_viewport_rect(dom.Rect{0, 10, 320, 200})
	second := document.record_display_list()?
	second_scene := retain_display_list_scene(second)
	defer { release_display_list_scene(second_scene) }
	second_snapshot := recording_snapshot(display_list_commands(second))
	// The shell has adopted a new frame, but another consumer retains first.
	release_display_list_scene(shell_scene)
	recycle_display_list_commands(second, first_commands)
	document.set_viewport_rect(dom.Rect{0, 20, 320, 200})
	third := document.record_display_list()?
	assert display_list_commands(third).data != first_commands.data
	assert recording_snapshot(display_list_commands(third)) != first_snapshot
	assert recording_snapshot(display_list_commands(first)) == first_snapshot
	assert recording_snapshot(display_list_commands(second)) == second_snapshot
	assert first.dump() == first_dump
}

fn test_recording_survives_layout_replacement_and_native_document_retirement() {
	mut document := dom.Document.create(dom.url_about_blank())
	document.enable_native_storage()
	mut allocations := document.enter_native_storage()
	html.parse_html_from_a_string(document, '<!doctype html><style>html,body{margin:0}div{transform:translateX(3px);background:green}</style><div id="changed">before replacement</div>')
	allocations.finish()
	enable_native_paint_tree_storage(document)
	_ = layout_document_typed_in_viewport(document, 320, 200)
	first := document.record_display_list()?
	first_scene := retain_display_list_scene(first)
	first_commands := display_list_commands(first)
	first_snapshot := recording_snapshot(first_commands)
	first_dump := first.dump()
	old_result := document_layout_result(document)?
	mut changed := document.get_element_by_id('changed')?
	changed.set_inner_html('after replacement')!
	document.update_layout(.debugging)
	current := document.record_display_list()?
	current_result := document_layout_result(document)?
	assert voidptr(current_result) != voidptr(old_result)
	assert current.generation() > first.generation()
	assert display_list_commands(current).any(it.text == 'after replacement')
	assert recording_snapshot(display_list_commands(first)) == first_snapshot
	another_reader := retain_display_list_scene(first)
	assert another_reader == first_scene

	handle := document.layout_engine_handle()
	document.destroy_a_document_and_its_descendants()
	document.finalize()
	retire_native_document_layout(handle)
	document.release_native_storage()
	assert display_list_commands(first).data == first_commands.data
	assert display_list_commands(first).len == first.command_count()
	assert recording_snapshot(display_list_commands(first)) == first_snapshot
	assert first.dump() == first_dump
	// The publisher and document are gone; the final consumers retire storage.
	mut scene := unsafe { &DisplayListScene(first_scene) }
	assert scene.references == 2
	release_display_list_scene(another_reader)
	assert scene.references == 1
	release_display_list_scene(first_scene)
	assert scene.references == 0
	assert scene.pool.live.len == 0
}
