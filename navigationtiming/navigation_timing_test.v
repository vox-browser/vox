module navigationtiming

fn test_navigation_constants_and_json() {
	navigation := PerformanceNavigation.new(type_back_forward, 7)
	assert navigation.type_ == 2
	assert navigation.type_() == 2
	assert navigation.redirect_count == 7
	assert navigation.redirect_count() == 7
	assert navigation.to_json().redirect_count == 7
	assert entry_names.len == 21
	assert entry_names[0] == 'connectEnd'
	assert entry_names.last() == 'unloadEventStart'
}

fn test_performance_timing_converts_implemented_timestamps_and_preserves_zero_fixmes() {
	timing := PerformanceTiming.with_epoch(DocumentLoadTimingInfo{
		navigation_start_time: 1_700_000_000_000.19
		dom_interactive_time: 1_700_000_000_004.99
		dom_content_loaded_event_start_time: 1_700_000_000_006.2
		dom_content_loaded_event_end_time: 1_700_000_000_007.8
		dom_complete_time: 1_700_000_000_010.1
		load_event_start_time: 1_700_000_000_011.4
		load_event_end_time: 0
	}, 1000)
	assert timing.document_load_timing_info().dom_complete_time == 1_700_000_000_010.1
	assert timing.navigation_start() == u64(1_699_999_999_000)
	assert timing.dom_interactive() == u64(1_699_999_999_004)
	assert timing.dom_content_loaded_event_start() == u64(1_699_999_999_006)
	assert timing.dom_content_loaded_event_end() == u64(1_699_999_999_007)
	assert timing.dom_complete() == u64(1_699_999_999_010)
	assert timing.load_event_start() == u64(1_699_999_999_011)
	assert timing.load_event_end() == 0
	assert timing.fetch_start() == 0
	assert timing.response_end() == 0
	assert timing.to_json().dom_complete == timing.dom_complete()
}

fn test_performance_extensions_preserves_same_objects() {
	timing_value := PerformanceTiming.with_epoch(DocumentLoadTimingInfo{}, 0)
	navigation_value := PerformanceNavigation.new(type_navigate, 0)
	extensions := PerformanceExtensions.new(&timing_value, &navigation_value)
	assert voidptr(extensions.timing()) == voidptr(&timing_value)
	assert voidptr(extensions.timing()) == voidptr(extensions.timing())
	assert voidptr(extensions.navigation()) == voidptr(&navigation_value)
}
