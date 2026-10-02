module browserjs

@[heap]
struct HostCallLog {
mut:
	values []string
}

fn test_host_function_executes_synchronously_and_preserves_string_data() {
	mut engines := [Engine.libjs]
	$if darwin {
		engines << .javascriptcore
	}
	for engine in engines {
		mut runtime := Runtime.create_with_engine(engine)
		defer { runtime.close() }
		mut log := &HostCallLog{}
		runtime.define_host_function('host', fn [mut log] (input string) !string {
			log.values << input
			return 'result:' + input
		})!
		assert runtime.evaluate('host("λ\\u0000😀");')! == 'result:λ\x00😀'
		assert log.values == ['λ\x00😀']
		assert runtime.evaluate('host(42);')! == 'result:42'
		assert log.values == ['λ\x00😀', '42']
	}
}

fn test_host_functions_keep_context_identity_and_resume_after_exception() {
	mut engines := [Engine.libjs]
	$if darwin {
		engines << .javascriptcore
	}
	for engine in engines {
		mut first := Runtime.create_with_engine(engine)
		mut second := Runtime.create_with_engine(engine)
		defer {
			first.close()
			second.close()
		}
		first.define_host_function('host', fn (input string) !string {
			if input == 'throw' { return error('host exception') }
			return 'first:' + input
		})!
		second.define_host_function('host', fn (input string) !string { return 'second:' + input })!
		assert first.evaluate('host("x");')! == 'first:x'
		assert second.evaluate('host("x");')! == 'second:x'
		first.evaluate('host("throw");') or {
			assert err.msg().contains('host exception')
			assert first.evaluate('host("after");')! == 'first:after'
			assert second.evaluate('host("after");')! == 'second:after'
			first.close()
			first.define_host_function('closed', fn (input string) !string { return input }) or {
				assert err.msg() == 'JavaScript runtime is closed'
				continue
			}
			assert false
		}
		assert false
	}
}
