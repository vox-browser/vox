module resourcetiming

import fetch

fn timing_info() FetchTimingInfo {
	return FetchTimingInfo{
		start_time: 1010
		end_time: 1100
		final_service_worker_start_time: 1011
		redirect_start_time: 1012
		redirect_end_time: 1013
		post_redirect_start_time: 1014
		final_connection_timing_info: ConnectionTimingInfo{
			alpn_negotiated_protocol: 'h2'
			domain_lookup_start_time: 1020
			domain_lookup_end_time: 1021
			connection_start_time: 1022
			connection_end_time: 1023
			secure_connection_start_time: 1022.5
		}
		final_network_request_start_time: 1030
		final_network_response_start_time: 1040
		first_interim_network_response_start_time: 1035
		render_blocking: true
	}
}

fn test_mark_resource_timing_populates_timeline_and_all_getters() {
	mut context := ResourceTimingContext{
		time_origin: 1000
	}
	entry := PerformanceResourceTiming.mark_resource_timing(mut context, timing_info(), 'https://e.test/a.js', 'script', none, fetch.BodyInfo{
		encoded_size: 50
		decoded_size: 80
		content_type: 'text/javascript'
	}, 200, '')
	assert entry.performance_entry().start_time == 10
	assert entry.performance_entry().duration == 90
	assert entry.entry_type() == 'resource'
	assert PerformanceResourceTiming.available_from_timeline() == .yes
	assert PerformanceResourceTiming.max_buffer_size()? == 250
	assert entry.should_add_entry(none) == .yes
	assert entry.next_hop_protocol() == 'h2'
	assert entry.worker_start() == 11
	assert entry.domain_lookup_start() == 20
	assert entry.connect_end() == 23
	assert entry.response_start() == 35
	assert entry.response_end() == 100
	assert entry.transfer_size() == 350
	assert entry.render_blocking_status() == .blocking
	assert context.resource_entries.len == 1
	tuple := context.timeline.entry_buffers['resource'] or { panic('missing resource tuple') }
	assert tuple.performance_entry_buffer.len == 1
	assert entry.to_json().content_type == 'text/javascript'
}

fn test_cache_transfer_delivery_and_missing_connection_branches() {
	for mode, expected in {
		fetch.CacheState.local:     u64(0)
		fetch.CacheState.validated: u64(300)
	} {
		mut context := ResourceTimingContext{}
		entry := PerformanceResourceTiming.mark_resource_timing(mut context, FetchTimingInfo{}, 'x', '', mode, fetch.BodyInfo{ encoded_size: 99 }, 0, '')
		assert entry.delivery_type() == 'cache'
		assert entry.transfer_size() == expected
		assert entry.next_hop_protocol() == ''
		assert entry.domain_lookup_end() == 0
		assert entry.response_start() == 0
	}
	assert render_blocking_status_type_from_string('non-blocking')! == .non_blocking
	assert RenderBlockingStatusType.blocking.str() == 'blocking'
}
