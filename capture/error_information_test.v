module main

import browserjs
import dom
import html
import json2

fn test_capture_error_information_uses_report_time_fields_without_author_conversion() {
	mut document := html.parse_document('<!doctype html><title>Error snapshot</title>')
	defer { document.finalize() }
	window := html.WindowModel.create_top_level(document, none, 'error-snapshot')!
	mut runtime := browserjs.Runtime.create()
	defer { runtime.close() }
	value := runtime.evaluate_host_value('globalThis.errorConversions=0;globalThis.originalError=({toString(){errorConversions++;return "report-time value"}});originalError')!
	mut scope := window.window_or_worker_global_scope()
	scope.report_error(dom.js_webidl_value(runtime.webidl_value(value)!))
	assert runtime.evaluate_host('errorConversions')! == '1'
	runtime.evaluate_host('originalError.toString=function(){errorConversions++;return "later value"};0')!
	app := BrowserApp{document: document}
	first := app.collect_capture_audit(CaptureAuditConfig{})!
	assert first.native_reported_error_count == 1 && first.native_reported_errors.len == 0
	assert first.native_reported_error_information.len == 1
	assert first.native_reported_error_information[0].message == 'Uncaught exception: report-time value'
	assert runtime.evaluate_host('errorConversions')! == '1'
	decoded := json2.decode[CaptureAudit](json2.encode(first))!
	assert decoded.native_reported_error_information[0].message == first.native_reported_error_information[0].message
	described := app.collect_capture_audit(CaptureAuditConfig{describe_native_errors: true})!
	assert described.native_reported_errors == ['later value']
	assert described.native_reported_error_information[0].message == first.native_reported_error_information[0].message
	assert runtime.evaluate_host('errorConversions')! == '2'
}

fn test_capture_error_information_keeps_prior_snapshots_and_does_not_create_settings() {
	mut empty := dom.Document.create(dom.URL{value: 'about:blank'})
	defer { empty.finalize() }
	missing := BrowserApp{document: empty}.collect_capture_audit(CaptureAuditConfig{})!
	assert missing.native_reported_error_count == 0 && missing.native_reported_error_information.len == 0
	assert empty.relevant_settings_object() == unsafe { nil }
	mut document := html.parse_document('<!doctype html><title>Error sequence</title>')
	defer { document.finalize() }
	window := html.WindowModel.create_top_level(document, none, 'error-sequence')!
	settings := unsafe { &html.EnvironmentSettingsObject(document.relevant_settings_object()) }
	mut realm := settings.realm()
	realm.error_extraction_context_ = fn (_ dom.JSValue) html.ErrorExtractionContext {
		return html.ErrorExtractionContext{own_message: 'known message', exception_is_error: true,
			traceback: [html.ErrorSourceLocation{filename: 'origin.js', line: 12, column: 34}]}
	}
	mut scope := window.window_or_worker_global_scope()
	scope.report_error(dom.js_string('one'))
	app := BrowserApp{document: document}
	first := app.collect_capture_audit(CaptureAuditConfig{})!
	scope.report_error(dom.js_string('two'))
	second := app.collect_capture_audit(CaptureAuditConfig{})!
	assert first.native_reported_error_count == first.native_reported_error_information.len
	assert first.native_reported_error_information.len == 1 && second.native_reported_error_information.len == 2
	assert second.native_reported_error_information[1].filename == 'origin.js'
	assert second.native_reported_error_information[1].lineno == 12 && second.native_reported_error_information[1].colno == 34
	assert scope.reported_error_count() == 2
}
