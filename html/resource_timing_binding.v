// Fetch's reporting closure reaches its actual Window or Worker global.
module html

import fetch
import performancetimeline
import resourcetiming

pub fn (settings &EnvironmentSettingsObject) fetch_timing_global_identity() voidptr {
	return voidptr(settings.global_object())
}

fn resource_timing_scope(settings &EnvironmentSettingsObject) &WindowOrWorkerGlobalScopeMixin {
	if window := settings.window_ { return window.window_or_worker_global_scope() }
	if worker := settings.worker_ { return worker.window_or_worker_global_scope() }
	panic('ResourceTiming requires a Window or Worker global')
}

fn resource_timing_context(settings &EnvironmentSettingsObject) &resourcetiming.ResourceTimingContext {
	mut scope := resource_timing_scope(settings)
	if context := scope.resource_timing_context_ { return context }
	context := &resourcetiming.ResourceTimingContext{
		time_origin: settings.time_origin()
		cross_origin_isolated_capability: settings.fetch_request_client_cross_origin_isolated_capability()
		queue_and_buffer_entry: fn [scope] (entry &performancetimeline.PerformanceEntry) {
			mut owner := unsafe { &WindowOrWorkerGlobalScopeMixin(scope) }
			mut performance := owner.performance()
			performance.add_entry(entry)
		}
	}
	scope.resource_timing_context_ = context
	return context
}

fn resource_timing_info(info &fetch.FetchTimingInfo) resourcetiming.FetchTimingInfo {
	connection := if value := info.final_connection_timing_info {
		?resourcetiming.ConnectionTimingInfo(resourcetiming.ConnectionTimingInfo{
			alpn_negotiated_protocol: value.alpn_negotiated_protocol
			domain_lookup_start_time: value.domain_lookup_start
			domain_lookup_end_time: value.domain_lookup_end
			connection_start_time: value.connect_start
			connection_end_time: value.connect_end
			secure_connection_start_time: value.secure_connection_start
		})
	} else { ?resourcetiming.ConnectionTimingInfo(none) }
	return resourcetiming.FetchTimingInfo{
		start_time: info.start_time
		end_time: info.end_time
		final_service_worker_start_time: info.final_service_worker_start_time
		redirect_start_time: info.redirect_start_time
		redirect_end_time: info.redirect_end_time
		post_redirect_start_time: info.post_redirect_start_time
		final_connection_timing_info: connection
		final_network_request_start_time: info.final_network_request_start_time
		final_network_response_start_time: info.final_network_response_start_time
		first_interim_network_response_start_time: info.first_interim_network_response_start_time
		render_blocking: info.render_blocking
	}
}

pub fn (settings &EnvironmentSettingsObject) fetch_mark_resource_timing(info &fetch.FetchTimingInfo,
	requested_url string, initiator_type string, cache_state ?fetch.CacheState,
	body_info fetch.BodyInfo, response_status u16) {
	mut context := resource_timing_context(settings)
	resourcetiming.PerformanceResourceTiming.mark_resource_timing(mut context,
		resource_timing_info(info), requested_url, initiator_type, cache_state, body_info, response_status, '')
}
