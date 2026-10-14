module platform

import os

$if gcboehm ? {
	fn C.GC_gcollect()
}

fn test_document_heap_hint_leaves_small_pages_and_explicit_settings_alone() {
	$if gcboehm ? {
		before := C.GC_get_heap_size()
		assert !reserve_gc_heap_for_document(1024)
		assert !reserve_gc_heap_for_document(256 * 1024 - 1)
		assert C.GC_get_heap_size() == before
		old_initial := os.getenv('GC_INITIAL_HEAP_SIZE')
		old_maximum := os.getenv('GC_MAXIMUM_HEAP_SIZE')
		if old_initial != '' || old_maximum != '' {
			assert !reserve_gc_heap_for_document(512 * 1024)
			return
		}
		defer {
			os.setenv('GC_INITIAL_HEAP_SIZE', old_initial, true)
			os.setenv('GC_MAXIMUM_HEAP_SIZE', old_maximum, true)
		}
		os.setenv('GC_INITIAL_HEAP_SIZE', '134217728', true)
		assert !reserve_gc_heap_for_document(512 * 1024)
		os.setenv('GC_INITIAL_HEAP_SIZE', '', true)
		os.setenv('GC_MAXIMUM_HEAP_SIZE', '134217728', true)
		assert !reserve_gc_heap_for_document(512 * 1024)
		os.setenv('GC_MAXIMUM_HEAP_SIZE', '', true)
		retained := 'still managed after expansion'.repeat(30)
		_ = reserve_gc_heap_for_document(256 * 1024)
		assert C.GC_get_heap_size() >= usize(512 * 1024 * 1024)
		assert !reserve_gc_heap_for_document(512 * 1024)
		C.GC_gcollect()
		assert retained.ends_with('after expansion')
	} $else {
		assert !reserve_gc_heap_for_document(1024 * 1024)
	}
}
