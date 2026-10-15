module browserjs

import libjs
import dom
import html

$if gcboehm ? {
	fn C.GC_gcollect()
}

@[heap]
struct DocumentSourceRecords {
mut:
	records []&libjs.Script
}

fn test_javascriptcore_document_sources_keep_owned_script_records_without_a_second_ast() {
	$if !darwin { return }
	mut runtime := Runtime.create()
	defer { runtime.close() }
	mut records := &DocumentSourceRecords{}
	owner_handle := voidptr(runtime)
	runtime.define_host_function('captureDocumentSource', fn [owner_handle, mut records] (_ string) !string {
		owner := unsafe { &Runtime(owner_handle) }
		vm := owner.libjs_vm()
		assert vm.execution_context_stack().len == 2
		active := vm.get_active_script_or_module()
		assert active.kind == .script
		record := active.script or { return error('Missing document Script Record') }
		assert record.parsed == unsafe { nil }
		assert voidptr(record.realm) == voidptr(owner.libjs_realm())
		assert record.host_defined == owner_handle
		assert record.external_source_text != none
		records.records << record
		return 'captured'
	})!
	runtime.evaluate_host('globalThis.sourceOrder = []; globalThis.console = {error(value){sourceOrder.push(String(value))}};')!
	strict_source := '"first directive"; "use strict"; captureDocumentSource(""); Promise.resolve().then(()=>sourceOrder.push("job"));'
	sloppy_source := 'captureDocumentSource(""); sourceOrder.push("continued");'
	runtime.run_document_scripts([
		ScriptSource{code: strict_source, url: 'https://source.test/strict.js', starting_line: 12},
		ScriptSource{code: sloppy_source, url: 'https://source.test/sloppy.js', starting_line: 30},
	])!
	assert records.records.len == 2
	assert voidptr(records.records[0]) != voidptr(records.records[1])
	assert records.records[0].external_source_text? == strict_source
	assert records.records[0].filename == 'https://source.test/strict.js'
	assert records.records[0].starting_line == 12
	assert records.records[0].is_strict_mode
	assert records.records[1].external_source_text? == sloppy_source
	assert records.records[1].filename == 'https://source.test/sloppy.js'
	assert records.records[1].starting_line == 30
	assert !records.records[1].is_strict_mode
	$if gcboehm ? { C.GC_gcollect() }
	assert records.records[0].external_source_text? == strict_source
	assert runtime.evaluate_host('JSON.stringify(sourceOrder)')! == '["job","continued"]'
	assert runtime.libjs_vm().execution_context_stack().len == 1
	assert runtime.libjs_vm().get_active_script_or_module().is_empty()
}

fn test_javascriptcore_validates_positioned_document_syntax_before_running_any_author_code() {
	$if !darwin { return }
	mut runtime := Runtime.create()
	defer { runtime.close() }
	runtime.evaluate_host('globalThis.sourceStarted = 0;')!
	errors := runtime.run_document_scripts_collect_errors([
		ScriptSource{code: 'sourceStarted++;\nlet duplicate; let duplicate;', url: 'https://source.test/early.js', starting_line: 20},
		ScriptSource{code: 'sourceStarted++; /[a-/;', url: 'https://source.test/regex.js', starting_line: 40},
		ScriptSource{code: 'sourceStarted++;', url: 'https://source.test/line.js', starting_line: 0},
		ScriptSource{code: 'sourceStarted++;', source_type: .module},
		ScriptSource{code: 'sourceStarted += 42;'},
	])
	assert errors.len == 4
	assert errors[0].starts_with('SyntaxError: https://source.test/early.js:21:'), errors[0]
	assert errors[1].starts_with('SyntaxError: https://source.test/regex.js:40:'), errors[1]
	assert errors[2] == 'Script starting line must be positive'
	assert errors[3].contains('Module execution is not yet implemented')
	assert runtime.evaluate('sourceStarted')! == '42'
	assert runtime.libjs_vm().execution_context_stack().len == 1
	runtime.close()
	assert runtime.run_document_scripts_collect_errors([ScriptSource{code: 'invalid ; ; source'}]) == ['JavaScript runtime is closed']
}

fn test_javascriptcore_accepts_deep_valid_document_source_and_keeps_explicit_preparation_full() {
	$if !darwin { return }
	mut runtime := Runtime.create()
	defer { runtime.close() }
	deep := 'globalThis.documentBackendAnswer = ' + '('.repeat(80) + '42' + ')'.repeat(80) + ';'
	assert runtime.run_document_scripts_collect_errors([ScriptSource{code: deep}]).len == 0
	assert runtime.evaluate('documentBackendAnswer')! == '42'
	prepared := prepare_script(ScriptSource{code: '"use strict"; const explicitAnswer = 42;'})!
	assert prepared.frontend.source_text == prepared.source.code
	assert prepared.frontend.is_strict_mode
	assert prepared.frontend.dump_ast()!.contains('VariableDeclaration')
	assert runtime.evaluate_prepared(prepared)! == 'use strict'
}

fn test_document_syntax_diagnostic_conversion_keeps_the_actual_script_settings_context() {
	$if !darwin { return }
	mut runtime := Runtime.create()
	defer { runtime.close() }
	document_url := dom.URL{value: 'https://source.test/'}
	document := &dom.Document{url: document_url, origin_: document_url.origin()}
	window := html.WindowModel.create_top_level(document, none, 'syntax-diagnostic-owner')!
	settings := unsafe { &html.EnvironmentSettingsObject(window.associated_document().relevant_settings_object()) }
	runtime.bind_scripting_environment(settings)!
	owner_handle := voidptr(runtime)
	runtime.define_host_function('captureSyntaxDiagnostic', fn [owner_handle, settings] (_ string) !string {
		owner := unsafe { &Runtime(owner_handle) }
		vm := owner.libjs_vm()
		assert settings.realm().script_execution_depth == 1
		assert vm.execution_context_stack().len == 2
		record := vm.get_active_script_or_module().script or { return error('Missing syntax diagnostic Script owner') }
		assert record.filename == 'https://source.test/invalid.js'
		assert (record.external_source_text or { return error('Missing external source') }) == 'let invalid = ;'
		return 'SyntaxError: custom diagnostic'
	})!
	errors := runtime.run_document_scripts_collect_errors([
		ScriptSource{code: 'Error.prototype.toString = function(){return captureSyntaxDiagnostic("")};'},
		ScriptSource{code: 'let invalid = ;', url: 'https://source.test/invalid.js', starting_line: 7},
	])
	assert errors.len == 1
	assert errors[0].starts_with('SyntaxError: https://source.test/invalid.js:7:'), errors[0]
	assert errors[0].contains('custom diagnostic')
	assert !runtime.libjs_vm().has_running_execution_context()
	assert settings.realm().script_execution_depth == 0
}
