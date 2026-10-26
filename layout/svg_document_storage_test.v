module layout

import dom
import platform

fn test_native_svg_payload_and_retained_scene_survive_host_workspace_and_retirement() {
	$if !prealloc {
		return
	}
	mut host := dom.Document.create(dom.URL{ value: 'https://svg-owner.test/' })
	host.enable_native_storage()
	mut host_scope := host.enter_native_storage()
	mut frame := platform.new_arena('SVG owner host frame')
	entry := frame.enter()
	mut image := parse_svg_image_document(SVGImageSource{
		source: '<svg xmlns="http://www.w3.org/2000/svg" width="60" height="40"><path id="shape" d="M0 0L60 0L30 40Z" fill="green"/></svg>'.clone()
		url:    dom.URL{ value: 'https://svg-owner.test/image.svg' }
	}, 'light', host) or { panic('missing SVG') }
	mut child_owner := image.native_storage()
	assert child_owner != unsafe { nil }
	shape := image.get_element_by_id('shape') or { panic('missing shape') }
	assert child_owner.arena.contains(shape)
	frame.leave(entry)
	frame.release()
	host_scope.finish()
	mut image_scope := child_owner.enter_nested()
	enable_native_paint_tree_storage(image)
	_ = run_document_layout(image, 60, 40) or { panic('missing SVG layout') }
	list := image.record_display_list() or { panic('missing SVG paint') }
	reader := retain_display_list_scene(list)
	expected_dump := list.dump()
	image_scope.finish()
	host.finalize()
	host.release_native_storage()
	// The host has closed the child publisher, but this scene still holds its
	// payload lease, including source strings originally created in the frame.
	assert image.native_storage() == unsafe { nil }
	assert child_owner.arena.usage().used > 0
	assert shape.get_attribute_value('d') == 'M0 0L60 0L30 40Z'
	assert list.dump() == expected_dump
	assert display_list_commands(list).any(it.kind == 'draw_svg_path')
	release_display_list_scene(reader)
	assert child_owner.arena.usage().used == 0
}

fn test_svg_document_header_survives_nested_native_paint_scratch_and_early_retirement() {
	$if !prealloc {
		return
	}
	mut host := dom.Document.create(dom.URL{ value: 'https://svg-owner.test/' })
	host.enable_native_storage()
	mut host_scope := host.enter_native_storage()
	mut frame := platform.new_arena('SVG paint projection')
	entry := frame.enter()
	scratch := platform.begin_thread_scratch('SVG native replay')
	mut image := parse_svg_image_document(SVGImageSource{
		source: '<svg xmlns="http://www.w3.org/2000/svg" width="20" height="20"><path d="M0 0H20V20H0Z" fill="white"/></svg>'.clone()
		url:    dom.URL{ value: 'https://svg-owner.test/mask.svg' }
	}, 'light', host) or { panic('missing SVG') }
	mut child_owner := image.native_storage()
	assert !child_owner.arena.contains(image)
	assert !host.native_storage().arena.contains(image)
	assert !frame.contains(image)
	scratch.finish()
	frame.leave(entry)
	frame.release()
	host_scope.finish()
	mut image_scope := child_owner.enter_nested()
	enable_native_paint_tree_storage(image)
	_ = run_document_layout(image, 20, 20) or { panic('missing SVG layout') }
	_ = image.record_display_list() or { panic('missing SVG paint') }
	image_scope.finish()
	retire_svg_image_document(image)
	assert image.native_storage() == unsafe { nil }
	assert image.layout_engine_handle() == unsafe { nil }
	assert child_owner.arena.usage().used == 0
	// The host's registered cleanup calls retirement again after early disposal.
	host.finalize()
	host.release_native_storage()
	assert image.native_storage() == unsafe { nil }
}
