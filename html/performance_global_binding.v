// HighResolutionTime::Performance retains and operates on its actual global.
module html

import dom
import highresolutiontime
import navigationtiming
import performancetimeline

fn global_performance_time_context(scope &WindowOrWorkerGlobalScopeMixin) highresolutiontime.TimeOriginContext {
	if realm := scope.error_reporting_realm_ {
		if realm.settings_handle != unsafe { nil } {
			settings := unsafe { &EnvironmentSettingsObject(realm.settings_handle) }
			return highresolutiontime.TimeOriginContext{
				time_origin:                      settings.time_origin()
				cross_origin_isolated_capability: settings.cross_origin_isolated_capability() == .yes
			}
		}
	}
	return highresolutiontime.TimeOriginContext{}
}

fn global_performance_entry(entry &performancetimeline.PerformanceEntry) PerformanceEntry {
	return PerformanceEntry{ name: entry.name, entry_type: entry.entry_type, start_time: entry.start_time, duration: entry.duration, native_entry: entry }
}

fn performance_entry_object(entry PerformanceEntry) &performancetimeline.PerformanceEntry {
	if native := entry.native_entry { return native }
	return performancetimeline.PerformanceEntry.new(entry.name, entry.entry_type, entry.start_time, entry.duration)
}

fn create_global_scope_performance(scope &WindowOrWorkerGlobalScopeMixin) &GlobalScopePerformance {
	target := scope.error_reporting_target_ or { unsafe { &dom.EventTarget(scope) } }
	implementation := highresolutiontime.Performance.create(highresolutiontime.PerformanceHost{
		global_handle:             voidptr(target)
		time:                      global_performance_time_context(scope)
		window_context:            scope.associated_window_ != none
		create_timing:             fn [scope] () &navigationtiming.PerformanceTiming {
			window := scope.associated_window_ or { panic('PerformanceTiming requires a Window') }
			return &navigationtiming.PerformanceTiming{
				estimated_monotonic_epoch:       highresolutiontime.estimated_monotonic_time_of_the_unix_epoch()
				load_timing_info_provider:       fn [window] () navigationtiming.DocumentLoadTimingInfo {
					timing := window.associated_document().load_timing_info
					return navigationtiming.DocumentLoadTimingInfo{
						navigation_start_time:               timing.navigation_start_time
						dom_loading_time:                    timing.dom_loading_time
						dom_interactive_time:                timing.dom_interactive_time
						dom_content_loaded_event_start_time: timing.dom_content_loaded_event_start_time
						dom_content_loaded_event_end_time:   timing.dom_content_loaded_event_end_time
						dom_complete_time:                   timing.dom_complete_time
						load_event_start_time:               timing.load_event_start_time
						load_event_end_time:                 timing.load_event_end_time
					}
				}
				previous_unload_timing_provider: fn [window] () navigationtiming.DocumentUnloadTimingInfo {
					document := window.associated_document()
					return navigationtiming.DocumentUnloadTimingInfo{
						unload_event_start_time: document.previous_document_unload_timing.unload_event_start_time
						unload_event_end_time:   document.previous_document_unload_timing.unload_event_end_time
					}
				}
			}
		}
		current_time_context:      fn [scope] () highresolutiontime.TimeOriginContext {
			return global_performance_time_context(scope)
		}
		queue_entry:               fn [scope] (entry &performancetimeline.PerformanceEntry) {
			mut owner := unsafe { &WindowOrWorkerGlobalScopeMixin(scope) }
			owner.queue_performance_entry(global_performance_entry(entry))
		}
		buffer_entry:              fn [scope] (entry &performancetimeline.PerformanceEntry) {
			mut owner := unsafe { &WindowOrWorkerGlobalScopeMixin(scope) }
			if entry.entry_type == 'resource' {
				owner.add_resource_timing_entry(global_performance_entry(entry))
			} else {
				owner.add_performance_entry(global_performance_entry(entry))
			}
		}
		filter_entries:            fn [scope] (name ?string, kind ?string) []&performancetimeline.PerformanceEntry {
			return scope.filter_buffer_map_by_name_and_type(name, kind).map(performance_entry_object(it))
		}
		buffer_entries:            fn [scope] (kind string) []&performancetimeline.PerformanceEntry {
			tuple := scope.performance_entry_buffer_map_[kind] or { return []&performancetimeline.PerformanceEntry{} }
			return tuple.performance_entry_buffer.map(performance_entry_object(it))
		}
		remove_entries:            fn [scope] (kind string, name ?string) {
			mut owner := unsafe { &WindowOrWorkerGlobalScopeMixin(scope) }
			if entry_name := name {
				owner.remove_entries_from_performance_entry_buffer(kind, entry_name)
			} else {
				owner.clear_performance_entry_buffer(kind)
			}
		}
		set_resource_buffer_limit: fn [scope] (maximum u32) {
			mut owner := unsafe { &WindowOrWorkerGlobalScopeMixin(scope) }
			owner.resource_timing_buffer_limit_ = maximum
		}
	})
	return &GlobalScopePerformance{ Performance: *implementation }
}

pub fn (mut performance GlobalScopePerformance) set_onresourcetimingbufferfull(handler ?highresolutiontime.ResourceTimingBufferFullHandler) {
	performance.resource_handler_ = handler
	mut listener := ?&dom.CallbackType(none)
	if callback := handler {
		listener = &dom.CallbackType{ handle_event: fn [callback] (_ &dom.Event, _ ?&dom.EventTarget) dom.JSValue {
			callback()
			return dom.js_undefined()
		} }
	}
	performance.EventTarget.set_event_handler_attribute('resourcetimingbufferfull', listener)
}

pub fn (performance &GlobalScopePerformance) onresourcetimingbufferfull() ?highresolutiontime.ResourceTimingBufferFullHandler {
	return performance.resource_handler_
}
