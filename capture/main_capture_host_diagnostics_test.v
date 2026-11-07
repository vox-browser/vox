module main

import browserjs
import html
import json2
import os

fn test_capture_audit_reports_host_samples_without_closing_or_changing_the_realm() {
	path := os.join_path(os.temp_dir(), 'vox-host-diagnostics-${os.getpid()}.json')
	previous_path := os.getenv_opt('VOX_CAPTURE_AUDIT_PATH')
	previous_config := os.getenv_opt('VOX_CAPTURE_AUDIT_CONFIG')
	defer {
		if value := previous_path {
			os.setenv('VOX_CAPTURE_AUDIT_PATH', value, true)
		} else {
			os.unsetenv('VOX_CAPTURE_AUDIT_PATH')
		}
		if value := previous_config {
			os.setenv('VOX_CAPTURE_AUDIT_CONFIG', value, true)
		} else {
			os.unsetenv('VOX_CAPTURE_AUDIT_CONFIG')
		}
		os.rm(path) or {}
	}
	os.setenv('VOX_CAPTURE_AUDIT_PATH', path, true)
	os.unsetenv('VOX_CAPTURE_AUDIT_CONFIG')
	mut document := html.parse_document('<!doctype html><title>Host observation</title><p>Retained page</p>')
	defer { document.finalize() }
	mut runtime := browserjs.Runtime.create_with_engine(.javascriptcore)
	defer { runtime.close() }
	runtime.define_host_function('captureEcho', fn (input string) !string { return input })!
	assert runtime.evaluate_host('captureEcho("before capture")')! == 'before capture'
	app := BrowserApp{ document: document, js_runtime: &runtime }
	app.write_capture_audit_if_requested()
	audit := json2.decode[CaptureAudit](os.read_file(path)!)!
	assert audit.title == 'Host observation'
	assert runtime.evaluate_host('captureEcho("after capture")')! == 'after capture'
}
