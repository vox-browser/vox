module libjs

import os

@[heap]
struct LoaderTestModule {
	name string
mut:
	module_realm   &Realm
	loaded         []LoadedModuleRequest
	meta           ?&Object
	reject_load    bool
	fail_link      bool
	evaluate_state PromiseState = .fulfilled
	linked         bool
	evaluated      bool
}

fn (module_record &LoaderTestModule) filename() string {
	return module_record.name
}

fn (module_record &LoaderTestModule) realm() &Realm {
	return module_record.module_realm
}

fn (module_record &LoaderTestModule) loaded_modules() []LoadedModuleRequest {
	return module_record.loaded
}

fn (module_record &LoaderTestModule) import_meta() ?&Object {
	return module_record.meta
}

fn (mut module_record LoaderTestModule) append_loaded_module(record LoadedModuleRequest) {
	module_record.loaded << record
}

fn (mut module_record LoaderTestModule) set_import_meta(import_meta &Object) {
	module_record.meta = import_meta
}

fn (mut module_record LoaderTestModule) load_requested_modules(mut vm VM, host_defined voidptr) &PromiseCapability {
	mut promise := Promise.create(module_record.module_realm)
	if module_record.reject_load {
		promise.set_is_handled()
		promise.reject(mut vm, Value.from_i32(1))
	} else {
		promise.fulfill(js_undefined())
	}
	return PromiseCapability.create(promise, none, none)
}

fn (mut module_record LoaderTestModule) link(mut vm VM) ! {
	if module_record.fail_link {
		return vm.throw_error(.syntax_error, 'link failed')
	}
	module_record.linked = true
}

fn (mut module_record LoaderTestModule) evaluate(mut vm VM) !&PromiseCapability {
	module_record.evaluated = true
	mut promise := Promise.create(module_record.module_realm)
	match module_record.evaluate_state {
		.fulfilled { promise.fulfill(js_undefined()) }
		.rejected { promise.reject(mut vm, Value.from_i32(2)) }
		.pending {}
	}
	return PromiseCapability.create(promise, none, none)
}

@[heap]
struct LoaderTestResults {
mut:
	items []ModuleLoadResult
	names []string
}

fn loader_test_directory(name string) string {
	directory := os.join_path(os.temp_dir(), 'libjs-vm-${name}-${os.getpid()}')
	os.rmdir_all(directory) or {}
	os.mkdir_all(directory) or { panic(err) }
	return directory
}

fn test_lexical_paths_and_module_filename_resolution() {
	assert lexical_canonicalized_path('/a/./b/../c') == '/a/c'
	assert lexical_canonicalized_path('a//b/') == 'a/b'
	assert lexical_canonicalized_path('../x/./y') == '../x/y'
	assert lexical_canonicalized_path('/..') == '/'
	assert lexical_canonicalized_path('.') == '.'
	assert lexical_absolute_path('/base/dir', './mod') == '/base/dir/mod'
	assert lexical_absolute_path('/base/dir', '/abs/mod.js') == '/abs/mod.js'
	assert lexical_absolute_path('.', 'entry.js') == 'entry.js'
	directory := loader_test_directory('resolve')
	defer {
		os.rmdir_all(directory) or {}
	}
	os.write_file(os.join_path(directory, 'plain.js'), 'export {};')!
	os.write_file(os.join_path(directory, 'esm.mjs'), 'export {};')!
	os.mkdir(os.join_path(directory, 'package'))!
	os.write_file(os.join_path(directory, 'package', 'index.mjs'), 'export {};')!
	os.write_file(os.join_path(directory, 'data.json'), '{}')!
	assert resolve_module_filename(os.join_path(directory, 'plain'), '') == os.join_path(directory, 'plain.js')
	assert resolve_module_filename(os.join_path(directory, 'esm'), '') == os.join_path(directory, 'esm.mjs')
	assert resolve_module_filename(os.join_path(directory, 'package'), '') == os.join_path(directory, 'package', 'index.mjs')
	assert resolve_module_filename(os.join_path(directory, 'data'), 'json') == os.join_path(directory, 'data.json')
	assert resolve_module_filename(os.join_path(directory, 'plain'), 'json') == os.join_path(directory, 'plain')
	assert resolve_module_filename(os.join_path(directory, 'missing'), '') == os.join_path(directory, 'missing')
}

