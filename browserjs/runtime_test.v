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
