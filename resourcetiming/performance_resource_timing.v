// Copyright (c) 2026, Ladybird contributors
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of ResourceTiming/PerformanceResourceTiming.{h,cpp,idl}.
module resourcetiming

import fetch
import highresolutiontime
import performancetimeline

pub enum RenderBlockingStatusType {
	blocking
	non_blocking
}

pub fn render_blocking_status_type_from_string(value string) !RenderBlockingStatusType {
	return match value {
		'blocking' { .blocking }
		'non-blocking' { .non_blocking }
		else { error('Invalid RenderBlockingStatusType: ${value}') }
	}
}

pub fn (value RenderBlockingStatusType) str() string {
	return match value {
		.blocking { 'blocking' }
		.non_blocking { 'non-blocking' }
	}
}

pub struct ConnectionTimingInfo {
pub:
	alpn_negotiated_protocol     string
	domain_lookup_start_time     f64
	domain_lookup_end_time       f64
	connection_start_time        f64
	connection_end_time          f64
	secure_connection_start_time f64
}

pub struct FetchTimingInfo {
pub:
	start_time                                f64
	end_time                                  f64
	final_service_worker_start_time           f64
	redirect_start_time                       f64
	redirect_end_time                         f64
	post_redirect_start_time                  f64
	final_connection_timing_info              ?ConnectionTimingInfo
	final_network_request_start_time          f64
	final_network_response_start_time         f64
	first_interim_network_response_start_time f64
	render_blocking                           bool
}

pub struct ResourceTimingContext {
pub:
	time_origin                      f64
	cross_origin_isolated_capability bool
pub mut:
	timeline         &performancetimeline.PerformanceTimeline = performancetimeline.PerformanceTimeline.new(performancetimeline.supported_entry_types)
	resource_entries []&PerformanceResourceTiming
}

pub fn convert_fetch_timestamp(time_stamp f64, context &ResourceTimingContext) f64 {
	if time_stamp == 0 { return 0 }
	return highresolutiontime.coarsen_time(time_stamp - context.time_origin,
		context.cross_origin_isolated_capability)
}

@[heap]
pub struct PerformanceResourceTiming {
mut:
	performance_entry_  &performancetimeline.PerformanceEntry = unsafe { nil }
	timing_info_        FetchTimingInfo
	initiator_type_     string
	requested_url_      string
	response_body_info_ fetch.BodyInfo
	cache_mode_         ?fetch.CacheState
	response_status_    u16
	delivery_type_      string
	context_            &ResourceTimingContext = unsafe { nil }
}

pub fn PerformanceResourceTiming.mark_resource_timing(mut context ResourceTimingContext, timing_info FetchTimingInfo, requested_url string, initiator_type string, cache_mode ?fetch.CacheState, body_info fetch.BodyInfo, response_status u16, delivery_type string) &PerformanceResourceTiming {
	converted_start := convert_fetch_timestamp(timing_info.start_time, context)
	converted_end := convert_fetch_timestamp(timing_info.end_time, context)
	base := &performancetimeline.PerformanceEntry{
		name:            requested_url
		entry_type:      'resource'
		start_time:      converted_start
		duration:        converted_end - converted_start
		available:       .yes
		max_buffer_size: u64(250)
	}
	mut entry := &PerformanceResourceTiming{
		performance_entry_: base
		context_:           context
	}
	entry.setup_the_resource_timing_entry(initiator_type, requested_url, timing_info, cache_mode,
		body_info, response_status, delivery_type)
	context.timeline.add_entry(base)
	context.resource_entries << entry
	return entry
}

fn (mut entry PerformanceResourceTiming) setup_the_resource_timing_entry(initiator_type string, requested_url string, timing_info FetchTimingInfo, cache_mode ?fetch.CacheState, body_info fetch.BodyInfo, response_status u16, delivery_type string) {
	entry.initiator_type_ = initiator_type
	entry.requested_url_ = requested_url
	entry.timing_info_ = timing_info
	entry.response_body_info_ = body_info
	entry.cache_mode_ = cache_mode
	entry.response_status_ = response_status
	entry.delivery_type_ = if delivery_type == '' && cache_mode != none {
		'cache'
	} else {
		delivery_type
	}
}

pub fn (entry &PerformanceResourceTiming) performance_entry() &performancetimeline.PerformanceEntry {
	return entry.performance_entry_
}

pub fn (entry &PerformanceResourceTiming) entry_type() string {
	return 'resource'
}

pub fn (entry &PerformanceResourceTiming) initiator_type() string {
	return entry.initiator_type_
}

pub fn (entry &PerformanceResourceTiming) delivery_type() string {
	return entry.delivery_type_
}

pub fn (entry &PerformanceResourceTiming) next_hop_protocol() string {
	return if info := entry.timing_info_.final_connection_timing_info {
		info.alpn_negotiated_protocol
	} else {
		''
	}
}

pub fn (entry &PerformanceResourceTiming) worker_start() f64 {
	return convert_fetch_timestamp(entry.timing_info_.final_service_worker_start_time,
		entry.context_)
}

pub fn (entry &PerformanceResourceTiming) redirect_start() f64 {
	return convert_fetch_timestamp(entry.timing_info_.redirect_start_time, entry.context_)
}

pub fn (entry &PerformanceResourceTiming) redirect_end() f64 {
	return convert_fetch_timestamp(entry.timing_info_.redirect_end_time, entry.context_)
}