fn test_load_imported_module_reads_parses_and_stores_file_modules() {
	directory := loader_test_directory('load')
	defer {
		os.rmdir_all(directory) or {}
	}
	os.write_file(os.join_path(directory, 'dep.js'), '\xEF\xBB\xBFexport const value = await Promise.resolve(1);')!
	os.write_file(os.join_path(directory, 'broken.js'), 'export let ;')!
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	realm := vm.realm()
	mut script := Script.parse('import("./dep");', realm, os.join_path(directory, 'main.js'), unsafe { nil })!
	referrer := ImportedModuleReferrer.from_script(script)
	mut results := &LoaderTestResults{}
	on_finished := fn [mut results] (result ModuleLoadResult) {
		results.items << result
	}
	state := &GraphLoadingState{}
	payload := ImportedModulePayload.for_graph_loading_state(state, on_finished)
	request := ModuleRequest{
		module_specifier: utf16_string('./dep')
	}
	vm.host_load_imported_module(referrer, request, unsafe { nil }, payload)
	assert results.items.len == 1
	loaded := results.items[0].module_record?
	assert loaded.filename() == os.join_path(directory, 'dep.js')
	assert voidptr(loaded.realm()) == voidptr(realm)
	assert script.loaded_modules.len == 1
	assert script.loaded_modules[0].specifier.str() == './dep'
	assert same_module(script.loaded_modules[0].module_record, loaded)
	assert vm.stored_module_count() == 1
	assert vm.stored_module(0).has_once_started_linking
	assert vm.get_stored_module(referrer, os.join_path(directory, 'dep.js'), '')? == 0
	if loaded is SourceTextModule {
		assert loaded.has_top_level_await()
	} else {
		assert false, 'file modules must be source text modules'
	}
	// Loading the same specifier again reuses the stored module without a second parse.
	vm.host_load_imported_module(referrer, request, unsafe { nil }, payload)
	assert results.items.len == 2
	assert same_module(results.items[1].module_record?, loaded)
	assert vm.stored_module_count() == 1
	assert script.loaded_modules.len == 1
	// Distinct import attributes record a second LoadedModuleRequest entry.
	typed_request := ModuleRequest{
		module_specifier: utf16_string('./dep')
		attributes:       [ImportAttribute{utf16_string('type'), utf16_string('javascript')}]
	}
	vm.host_load_imported_module(referrer, typed_request, unsafe { nil }, payload)
	assert script.loaded_modules.len == 2
	assert !module_requests_equal(script.loaded_modules[0], typed_request)
	assert module_requests_equal(script.loaded_modules[1], typed_request)

	missing := ModuleRequest{
		module_specifier: utf16_string('./missing')
	}
	vm.host_load_imported_module(referrer, missing, unsafe { nil }, payload)
	missing_result := results.items.last()
	assert missing_result.is_error()
	missing_error := missing_result.thrown?.as_object()
	assert missing_error.error_kind()? == .syntax_error
	assert missing_error.error_message()? == "Cannot find/open module: './missing'"

	broken := ModuleRequest{
		module_specifier: utf16_string('./broken')
	}
	vm.host_load_imported_module(referrer, broken, unsafe { nil }, payload)
	broken_error := results.items.last().thrown?.as_object()
	assert broken_error.error_kind()? == .syntax_error
	assert broken_error.error_message()?.starts_with('SyntaxError: 1:')
	assert vm.stored_module_count() == 1

	// A realm referrer resolves relative to the active script.
	mut script_context := ExecutionContext.create(0, [], 0)
	script_context.realm = realm
	script_context.script_or_module = ScriptOrModule.from_script(script)
	vm.push_execution_context(mut script_context)
	assert vm.get_active_script_or_module().filename() == os.join_path(directory, 'main.js')
	vm.host_load_imported_module(ImportedModuleReferrer.from_realm(realm), request, unsafe { nil }, payload)
	assert same_module(results.items.last().module_record?, loaded)
	vm.pop_execution_context()
}

fn test_dynamic_imports_and_json_modules_follow_the_vm_gates() {
	directory := loader_test_directory('dynamic')
	defer {
		os.rmdir_all(directory) or {}
	}
	os.write_file(os.join_path(directory, 'dep.js'), 'export const value = 1;')!
	os.write_file(os.join_path(directory, 'data.json'), '{"answer": 42}')!
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	realm := vm.realm()
	mut script := Script.parse('1;', realm, os.join_path(directory, 'main.js'), unsafe { nil })!
	referrer := ImportedModuleReferrer.from_script(script)
	mut results := &LoaderTestResults{}
	on_finished := fn [mut results] (result ModuleLoadResult) {
		results.items << result
	}
	mut promise := Promise.create(realm)
	capability := PromiseCapability.create(promise, none, none)
	payload := ImportedModulePayload.for_promise_capability(capability, on_finished)
	request := ModuleRequest{
		module_specifier: utf16_string('./dep')
	}
	vm.host_load_imported_module(referrer, request, unsafe { nil }, payload)
	denied := results.items[0].thrown?.as_object()
	assert denied.error_kind()? == .internal_error
	assert denied.error_message()? == 'Dynamic Imports are not allowed'
	assert script.loaded_modules.len == 0
	vm.set_dynamic_imports_allowed(true)
	vm.host_load_imported_module(referrer, request, unsafe { nil }, payload)
	assert results.items[1].module_record?.filename() == os.join_path(directory, 'dep.js')

	json_request := ModuleRequest{
		module_specifier: utf16_string('./data')
		attributes:       [ImportAttribute{utf16_string('type'), utf16_string('json')}]
	}
	vm.host_load_imported_module(referrer, json_request, unsafe { nil }, payload)
	json_error := results.items[2].thrown?.as_object()
	assert json_error.error_kind()? == .internal_error
	assert json_error.error_message()?.contains('JSON modules require')
	vm.parse_json_module = fn (mut vm VM, realm &Realm, source_text string, filename string) !Module {
		assert source_text == '{"answer": 42}'
		return Module(&LoaderTestModule{
			name:         filename
			module_realm: realm
		})
	}
	vm.host_load_imported_module(referrer, json_request, unsafe { nil }, payload)
	json_module := results.items[3].module_record?
	assert json_module.filename() == os.join_path(directory, 'data.json')
	assert vm.stored_module_count() == 2
	assert script.loaded_modules.len == 2
}

