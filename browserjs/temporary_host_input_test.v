module browserjs

import platform

@[heap]
struct TemporaryInputState {
mut:
	kept string
	ordinary string
}

fn test_temporary_input_can_supply_the_reply_and_publish_owned_native_state() {
	mut runtime := Runtime.create()
	defer { runtime.close() }
	mut state := &TemporaryInputState{}
	runtime.define_temporary_host_function('borrowed', fn [mut state] (input string) !HostFunctionReply {
		state.kept = 'native:' + input
		return HostFunctionReply{value: input}
	})!
	runtime.define_host_function('ordinary', fn [mut state] (input string) !string {
		state.ordinary = input
		return input
	})!
	mut owner := platform.new_retained_arena('temporary input native state')
	mut entered := owner.enter()
	defer {
		entered.finish()
		owner.release()
	}
	assert runtime.evaluate('var kept=borrowed("λ\\u0000雪😀");borrowed("overwrite");kept;')! == 'λ\x00雪😀'
	assert runtime.evaluate('ordinary(kept);')! == 'λ\x00雪😀'
	churn := platform.begin_thread_scratch('temporary input overwrite')
	_ = []u8{len: 256 * 1024, init: u8(0xa5)}
	churn.finish()
	assert state.kept == 'native:overwrite'
	assert state.ordinary == 'λ\x00雪😀'
	$if prealloc {
		assert owner.arena.contains(state.kept.str)
		assert owner.arena.contains(state.ordinary.str)
	}
}

fn test_temporary_input_conversion_keeps_object_coercion_and_reentry_outside_scratch() {
	mut runtime := Runtime.create()
	defer { runtime.close() }
	mut state := &TemporaryInputState{}
	runtime.define_host_function('publish', fn [mut state] (input string) !string {
		state.kept = input
		return input
	})!
	runtime.define_temporary_host_function('borrowed', fn (input string) !HostFunctionReply {
		return HostFunctionReply{value: input}
	})!
	assert runtime.evaluate('borrowed({toString(){publish("retained during conversion");return "converted"}});')! == 'converted'
	assert runtime.evaluate('borrowed({toString(){throw new Error("conversion failed")}});') or {
		assert err.msg().contains('could not be converted')
		'failed'
	} == 'failed'
	assert runtime.evaluate('borrowed(42);')! == '42'
	assert runtime.evaluate('borrowed();')! == 'undefined'
	work := platform.begin_thread_scratch('coercion input overwrite')
	_ = []u8{len: 256 * 1024, init: u8(0xa5)}
	work.finish()
	assert state.kept == 'retained during conversion'
}

fn test_temporary_input_exception_is_copied_before_retirement_and_host_resumes() {
	mut runtime := Runtime.create()
	defer { runtime.close() }
	runtime.define_temporary_host_function('borrowed', fn (input string) !HostFunctionReply {
		if input.starts_with('throw:') { return error(input) }
		return HostFunctionReply{value: input}
	})!
	assert runtime.evaluate('var message;try{borrowed("throw:λ\\u0000雪😀")}catch(e){message=e.message}borrowed("overwrite");message;')! == 'throw:λ\x00雪😀'
	assert runtime.evaluate('borrowed("after");')! == 'after'
}

fn temporary_input_retention_trial(temporary bool) !i64 {
	mut runtime := Runtime.create()
	defer { runtime.close() }
	if temporary {
		runtime.define_temporary_host_function('consume', fn (_ string) !HostFunctionReply { return HostFunctionReply{value: 'ok'} })!
	} else {
		runtime.define_host_function('consume', fn (_ string) !string { return 'ok' })!
	}
	runtime.evaluate('var request="λ😀".repeat(8192);consume(request);')!
	mut owner := platform.new_retained_arena('temporary input measurement')
	mut entered := owner.enter()
	defer {
		entered.finish()
		owner.release()
	}
	before := owner.arena.usage().used
	assert runtime.evaluate('for(var i=0;i<32;i++)consume(request);"done";')! == 'done'
	return owner.arena.usage().used - before
}

fn test_temporary_input_conversion_does_not_retain_request_sized_buffers() {
	control := temporary_input_retention_trial(false)!
	candidate := temporary_input_retention_trial(true)!
	$if prealloc {
		assert control > 2 * 1024 * 1024
		assert candidate < control / 100, '${candidate} candidate versus ${control} control bytes'
		println('Temporary host input: candidate=${candidate} control=${control} bytes')
	}
}
