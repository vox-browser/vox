module browserjs

fn test_libjs_javascript_url_preserves_nonstring_completions_without_coercion_or_jsc() {
	mut runtime := Runtime.create_with_engine(.libjs)
	defer { runtime.close() }
	for source in ['void(0)', '42', 'false', 'null', 'var coercions=0;({toString(){coercions++;return "bad document"}})'] {
		assert runtime.evaluate_javascript_url(source)!.markup == none
	}
	assert runtime.evaluate_host('coercions')! == '0'
	assert runtime.evaluate_javascript_url('"<p>Привет</p>"')!.markup? == '<p>Привет</p>'
	assert !runtime.native_context_initialized()
}

fn test_libjs_javascript_url_runs_once_and_propagates_errors() {
	mut runtime := Runtime.create_with_engine(.libjs)
	defer { runtime.close() }
	assert runtime.evaluate_javascript_url('var count=0;count++;void(0)')!.markup == none
	assert runtime.evaluate_host('count')! == '1'
	runtime.evaluate_javascript_url('count++;throw new Error("URL failure")') or {
		assert err.msg().contains('URL failure')
		assert runtime.evaluate_host('count')! == '2'
		assert !runtime.native_context_initialized()
		return
	}
	assert false, 'A thrown completion must reach the navigation error path'
}
