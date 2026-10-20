module css

import dom
import platform

fn test_lazy_computed_geometry_and_provenance_outlive_paint_projection() {
	mut document := dom.Document.create(dom.url_about_blank())
	document.enable_native_storage()
	mut allocations := document.enter_native_storage()
	mut style := computed_properties_with_initial_values()
	mut projection := platform.new_arena('lazy SVG style projection')
	for _ in 0 .. 3 {
		entry := projection.enter()
		values := resolve_computed_values_for_document(style, document)
		projection.leave(entry)
		projection.reset()
		assert values.font_size().to_double() > 0
		assert style.computed_layout_cache_.resolution_provenance != unsafe { nil }
		assert style.computed_layout_cache_.resolution_provenance.matches(style)
		$if prealloc {
			assert document.native_storage().arena.contains(style.computed_layout_cache_.resolution_provenance)
		}
	}
	projection.release()
	allocations.finish()
	document.finalize()
	document.release_native_storage()
}