pub fn (entry &PerformanceResourceTiming) fetch_start() f64 {
	return convert_fetch_timestamp(entry.timing_info_.post_redirect_start_time, entry.context_)
}

pub fn (entry &PerformanceResourceTiming) domain_lookup_start() f64 {
	return if info := entry.timing_info_.final_connection_timing_info {
		convert_fetch_timestamp(info.domain_lookup_start_time, entry.context_)
	} else {
		0
	}
}

pub fn (entry &PerformanceResourceTiming) domain_lookup_end() f64 {
	return if info := entry.timing_info_.final_connection_timing_info {
		convert_fetch_timestamp(info.domain_lookup_end_time, entry.context_)
	} else {
		0
	}
}

pub fn (entry &PerformanceResourceTiming) connect_start() f64 {
	return if info := entry.timing_info_.final_connection_timing_info {
		convert_fetch_timestamp(info.connection_start_time, entry.context_)
	} else {
		0
	}
}

pub fn (entry &PerformanceResourceTiming) connect_end() f64 {
	return if info := entry.timing_info_.final_connection_timing_info {
		convert_fetch_timestamp(info.connection_end_time, entry.context_)
	} else {
		0
	}
}

pub fn (entry &PerformanceResourceTiming) secure_connection_start() f64 {
	return if info := entry.timing_info_.final_connection_timing_info {
		convert_fetch_timestamp(info.secure_connection_start_time, entry.context_)
	} else {
		0
	}
}

pub fn (entry &PerformanceResourceTiming) request_start() f64 {
	return convert_fetch_timestamp(entry.timing_info_.final_network_request_start_time,
		entry.context_)
}

pub fn (entry &PerformanceResourceTiming) final_response_headers_start() f64 {
	return convert_fetch_timestamp(entry.timing_info_.final_network_response_start_time,
		entry.context_)
}

pub fn (entry &PerformanceResourceTiming) first_interim_response_start() f64 {
	return convert_fetch_timestamp(entry.timing_info_.first_interim_network_response_start_time,
		entry.context_)
}

pub fn (entry &PerformanceResourceTiming) response_start() f64 {
	interim := entry.first_interim_response_start()
	return if interim != 0 { interim } else { entry.final_response_headers_start() }
}

pub fn (entry &PerformanceResourceTiming) response_end() f64 {
	return convert_fetch_timestamp(entry.timing_info_.end_time, entry.context_)
}

pub fn (entry &PerformanceResourceTiming) encoded_body_size() u64 {
	return entry.response_body_info_.encoded_size
}

pub fn (entry &PerformanceResourceTiming) decoded_body_size() u64 {
	return entry.response_body_info_.decoded_size
}

pub fn (entry &PerformanceResourceTiming) transfer_size() u64 {
	if mode := entry.cache_mode_ {
		if mode == .local { return 0 }
		if mode == .validated { return 300 }
	}
	return entry.response_body_info_.encoded_size + 300
}

pub fn (entry &PerformanceResourceTiming) response_status() u16 {
	return entry.response_status_
}

pub fn (entry &PerformanceResourceTiming) render_blocking_status() RenderBlockingStatusType {
	return if entry.timing_info_.render_blocking { .blocking } else { .non_blocking }
}

pub fn (entry &PerformanceResourceTiming) content_type() string {
	return entry.response_body_info_.content_type
}

pub struct PerformanceResourceTimingJSON {
pub:
	name                         string
	entry_type                   string
	start_time                   f64
	duration                     f64
	initiator_type               string
	delivery_type                string
	next_hop_protocol            string
	worker_start                 f64
	redirect_start               f64
	redirect_end                 f64
	fetch_start                  f64
	domain_lookup_start          f64
	domain_lookup_end            f64
	connect_start                f64
	connect_end                  f64
	secure_connection_start      f64
	request_start                f64
	final_response_headers_start f64
	first_interim_response_start f64
	response_start               f64
	response_end                 f64
	transfer_size                u64
	encoded_body_size            u64
	decoded_body_size            u64
	response_status              u16
	render_blocking_status       RenderBlockingStatusType
	content_type                 string
}

pub fn (entry &PerformanceResourceTiming) to_json() PerformanceResourceTimingJSON {
	base := entry.performance_entry_
	return PerformanceResourceTimingJSON{
		name:                         base.name
		entry_type:                   entry.entry_type()
		start_time:                   base.start_time
		duration:                     base.duration
		initiator_type:               entry.initiator_type()
		delivery_type:                entry.delivery_type()
		next_hop_protocol:            entry.next_hop_protocol()
		worker_start:                 entry.worker_start()
		redirect_start:               entry.redirect_start()
		redirect_end:                 entry.redirect_end()
		fetch_start:                  entry.fetch_start()
		domain_lookup_start:          entry.domain_lookup_start()
		domain_lookup_end:            entry.domain_lookup_end()
		connect_start:                entry.connect_start()
		connect_end:                  entry.connect_end()
		secure_connection_start:      entry.secure_connection_start()
		request_start:                entry.request_start()
		final_response_headers_start: entry.final_response_headers_start()
		first_interim_response_start: entry.first_interim_response_start()
		response_start:               entry.response_start()
		response_end:                 entry.response_end()
		transfer_size:                entry.transfer_size()
		encoded_body_size:            entry.encoded_body_size()
		decoded_body_size:            entry.decoded_body_size()
		response_status:              entry.response_status()
		render_blocking_status:       entry.render_blocking_status()
		content_type:                 entry.content_type()
	}
}
