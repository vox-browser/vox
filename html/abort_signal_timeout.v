// Copyright (c) 2024, Tim Ledbetter <tim.ledbetter@ladybird.org>
// SPDX-License-Identifier: BSD-2-Clause
// Source DOM/AbortSignal.cpp → WindowOrWorkerGlobalScope.cpp timer boundary.
module html

import dom
import highresolutiontime

pub fn (settings &EnvironmentSettingsObject) window_or_worker_global_scope() !&WindowOrWorkerGlobalScopeMixin {
	if window := settings.window_ { return window.window_or_worker_global_scope() }
	if worker := settings.worker_ { return worker.window_or_worker_global_scope() }
	return error('AbortSignal.timeout requires a Window or Worker global')
}

pub fn (settings &EnvironmentSettingsObject) global_relative_event_timestamp() f64 {
	return highresolutiontime.current_high_resolution_time(highresolutiontime.TimeOriginContext{
		time_origin:                      settings.time_origin()
		cross_origin_isolated_capability: settings.cross_origin_isolated_capability() == .yes
	})
}

pub fn abort_signal_timeout(settings &EnvironmentSettingsObject, milliseconds u64) !&dom.AbortSignal {
	scope := settings.window_or_worker_global_scope()!
	return dom.AbortSignal.timeout_in_context(milliseconds, dom.AbortSignalTimeoutContext{
		run_steps_after_timeout: fn [scope] (delay u64, completion fn ()) {
			mut owner := unsafe { &WindowOrWorkerGlobalScopeMixin(scope) }
			// The pinned source passes UnsignedLongLong into the scope's i32 API.
			owner.run_steps_after_a_timeout(i32(delay), completion)
		}
		queue_timer_task:        fn [settings] (steps fn ()) {
			queue_a_task(.timer_task, settings.responsible_event_loop(), settings.responsible_document(), steps)
		}
		event_timestamp:         fn [settings] () f64 {
			return settings.global_relative_event_timestamp()
		}
	})
}
