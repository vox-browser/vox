module main

import libjs
import os
import json2

@[heap]
struct ModuleProbe {
mut:
	vm &libjs.VM
	modules map[string]&libjs.SourceTextModule
	aliases map[string]string
}

fn (mut probe ModuleProbe) load(path string) !&libjs.SourceTextModule {
	key := os.real_path(path)
	if module_record := probe.modules[key] { return module_record }
	module_record := libjs.SourceTextModule.parse_with_options(os.read_file(key)!,probe.vm.realm(),key,
		unsafe { nil },libjs.ParseOptions{max_recursion_depth:256})!
	probe.modules[key]=module_record
	return module_record
}

fn probe_error(err IError) string {
	if libjs.is_throw_completion(err) {
		value := libjs.thrown_value(err)
		if value.is_object() { return value.as_object().error_message() or { err.msg() } }
	}
	return err.msg()
}

// A language/runtime diagnostic for unmodified, local module trees. It supplies
// file loading only: it does not emulate browser APIs or establish hydration or
// pixel correctness. Browser validation must use the native HTML Fetch host.
fn main() {
	if os.args.len<2 { eprintln('Usage: libjs_module_probe ENTRY.js ...');exit(2) }
	mut vm := libjs.VM.create()
	libjs.create_simple_execution_context(mut vm)
	mut probe := &ModuleProbe{vm:vm}
	if alias_file := os.getenv_opt('LIBJS_PROBE_IMPORTS') {
		probe.aliases=json2.decode[map[string]string](os.read_file(alias_file) or { eprintln(err);exit(2) }) or { eprintln(err);exit(2) }
	}
	vm.host_load_imported_module=fn [probe] (referrer libjs.ImportedModuleReferrer,request libjs.ModuleRequest,_ voidptr,payload libjs.ImportedModulePayload) {
		mut owner := unsafe { &ModuleProbe(probe) }
		specifier := request.module_specifier.str()
		alias := owner.aliases[specifier] or { '' }
		mut result := libjs.ModuleLoadResult{}
		if alias=='' && !specifier.starts_with('./') && !specifier.starts_with('../') && !os.is_abs_path(specifier) {
			result=libjs.ModuleLoadResult.from_error(owner.vm.throw_error(.type_error,'Probe requires a local relative or absolute module path: ${specifier}'))
		} else {
			path := if alias!='' { alias } else if os.is_abs_path(specifier) { specifier } else { os.join_path(os.dir(referrer.filename()),specifier) }
			module_record := owner.load(path) or {
				libjs.finish_loading_imported_module(referrer,request,payload,libjs.ModuleLoadResult.from_error(owner.vm.throw_error(.syntax_error,err.msg())))
				return
			}
			result=libjs.ModuleLoadResult.from_module(libjs.Module(module_record))
		}
		libjs.finish_loading_imported_module(referrer,request,payload,result)
	}
	mut failures := 0
	for path in os.args[1..] {
		mut entry := probe.load(path) or { eprintln('${path}: ${probe_error(err)}');failures++;continue }
		loading := entry.load_requested_modules(mut vm,unsafe { nil })
		if loading.promise.state!=.fulfilled {
			eprintln('${path}: load: ${probe_error(libjs.throw_completion(loading.promise.result))}');failures++;continue
		}
		entry.link(mut vm) or { eprintln('${path}: link: ${probe_error(err)}');failures++;continue }
		result := entry.evaluate(mut vm) or { eprintln('${path}: evaluate: ${probe_error(err)}');failures++;continue }
		if result.promise.state==.rejected {
			eprintln('${path}: evaluate: ${probe_error(libjs.throw_completion(result.promise.result))}');failures++;continue
		}
		println('${path}: evaluated')
	}
	println('modules=${probe.modules.len} failures=${failures}')
	if failures>0 { exit(1) }
}
