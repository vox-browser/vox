// SPDX-License-Identifier: BSD-2-Clause
module browserjs

import html
import libjs
import platform

// HostEnqueuePromiseJob belongs to the owning HTML event loop. A fetch can
// settle an import after the original JavaScript entry has returned; leaving
// that reaction in the standalone VM queue would require another script entry.
fn (mut runtime Runtime) install_libjs_promise_jobs(settings &html.EnvironmentSettingsObject) {
	owner := &runtime
	mut vm := runtime.agent_vm
	vm.host_enqueue_promise_job = fn [owner, settings] (job libjs.PromiseJob, _ ?&libjs.Realm) {
		if owner.closed { return }
		persistent := platform.enter_persistent()
		defer { platform.leave_persistent(persistent) }
		task := html.Task.create(.microtask, settings.responsible_document(), fn [owner, settings, job] () {
			mut runtime := unsafe { &Runtime(owner) }
			if runtime.closed || html.can_run_script_for_settings(settings) != .run { return }
			persistent := platform.enter_persistent()
			defer { platform.leave_persistent(persistent) }
			previous := if document := settings.responsible_document() { document.current_script() } else { none }
			if mut document := settings.responsible_document() { document.set_current_script(none) }
			runtime.prepare_html_callback(settings)
			defer {
				if mut document := settings.responsible_document() { document.set_current_script(previous) }
				runtime.clean_up_html_callback(settings)
			}
			mut vm := runtime.agent_vm
			vm.run_promise_job_with_limits(job, libjs.ExecutionLimits{max_instructions: 1000000}) or {
				runtime.libjs_messages_ << 'JavaScript (LibJS): Promise job: ' + libjs_exception_message(err)
				runtime.mark_document_state_dirty()
			}
		})
		mut event_loop := settings.responsible_event_loop()
		event_loop.enqueue_microtask(task)
	}
}
