// SPDX-License-Identifier: BSD-2-Clause
module browserjs

fn test_libjs_promise_job_failures_reach_document_messages_without_jsc() {
	mut runtime := Runtime.create_with_engine(.libjs)
	defer { runtime.close() }
	runtime.evaluate('Promise.resolve().then(function(){with({}){}})')!
	messages := runtime.take_libjs_messages()
	assert messages.len == 1
	assert messages[0].contains('Promise job:') && messages[0].contains('not translated')
	assert runtime.take_libjs_messages().len == 0
	runtime.evaluate('var result=0;Promise.reject(42).catch(function(x){result=x})')!
	assert runtime.evaluate('result')! == '42'
	assert runtime.take_libjs_messages().len == 0 && runtime.context == unsafe { nil }
}