fn test_link_and_eval_module_registers_the_entry_module_and_checks_promises() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	realm := vm.realm()
	mut rejected_load := &LoaderTestModule{
		name:         'rejected-load.js'
		module_realm: realm
		reject_load:  true
	}
	mut rejected_module := Module(rejected_load)
	vm.link_and_eval_module(mut rejected_module) or {
		assert thrown_value(err).as_i32() == 1
	}
	assert !rejected_load.linked
	assert vm.stored_module_count() == 1
	assert vm.stored_module(0).filename == 'rejected-load.js'
	mut failing_link := &LoaderTestModule{
		name:         'failing-link.js'
		module_realm: realm
		fail_link:    true
	}
	mut failing_module := Module(failing_link)
	vm.link_and_eval_module(mut failing_module) or {
		assert thrown_value(err).as_object().error_message()? == 'link failed'
	}
	assert !failing_link.evaluated
	mut rejected_evaluation := &LoaderTestModule{
		name:           'rejected-evaluation.js'
		module_realm:   realm
		evaluate_state: .rejected
	}
	mut rejected_evaluation_module := Module(rejected_evaluation)
	vm.link_and_eval_module(mut rejected_evaluation_module) or {
		assert thrown_value(err).as_i32() == 2
	}
	assert rejected_evaluation.linked && rejected_evaluation.evaluated
	mut order := &LoaderTestResults{}
	vm.enqueue_promise_job(fn [mut order] () !Value {
		order.names << 'job'
		return js_undefined()
	}, realm)
	mut succeeding := &LoaderTestModule{
		name:         'ok.js'
		module_realm: realm
	}
	mut succeeding_module := Module(succeeding)
	vm.link_and_eval_module(mut succeeding_module)!
	assert order.names == ['job']
	assert vm.promise_job_count() == 0
	assert vm.stored_module_count() == 4
	// Re-running the entry module does not duplicate its stored record.
	vm.link_and_eval_module(mut succeeding_module)!
	assert vm.stored_module_count() == 4
	mut anonymous := &LoaderTestModule{
		name:         ''
		module_realm: realm
	}
	mut anonymous_module := Module(anonymous)
	vm.link_and_eval_module(mut anonymous_module)!
	assert vm.stored_module_count() == 4
	assert vm.stored_module(3).referrer.kind == .cyclic_module
}

fn test_source_text_modules_execute_local_exports_and_import_meta_is_memoized() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	realm := vm.realm()
	mut source_module := SourceTextModule.parse('export const value = 1;', realm, 'meta.js', unsafe { nil })!
	assert !source_module.has_top_level_await()
	assert source_module.import_meta() == none
	mut module_record := Module(source_module)
	load_capability := module_record.load_requested_modules(mut vm, unsafe { nil })
	assert load_capability.promise.state == .fulfilled
	module_record.link(mut vm)!
	assert module_record.evaluate(mut vm)!.promise.state == .fulfilled
	assert source_module.local_export_value(mut vm, 'value')!.number == 1
	SourceTextModule.parse('export let ;', realm, 'bad.js', unsafe { nil }) or {
		assert err is ModuleParseError
	}
	mut context := ExecutionContext.create(0, [], 0)
	context.realm = realm
	context.script_or_module = ScriptOrModule.from_module(module_record)
	vm.push_execution_context(mut context)
	assert vm.get_active_script_or_module().filename() == 'meta.js'
	vm.host_get_import_meta_properties = fn (module_record Module) []ImportMetaProperty {
		return [
			ImportMetaProperty{
				key:   PropertyName.from_str('url')
				value: Value.from_i32(7)
			},
		]
	}
	mut finalized := &LoaderTestResults{}
	vm.host_finalize_import_meta = fn [mut finalized] (import_meta &Object, module_record Module) {
		finalized.names << module_record.filename()
	}
	import_meta := vm.get_import_meta()
	assert import_meta.get(mut vm, PropertyName.from_str('url'))!.as_i32() == 7
	assert import_meta.prototype == none
	assert finalized.names == ['meta.js']
	assert voidptr(vm.get_import_meta()) == voidptr(import_meta)
	assert finalized.names.len == 1
	assert voidptr(source_module.import_meta()?) == voidptr(import_meta)
	roots := vm.heap_roots()
	assert roots.contains(module_identity(module_record))
}
