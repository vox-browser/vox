// SPDX-License-Identifier: BSD-2-Clause
module libjs

import os

pub struct NativeModuleTemplateBatch {
pub:
	next_index  int
	done        bool
	prepared    int
	queued      int
	unsupported int
	diagnostics []string
}

// Compile syntax, never call these functions. Rspack-style lazy modules can
// export factories that have not run during the first page's initial work.
// Constants and register layouts stay in the module's own realm; machine code
// will still read each actual invocation's values and defining environment.
pub fn (mut module_record SourceTextModule) prepare_native_function_templates(mut vm VM, start int, limit int) !NativeModuleTemplateBatch {
	if start < 0 || limit <= 0 { return error('Invalid native function template range') }
	if !vm.native_code_cache_is_idle() {
		return error('Native template preparation requires an idle VM')
	}
	tier := vm.native_tier or { return NativeModuleTemplateBatch{ done: true } }
	mut cache := tier.persistent or { return NativeModuleTemplateBatch{ done: true } }
	count := module_record.parsed.function_table.entries.len
	if start > count { return error('Native function template start exceeds the source table') }
	mut context := ExecutionContext.create(0, [], 0)
	context.realm = module_record.module_realm
	context.lexical_environment = Environment(module_record.module_realm.global_environment_record())
	context.variable_environment = context.lexical_environment
	context.script_or_module = ScriptOrModule.from_module(Module(&module_record))
	vm.push_execution_context_checked(mut context)!
	defer { vm.pop_current_context() }
	source := module_record.compile_module(mut vm)!
	end := if limit > count - start { count } else { start + limit }
	mut prepared := 0
	mut queued := 0
	mut unsupported := 0
	mut diagnostics := []string{}
	for index in start .. end {
		data := module_record.parsed.function_table.entries[index] or { continue }
		if data.kind == .async_generator {
			unsupported++
			if diagnostics.len < 16 {
				diagnostics << '${module_record.module_filename}:${data.source_text_start}: async generator execution is not translated'
			}
			continue
		}
		object := create_ecmascript_function_data(mut vm, source, data, false, none, true)!
		mut callable := Value.from_object(object).as_function()
		if mut callable is ECMAScriptFunction {
			executable := callable.compile(mut vm) or {
				unsupported++
				if diagnostics.len < 16 {
					diagnostics << '${module_record.module_filename}:${data.source_text_start}: ${err.msg()}'
				}
				continue
			}
			prepared++
			key := cache.key(executable)
			if key == '' || key in cache.entries || key in cache.pending || os.is_file(os.join_path(cache.directory, key + '.json')) {
				continue
			}
			// Preserve observed hit/miss counters: this body has not executed.
			// A future real invocation performs its ordinary checked attachment.
			cache.pending[key] = executable
			queued++
		}
	}
	return NativeModuleTemplateBatch{ next_index: end, done: end >= count, prepared: prepared, queued: queued, unsupported: unsupported, diagnostics: diagnostics }
}
