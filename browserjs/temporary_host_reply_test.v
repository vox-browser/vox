module browserjs

import platform

fn temporary_test_reply(input string) !HostFunctionReply {
	if input == 'throw' { return error('temporary host exception') }
	work := platform.begin_thread_scratch('temporary host reply test')
	value := 'reply:' + input + '\x00雪😀'
	work.leave()
	return HostFunctionReply{value: value, workspace: work}
}

fn test_temporary_host_reply_is_copied_before_its_storage_retires() {
	mut engines := [Engine.libjs]
	$if darwin || linux { engines << .javascriptcore }
	for engine in engines {
		mut runtime := Runtime.create_with_engine(engine)
		defer { runtime.close() }
		runtime.define_temporary_host_function('temporary', temporary_test_reply)!
		runtime.define_host_function('ordinary', fn (input string) !string { return input })!
		assert runtime.evaluate('var kept=temporary("λ");temporary("overwrite");kept;')! == 'reply:λ\x00雪😀'
		// Scratch poisoning retires both responses before these later reads.
		work := platform.begin_thread_scratch('temporary reply overwrite')
		_ = []u8{len: 128 * 1024, init: u8(0xa5)}
		work.finish()
		assert runtime.evaluate('ordinary(kept);')! == 'reply:λ\x00雪😀'
	}
}

fn test_temporary_host_reply_exception_preserves_the_runtime_and_other_hosts() {
	mut engines := [Engine.libjs]
	$if darwin || linux { engines << .javascriptcore }
	for engine in engines {
		mut runtime := Runtime.create_with_engine(engine)
		defer { runtime.close() }
		runtime.define_temporary_host_function('temporary', temporary_test_reply)!
		runtime.evaluate('temporary("throw");') or {
			assert err.msg().contains('temporary host exception')
			assert runtime.evaluate('temporary("after");')! == 'reply:after\x00雪😀'
			continue
		}
		assert false
	}
}
