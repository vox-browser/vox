module dom

import platform

fn test_svg_dependency_registration_outlives_the_paint_projection() {
	for native in [false, true] {
		mut document := Document.create(url_about_blank())
		if native { document.enable_native_storage() }
		mut allocations := document.enter_native_storage()
		mut resource := document.create_element('div')!
		first := document.create_element('span')!
		second := document.create_element('span')!
		mut projection := platform.new_arena('SVG dependency projection')
		entry := projection.enter()
		resource.register_svg_paint_resource_referencing_element(first)
		projection.leave(entry)
		projection.reset()
		assert resource.svg_paint_references().len == 1
		assert voidptr(resource.svg_paint_references()[0]) == voidptr(first)
		again := projection.enter()
		resource.register_svg_paint_resource_referencing_element(first)
		resource.register_svg_paint_resource_referencing_element(second)
		projection.leave(again)
		projection.release()
		assert resource.svg_paint_references().len == 2
		assert voidptr(resource.svg_paint_references()[1]) == voidptr(second)
		allocations.finish()
		document.finalize()
		if native { document.release_native_storage() }
	}
}
