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

fn test_performance_timing_converts_relative_document_timestamps() {
	timing := PerformanceTiming.with_epoch(DocumentLoadTimingInfo{
		navigation_start_time: 1_700_000_000_000.19
		dom_loading_time: 2.4
		dom_interactive_time: 4.99
		dom_content_loaded_event_start_time: 6.2
		dom_content_loaded_event_end_time: 7.8
		dom_complete_time: 10.1
		load_event_start_time: 11.4
		load_event_end_time: 0
	}, 1000)
	assert timing.document_load_timing_info().dom_complete_time == 10.1
	assert timing.document().dom_complete_time == 10.1
	assert timing.navigation_start() == u64(1_699_999_999_000)
	assert timing.dom_interactive() == u64(1_699_999_999_005)
	assert timing.dom_content_loaded_event_start() == u64(1_699_999_999_006)
	assert timing.dom_content_loaded_event_end() == u64(1_699_999_999_007)
	assert timing.dom_complete() == u64(1_699_999_999_010)
	assert timing.load_event_start() == u64(1_699_999_999_011)
	assert timing.load_event_end() == 0
	assert timing.fetch_start() == 0
	assert timing.response_end() == 0
	assert timing.dom_loading() == u64(1_699_999_999_002)
	assert timing.to_json().dom_complete == timing.dom_complete()
}

fn test_navigation_timing_entry_exposes_resource_and_document_phases() {
	mut context := NavigationTimingContext{
		document_url: 'https://example.test/page'
		time_origin: 1_000
		load_timing_info: DocumentLoadTimingInfo{
			navigation_start_time: 1_000
			dom_loading_time: 4
			dom_interactive_time: 40
			dom_content_loaded_event_start_time: 50
			dom_content_loaded_event_end_time: 52
			dom_complete_time: 90
			load_event_start_time: 95
			load_event_end_time: 100
		}
		previous_document_unload_timing: DocumentUnloadTimingInfo{
			unload_event_start_time: 1
			unload_event_end_time: 2
		}
	}
	entry := PerformanceNavigationTiming.create_navigation_timing_entry(mut context,
		NavigationFetchTimingInfo{
			redirect_start_time: 1_005
			redirect_end_time: 1_010
			post_redirect_start_time: 1_011
			final_network_request_start_time: 1_030
			final_network_response_start_time: 1_035
			end_time: 1_080
			final_connection_timing_info: NavigationConnectionTimingInfo{
				domain_lookup_start_time: 1_012
				domain_lookup_end_time: 1_015
				connection_start_time: 1_016
				connection_end_time: 1_020
				secure_connection_start_time: 1_017
			}
		}, 2, .reload)
	assert entry.entry_type() == 'navigation'
	assert entry.duration() == 100
	assert entry.redirect_start() == 5
	assert entry.redirect_end() == 10
	assert entry.fetch_start() == 11
	assert entry.domain_lookup_start() == 12
	assert entry.connect_end() == 20
	assert entry.response_start() == 35
	assert entry.response_end() == 80
	assert entry.unload_event_start() == 1
	assert entry.dom_content_loaded_event_end() == 52
	assert entry.type_() == .reload
	assert entry.redirect_count() == 2
	assert entry.critical_ch_restart() == 0
	assert PerformanceNavigationTiming.available_from_timeline() == .yes
	assert PerformanceNavigationTiming.max_buffer_size() == none
	assert entry.should_add_entry(none) == .yes
	assert context.navigation_timing_entry? == entry
	tuple := context.timeline.entry_buffers['navigation'] or { panic('missing navigation tuple') }
	assert tuple.performance_entry_buffer == [entry.performance_entry()]
	assert entry.to_json().name == 'https://example.test/page'

	navigation := PerformanceNavigation.create(entry)
	assert navigation.type_() == type_reload
	assert navigation.redirect_count() == 2
	timing := PerformanceTiming.create(context.load_timing_info,
		context.previous_document_unload_timing, entry, 100)
	assert timing.navigation_start() == 900
	assert timing.redirect_start() == 905
	assert timing.fetch_start() == 911
	assert timing.secure_connection_start() == 917
	assert timing.response_end() == 980
}

fn test_navigation_entry_hides_redirect_phases_without_redirects() {
	mut context := NavigationTimingContext{
		time_origin: 10
	}
	entry := PerformanceNavigationTiming.create_navigation_timing_entry(mut context,
		NavigationFetchTimingInfo{
			redirect_start_time: 12
			redirect_end_time: 14
		}, 0, .navigate)
	assert entry.redirect_start() == 0
	assert entry.redirect_end() == 0
}

fn test_performance_extensions_preserves_same_objects() {
	timing_value := PerformanceTiming.with_epoch(DocumentLoadTimingInfo{}, 0)
	navigation_value := PerformanceNavigation.new(type_navigate, 0)
	extensions := PerformanceExtensions.new(&timing_value, &navigation_value)
	assert voidptr(extensions.timing()) == voidptr(&timing_value)
	assert voidptr(extensions.timing()) == voidptr(extensions.timing())
	assert voidptr(extensions.navigation()) == voidptr(&navigation_value)
}
