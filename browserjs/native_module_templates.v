// SPDX-License-Identifier: BSD-2-Clause
module browserjs

import libjs

@[heap]
struct NativeModulePreparationJob {
	module_record &libjs.SourceTextModule
mut:
	index int
}

pub struct NativeModulePreparationAudit {
pub mut:
	requested_modules     int
	completed_modules     int
	pending_modules       int
	prepared_functions    int
	queued_functions      int
	unsupported_functions int
	diagnostics           []string
}

fn (mut runtime Runtime) queue_native_module_templates(module_record &libjs.SourceTextModule) {
	if !runtime.libjs_native_cache_enabled_ || runtime.libjs_native_cache_failed_ || runtime.closed {
		return
	}
	key := voidptr(module_record)
	if runtime.libjs_native_template_seen_[key] { return }
	runtime.libjs_native_template_seen_[key] = true
	runtime.libjs_native_template_jobs_ << &NativeModulePreparationJob{ module_record: module_record }
	runtime.libjs_native_template_audit_.requested_modules++
}

fn (runtime &Runtime) has_pending_native_module_templates() bool {
	// Fully cached revisits need no speculative bytecode preparation. If a
	// real miss occurs, include the newly requested lazy modules in this visit.
	return runtime.native_code_cache_stats().cache_misses > 0 && runtime.libjs_native_template_jobs_.len > 0
}

fn (mut runtime Runtime) prepare_native_module_templates_batch() {
	if !runtime.has_pending_native_module_templates() { return }
	mut job := runtime.libjs_native_template_jobs_[0]
	mut module_record := unsafe { &libjs.SourceTextModule(job.module_record) }
	result := module_record.prepare_native_function_templates(mut runtime.agent_vm, job.index, 128) or {
		if runtime.libjs_native_template_audit_.diagnostics.len < 16 {
			runtime.libjs_native_template_audit_.diagnostics << '${module_record.filename()}: ${err.msg()}'
		}
		runtime.libjs_native_template_audit_.unsupported_functions++
		runtime.libjs_native_template_jobs_.delete(0)
		runtime.libjs_native_template_audit_.completed_modules++
		return
	}
	job.index = result.next_index
	runtime.libjs_native_template_audit_.prepared_functions += result.prepared
	runtime.libjs_native_template_audit_.queued_functions += result.queued
	runtime.libjs_native_template_audit_.unsupported_functions += result.unsupported
	for message in result.diagnostics {
		if runtime.libjs_native_template_audit_.diagnostics.len < 16 {
			runtime.libjs_native_template_audit_.diagnostics << message
		}
	}
	if result.done {
		runtime.libjs_native_template_jobs_.delete(0)
		runtime.libjs_native_template_audit_.completed_modules++
	}
}
