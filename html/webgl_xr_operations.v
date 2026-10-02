// Copyright (c) 2024-2025, Aliaksandr Kalenik <kalenik.aliaksandr@gmail.com>
// Copyright (c) 2024-2025, Luke Wilde <luke@ladybird.org>
// SPDX-License-Identifier: BSD-2-Clause
module html

import webgl
import webidl

// Adapt EventLoopPlugin's deferred invocation to an owning HTML loop task;
// the source's Unspecified settlement task remains a distinct queued task.
pub fn make_webgl_xr_compatible(context &webgl.WebGLRenderingContext, settings &EnvironmentSettingsObject) &webidl.Promise {
	owner := settings.responsible_event_loop()
	return context.make_xr_compatible(settings.stream_promise_context(),
		fn [owner] (steps fn ()) { queue_a_task(.unspecified, owner, none, steps) },
		fn [owner, settings] (steps fn ()) {
			queue_a_task(.unspecified, owner, none, fn [settings, steps] () {
				mut realm := unsafe { &ScriptingRealm(settings.realm()) }
				mut execution := TemporaryExecutionContext.create(mut realm, .yes)
				defer { execution.close() }
				steps()
			})
		})
}
