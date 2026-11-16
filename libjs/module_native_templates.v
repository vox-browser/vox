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

struct NativeTemplatePreparation {
mut:
	prepared    int
	queued      int
	unsupported int
	diagnostics []string
}

fn (mut result NativeTemplatePreparation) queue(executable &Executable, mut cache NativeCodeCache) {
	result.prepared++
	key := cache.key(executable)
	if key == '' || key in cache.entries || key in cache.pending
		|| os.is_file(os.join_path(cache.directory, key + '.json')) {
		return
	}
	// This body has not executed. Actual invocations still perform their own
	// checked attachment without changing observed hit/miss counts here.
	cache.pending[key] = executable
	result.queued++
}

fn (mut result NativeTemplatePreparation) prepare_initializers(mut vm VM, mut cache NativeCodeCache, source &Executable, filename string) ! {
	// These synthetic functions are emitted into their owner's bytecode, not
	// the parser's ordinary function table. Include static blocks and nested
	// class definitions without evaluating keys, expressions or class effects.
	for index in 0 .. source.class_field_initializers.len {
		object := create_class_field_initializer(mut vm, source, u32(index), PropertyName.from_str(''))!
		mut callable := Value.from_object(object).as_function()
		if mut callable is ECMAScriptFunction {
			executable := callable.compile(mut vm) or {
				result.unsupported++
				if result.diagnostics.len < 16 {
					result.diagnostics << '${filename}:${callable.data.source_text_start}: ${err.msg()}'
				}
				continue
			}
			// Anonymous function initializers read their field name through a
			// constant slot. The placeholder only supplies its layout: generated
			// code reads the real invocation's key, including unique Symbols.
			result.queue(executable, mut cache)
			result.prepare_initializers(mut vm, mut cache, executable, filename)!
		}
	}
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
	mut result := NativeTemplatePreparation{}
	if start == 0 { result.prepare_initializers(mut vm, mut cache, source, module_record.module_filename)! }
	for index in start .. end {
		data := module_record.parsed.function_table.entries[index] or { continue }
		if data.kind == .async_generator {
			result.unsupported++
			if result.diagnostics.len < 16 {
				result.diagnostics << '${module_record.module_filename}:${data.source_text_start}: async generator execution is not translated'
			}
			continue
		}
		object := create_ecmascript_function_data(mut vm, source, data, false, none, true)!
		mut callable := Value.from_object(object).as_function()
		if mut callable is ECMAScriptFunction {
			executable := callable.compile(mut vm) or {
				result.unsupported++
				if result.diagnostics.len < 16 {
					result.diagnostics << '${module_record.module_filename}:${data.source_text_start}: ${err.msg()}'
				}
				continue
			}
			result.queue(executable, mut cache)
			result.prepare_initializers(mut vm, mut cache, executable, module_record.module_filename)!
		}
	}
	return NativeModuleTemplateBatch{ next_index: end, done: end >= count, prepared: result.prepared, queued: result.queued, unsupported: result.unsupported, diagnostics: result.diagnostics }
}
