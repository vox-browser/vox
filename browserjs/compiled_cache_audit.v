// SPDX-License-Identifier: BSD-2-Clause
module browserjs

import libjs

pub struct CompiledJavaScriptCacheAudit {
pub:
	engine                     string
	native_context_initialized bool
	libjs_execution_generation u32
	native                     libjs.NativeCacheStats
	frontend                   LibJSFrontendCacheStats
}

// Read counters without creating a context, running JavaScript or flushing
// pending compilation. This snapshot can accompany a document capture.
pub fn (runtime &Runtime) compiled_code_cache_audit() CompiledJavaScriptCacheAudit {
	return CompiledJavaScriptCacheAudit{
		engine:                     runtime.engine.str()
		native_context_initialized: runtime.native_context_initialized()
		libjs_execution_generation: runtime.agent_vm.execution_generation()
		native:                     runtime.native_code_cache_stats()
		frontend:                   runtime.frontend_code_cache_stats()
	}
}
