module fetch

fn test_final_network_offsets_are_relative_to_the_final_redirect_hop() {
	mut timing := FetchTimingInfo.create()
	timing.start_time = 10
	timing.post_redirect_start_time = 40
	timing.update_final_timings(RequestTimingInfo{
		domain_lookup_start_microseconds: 1000
		domain_lookup_end_microseconds: 2000
		connect_start_microseconds: 3000
		connect_end_microseconds: 4000
		secure_connect_start_microseconds: 5000
		request_start_microseconds: 6000
		response_start_microseconds: 7000
		http_version_alpn_identifier: 'h2'
	}, true)
	connection := timing.final_connection_timing_info?
	assert connection.domain_lookup_start == 41
	assert connection.domain_lookup_end == 42
	assert connection.connect_start == 43
	assert connection.connect_end == 44
	assert connection.secure_connection_start == 45
	assert connection.alpn_negotiated_protocol == 'h2'
	assert timing.final_network_request_start_time == 46
	assert timing.final_network_response_start_time == 47
	assert timing.start_time == 10
}

fn test_missing_tls_timestamp_stays_zero_after_final_timing_update() {
	mut timing := FetchTimingInfo.create()
	timing.start_time = 10
	timing.post_redirect_start_time = 40
	timing.final_connection_timing_info = ConnectionTimingInfo{ secure_connection_start: 99 }
	timing.update_final_timings(RequestTimingInfo{
		connect_start_microseconds: 1000
		request_start_microseconds: 2000
		response_start_microseconds: 3000
	}, true)
	connection := timing.final_connection_timing_info?
	assert connection.secure_connection_start == 0
	assert connection.connect_start == 41
	assert timing.final_network_request_start_time == 42
	assert timing.final_network_response_start_time == 43
}
