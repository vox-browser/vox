// SPDX-License-Identifier: BSD-2-Clause
// WorkerGlobalScope's Navigator and Location come from its actual source model.
module browserjs

import html
import loader
import platform

@[heap]
pub struct WorkerEnvironmentHost {
	settings &html.EnvironmentSettingsObject
	scope    &html.WorkerGlobalScope
mut:
	runtime &Runtime = unsafe { nil }
	closed  bool
}

pub fn WorkerEnvironmentHost.create(environment &html.WorkerEnvironmentSettingsObject) !&WorkerEnvironmentHost {
	if voidptr(environment.settings.global_object()) != voidptr(environment.global_scope.this_impl()) {
		return error('Worker environment requires its own global scope')
	}
	if environment.settings.responsible_document() != none {
		return error('Worker environment cannot belong to a Document')
	}
	if !loader.is_initialized() { loader.initialize() }
	persistent := platform.enter_persistent()
	defer { platform.leave_persistent(persistent) }
	return &WorkerEnvironmentHost{ settings: environment.settings, scope: environment.global_scope }
}

pub fn (mut host WorkerEnvironmentHost) close() {
	host.closed = true
}
