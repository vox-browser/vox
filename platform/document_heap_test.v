module platform

import os

$if gcboehm ? {
	fn C.GC_gcollect()

	struct DocumentHeapTestDivisor {
	mut:
		value usize
	}

	fn document_heap_test_read_divisor(context voidptr) voidptr {
		mut divisor := unsafe { &DocumentHeapTestDivisor(context) }
		divisor.value = C.GC_get_free_space_divisor()
		return unsafe { nil }
	}

	fn document_heap_test_write_divisor(context voidptr) voidptr {
		divisor := unsafe { &DocumentHeapTestDivisor(context) }
		C.GC_set_free_space_divisor(divisor.value)
		return unsafe { nil }
	}

	fn document_heap_test_divisor() usize {
		mut divisor := DocumentHeapTestDivisor{}
		C.GC_call_with_alloc_lock(document_heap_test_read_divisor, &divisor)
		return divisor.value
	}

	fn document_heap_test_set_divisor(value usize) {
		divisor := DocumentHeapTestDivisor{value: value}
		C.GC_call_with_alloc_lock(document_heap_test_write_divisor, &divisor)
	}
}

fn test_document_heap_hint_leaves_small_pages_and_explicit_settings_alone() {
	$if gcboehm ? {
		threshold := document_heap_reservation_element_threshold()
		before := C.GC_get_heap_size()
		original_divisor := document_heap_test_divisor()
		assert !reserve_gc_heap_for_document(4)
		assert !reserve_gc_heap_for_document(threshold - 1)
		assert C.GC_get_heap_size() == before
		assert document_heap_test_divisor() == original_divisor
		old_initial := os.getenv('GC_INITIAL_HEAP_SIZE')
		old_maximum := os.getenv('GC_MAXIMUM_HEAP_SIZE')
		old_divisor := os.getenv('GC_FREE_SPACE_DIVISOR')
		if old_initial != '' || old_maximum != '' || old_divisor != '' {
			assert !reserve_gc_heap_for_document(threshold)
			assert C.GC_get_heap_size() == before
			assert document_heap_test_divisor() == original_divisor
			return
		}
		defer {
			os.setenv('GC_INITIAL_HEAP_SIZE', old_initial, true)
			os.setenv('GC_MAXIMUM_HEAP_SIZE', old_maximum, true)
			os.setenv('GC_FREE_SPACE_DIVISOR', old_divisor, true)
			document_heap_test_set_divisor(original_divisor)
		}
		os.setenv('GC_INITIAL_HEAP_SIZE', '134217728', true)
		assert !reserve_gc_heap_for_document(threshold)
		assert document_heap_test_divisor() == original_divisor
		os.setenv('GC_INITIAL_HEAP_SIZE', '', true)
		os.setenv('GC_MAXIMUM_HEAP_SIZE', '134217728', true)
		assert !reserve_gc_heap_for_document(threshold)
		assert document_heap_test_divisor() == original_divisor
		os.setenv('GC_MAXIMUM_HEAP_SIZE', '', true)
		os.setenv('GC_FREE_SPACE_DIVISOR', '8', true)
		assert !reserve_gc_heap_for_document(threshold)
		assert document_heap_test_divisor() == original_divisor
		os.setenv('GC_FREE_SPACE_DIVISOR', '', true)
		assert C.GC_get_heap_size() == before
		document_heap_test_set_divisor(2)
		retained := 'still managed after expansion'.repeat(30)
		// Keep pointer-bearing aggregates across both the expansion and a full
		// collection; the reservation is a growth hint, not a GC bypass.
		mut nested := {
			'children': [retained, 'Unicode λ and 🌍']
		}
		original := nested['children'] or { panic('missing retained children') }
		_ = reserve_gc_heap_for_document(threshold)
		assert C.GC_get_heap_size() >= usize(64) * 1024 * 1024
		assert document_heap_test_divisor() == 16
		assert !reserve_gc_heap_for_document(threshold)
		document_heap_test_set_divisor(32)
		assert !reserve_gc_heap_for_document(threshold)
		assert document_heap_test_divisor() == 32
		C.GC_gcollect()
		assert retained.ends_with('after expansion')
		assert nested['children'] == original
		nested['children'] << 'appended after collection'
		C.GC_gcollect()
		assert nested['children'][0] == retained
		assert nested['children'][1] == 'Unicode λ and 🌍'
		assert nested['children'][2] == 'appended after collection'
	} $else {
		assert !reserve_gc_heap_for_document(document_heap_reservation_element_threshold())
	}
}
