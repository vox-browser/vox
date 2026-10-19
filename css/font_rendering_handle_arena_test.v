module css

import platform

// Keyframe sampling can create a font's cached native handle while an
// animation-sample arena is entered; the handle must outlive that arena.
fn test_rendering_handle_created_inside_an_arena_outlives_it() {
	font := platform_default_font_boundary(12, FontVariationSettings{}, ShapeFeatures{})
	mut arena := platform.new_arena('test')
	defer { arena.release() }
	entry := arena.enter()
	handle := font.font_for_rendering()
	arena.leave(entry)
	$if prealloc {
		assert !arena.contains(voidptr(handle))
	}
	arena.reset()
	assert voidptr(font.font_for_rendering()) == voidptr(handle)
}
