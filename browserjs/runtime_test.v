module browserjs

fn test_javascript_core_evaluates_ecmascript_and_reports_exceptions() {
	mut runtime := Runtime.create()
	defer {
		runtime.close()
	}
	$if darwin {
		assert runtime.evaluate('JSON.stringify({ answer: 6 * 7 })')! == '{"answer":42}'
		assert runtime.evaluate('globalThis.answer = 41; "set"')! == 'set'
		assert runtime.evaluate('answer + 1')! == '42'
		if _ := runtime.evaluate('throw new Error("boom")') {
			assert false
		} else {
			assert err.msg().contains('boom')
		}
	} $else {
		assert runtime.evaluate('1 + 1') or { err.msg() }.contains('macOS')
	}
}

fn test_javascript_core_drains_promise_jobs_between_evaluations() {
	$if darwin {
		mut runtime := Runtime.create()
		defer {
			runtime.close()
		}
		assert runtime.evaluate('globalThis.promise_value = 0; Promise.resolve().then(() => promise_value = 42); promise_value')! == '0'
		assert runtime.evaluate('promise_value')! == '42'
	}
}
