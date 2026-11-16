// SPDX-License-Identifier: BSD-2-Clause
module browserjs

import libjs

pub struct ModuleExecutionAudit {
pub:
	url           string
	status        string
	promise_state string
}

pub struct RuntimeExecutionAudit {
pub:
	engine                     string
	closed                     bool
	native_context_initialized bool
	libjs_execution_generation u32
	native_cache               libjs.NativeCacheStats
	frontend_cache             LibJSFrontendCacheStats
	modules                    []ModuleExecutionAudit
}

// Pure observation: do not create a context, evaluate a pending module, pump
// jobs, invoke getters, or format retained VM/DOM owner graphs.
pub fn (runtime &Runtime) execution_audit() RuntimeExecutionAudit {
	mut modules := []ModuleExecutionAudit{}
	mut names := runtime.libjs_modules_.keys()
	names.sort()
	for name in names {
		module_record := runtime.libjs_modules_[name] or { continue }
		snapshot := module_record.execution_snapshot()
		modules << ModuleExecutionAudit{ url: name.clone(), status: snapshot.status, promise_state: snapshot.promise_state }
	}
	return RuntimeExecutionAudit{
		engine:                     runtime.engine.str()
		closed:                     runtime.closed
		native_context_initialized: runtime.native_context_initialized()
		libjs_execution_generation: runtime.agent_vm.execution_generation()
		native_cache:               runtime.native_code_cache_stats()
		frontend_cache:             runtime.frontend_code_cache_stats()
		modules:                    modules
	}
}
