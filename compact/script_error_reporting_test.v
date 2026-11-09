module main

import browserjs
import dom

fn test_uncaught_document_script_errors_dispatch_error_and_continue_with_the_next_script() {
	mut document := parse_browser_navigation_document('<!doctype html><body>', dom.URL{ value: 'https://script-error.test/' }, none)
	mut runtime := browserjs.Runtime.create()
	defer {
		runtime.close()
		document.finalize()
	}
	mut messages := []string{}
	run_document_javascript(document, document.url.serialize(), [
		r'globalThis.failures=[];globalThis.original=new Error("original script failure");addEventListener("error",e=>{failures.push(e.error===original);e.preventDefault()});',
		r'throw original;',
		r'console.log(failures.length,failures[0]);',
	], runtime, mut messages)
	assert runtime.evaluate_host('failures.length===1&&failures[0]===true')! == 'true'
	assert messages.last() == '1 true'
}

fn test_javascript_result_string_conversion_failure_returns_an_error() {
	mut runtime := browserjs.Runtime.create()
	defer { runtime.close() }
	runtime.evaluate_host('({toString(){throw new Error("cannot stringify")}})') or {
		assert err.msg().contains('could not be converted to a string')
		return
	}
	assert false,'string conversion must fail'
}
