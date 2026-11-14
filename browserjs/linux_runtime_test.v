module browserjs

fn test_linux_javascriptcore_preserves_length_aware_source_and_host_callbacks() {
	$if !linux { return }
	mut runtime := Runtime.create()
	defer { runtime.close() }
	assert runtime.context != unsafe { nil }
	runtime.define_host_function('nativeEcho', fn (value string) !string {
		return value + '✓'
	})!
	assert runtime.evaluate('nativeEcho("Linux 😀")')! == 'Linux 😀✓'
	assert runtime.evaluate_host('"a\x00b😀".length')! == '5'
	assert runtime.evaluate_host('JSON.stringify([1, 2, 3].map(x => x * 2))')! == '[2,4,6]'
	if _ := runtime.evaluate_host('throw new Error("linux exception")') {
		assert false
	} else {
		if err is JavaScriptValueException {
			assert err.context == runtime.context
			assert js_exception_message(err.context, err.value).contains('linux exception')
		} else {
			assert false, err.msg()
		}
	}
	runtime.close()
	if _ := runtime.evaluate('42') { assert false }
}
