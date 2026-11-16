// SPDX-License-Identifier: BSD-2-Clause
module browserjs

import libjs

pub struct CompiledJavaScriptCacheAudit {
pub:
	engine                     string
	native_context_initialized bool
	libjs_execution_generation u32
	max_instructions_per_entry u64
	native                     libjs.NativeCacheStats
	frontend                   LibJSFrontendCacheStats
	function_bytecode          libjs.FunctionCompilationActivity
	pending_native             []libjs.NativePendingExecutableDiagnostic
	module_preparation         NativeModulePreparationAudit
}

// Read counters without creating a context, running JavaScript or flushing
// pending compilation. This snapshot can accompany a document capture.
pub fn (runtime &Runtime) compiled_code_cache_audit() CompiledJavaScriptCacheAudit {
	return CompiledJavaScriptCacheAudit{
		engine:                     runtime.engine.str()
		native_context_initialized: runtime.native_context_initialized()
		libjs_execution_generation: runtime.agent_vm.execution_generation()
		max_instructions_per_entry: runtime.libjs_execution_limits().max_instructions
		native:                     runtime.native_code_cache_stats()
		frontend:                   runtime.frontend_code_cache_stats()
		function_bytecode:          runtime.realm.function_compilation_stats()
		pending_native:             runtime.agent_vm.pending_native_code_cache_diagnostics(16)
		module_preparation:         NativeModulePreparationAudit{ ...runtime.libjs_native_template_audit_, pending_modules: if runtime.has_pending_native_module_templates() {
			runtime.libjs_native_template_jobs_.len
		} else {
			0
		} }
	}
}
