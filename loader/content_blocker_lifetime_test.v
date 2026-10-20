module loader

import dom
import platform

fn test_lazy_content_blocker_outlives_its_first_document() {
	previous := loader_global_content_blocker
	loader_global_content_blocker = unsafe { nil }
	defer { loader_global_content_blocker = previous }
	mut document := platform.new_arena('first content blocker document')
	defer { document.release() }
	entry := document.enter()
	blocker := ContentBlocker.the()
	document.leave(entry)
	$if prealloc {
		assert !document.contains(blocker)
	}
	document.reset()
	assert voidptr(ContentBlocker.the()) == voidptr(blocker)
	assert blocker.filtering_enabled()
	assert !blocker.has_rules()
	assert !blocker.is_filtered_for_resource(dom.URL{ value: 'https://images.test/image.svg' },
		dom.URL{ value: 'https://page.test/' }, .image)
	mut retained := ContentBlocker.the()
	retained.set_filtering_enabled(false)
	assert !ContentBlocker.the().filtering_enabled()
}
