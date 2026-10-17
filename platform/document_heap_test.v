module platform

import os

$if gcboehm ? {
	fn C.GC_gcollect_and_unmap()
}

fn test_document_heap_hint_is_bounded_preserves_overrides_and_keeps_managed_data() {
	$if gcboehm ? {
		settings := ['GC_INITIAL_HEAP_SIZE', 'GC_MAXIMUM_HEAP_SIZE', 'GC_FREE_SPACE_DIVISOR']
		previous := settings.map(os.getenv(it))
		defer {
			for index, setting in settings { os.setenv(setting, previous[index], true) }
		}
		for setting in settings { os.setenv(setting, '', true) }
		initial := gc_heap_usage()
		before := initial.heap_size + initial.unmapped_bytes
		assert !prepare_document_heap(document_heap_element_threshold - 1)
		small := gc_heap_usage()
		assert small.heap_size + small.unmapped_bytes == before
		for setting in settings {
			os.setenv(setting, '8', true)
			assert !prepare_document_heap(document_heap_element_threshold)
			unchanged := gc_heap_usage()
			assert unchanged.heap_size + unchanged.unmapped_bytes == before
			os.setenv(setting, '', true)
		}
		retained := {'text': ['Unicode λ and 🌍', 'nested retained value']}
		_ = prepare_document_heap(document_heap_element_threshold)
		assert gc_is_enabled()
		prepared := gc_heap_usage()
		capacity := prepared.heap_size + prepared.unmapped_bytes
		assert capacity >= document_heap_capacity
		assert capacity <= before + document_heap_capacity
		assert !prepare_document_heap(document_heap_element_threshold)
		gc_collect()
		assert retained['text'][0] == 'Unicode λ and 🌍'
		assert retained['text'][1] == 'nested retained value'
		// Idle collection must release physical pages without making the next
		// document acquire the same virtual capacity from the OS again.
		for _ in 0 .. 3 {
			C.GC_gcollect_and_unmap()
			unmapped := gc_heap_usage()
			assert unmapped.unmapped_bytes > 0
			assert unmapped.heap_size + unmapped.unmapped_bytes == capacity
			assert !prepare_document_heap(document_heap_element_threshold)
			reused := gc_heap_usage()
			assert reused.heap_size + reused.unmapped_bytes == capacity
			assert gc_is_enabled()
			assert retained['text'][0] == 'Unicode λ and 🌍'
			assert retained['text'][1] == 'nested retained value'
		}
	} $else {
		assert !prepare_document_heap(document_heap_element_threshold)
	}
}
