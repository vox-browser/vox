module browserjs

@[heap]
struct NumberHostCounter {
mut:
	value f64
}

fn test_number_host_function_reads_live_scalars_in_both_engines_and_rejects_closed_runtime() {
	mut engines := [Engine.libjs]
	$if darwin || linux { engines << .javascriptcore }
	for engine in engines {
		mut runtime := Runtime.create_with_engine(engine)
		defer { runtime.close() }
		mut counter := &NumberHostCounter{value: 7}
		runtime.define_number_host_function('counter', fn [counter] () f64 { return counter.value })!
		assert runtime.evaluate('counter()')! == '7'
		counter.value = 9007199254740991.0
		assert runtime.evaluate('counter() === 9007199254740991')! == 'true'
		counter.value = -0.5
		assert runtime.evaluate('counter()')! == '-0.5'
		runtime.close()
		if _ := runtime.define_number_host_function('closed', fn () f64 { return 0 }) {
			assert false
		} else { assert err.msg().contains('closed') }
	}
}

fn test_number_host_function_does_not_coerce_unused_arguments_or_share_runtime_owners() {
	$if !darwin && !linux { return }
	mut first := Runtime.create()
	mut second := Runtime.create()
	defer { first.close(); second.close() }
	first.define_number_host_function('counter', fn () f64 { return 11 })!
	second.define_number_host_function('counter', fn () f64 { return 22 })!
	assert first.evaluate_host('counter({toString(){throw new Error("coerced")},valueOf(){throw new Error("coerced")}})===11')! == 'true'
	assert second.evaluate_host('counter()===22')! == 'true'
	first.close()
	assert second.evaluate_host('counter()===22')! == 'true'
}
