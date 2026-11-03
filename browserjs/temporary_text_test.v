module browserjs

import platform

fn test_temporary_evaluation_text_keeps_script_and_coercion_side_effects_owned() {
	mut runtime := Runtime.create()
	defer { runtime.close() }
	mut state := &HostCallLogForTemporaryText{}
	runtime.define_host_function('publish', fn [mut state] (input string) !string {
		state.value = input
		return input
	})!
	first := runtime.evaluate_host_temporary_text('publish("during evaluation");"λ\\u0000雪😀";')!
	assert first.value == 'λ\x00雪😀'
	second := runtime.evaluate_host_temporary_text('({toString(){publish("during coercion");return "converted"}})')!
	assert second.value == 'converted'
	second.finish()
	assert first.value == 'λ\x00雪😀'
	first.finish()
	first.finish()
	churn := platform.begin_thread_scratch('evaluated text overwrite')
	_ = []u8{len: 128 * 1024, init: u8(0xa5)}
	churn.finish()
	assert state.value == 'during coercion'
}

@[heap]
struct HostCallLogForTemporaryText {
mut:
	value string
}

fn test_temporary_evaluation_preserves_errors_and_closed_runtime_checks() {
	mut runtime := Runtime.create()
	for source in ['throw new Error("temporary evaluation failure")', 'var ='] {
		if result := runtime.evaluate_host_temporary_text(source) {
			result.finish()
			assert false
		} else {
			assert err.msg().contains(if source.starts_with('throw') { 'temporary evaluation failure' } else { 'SyntaxError' })
		}
	}
	result := runtime.evaluate_host_temporary_text('42')!
	assert result.value == '42'
	result.finish()
	runtime.close()
	if closed := runtime.evaluate_host_temporary_text('"closed"') {
		closed.finish()
		assert false
	} else {
		assert err.msg() == 'JavaScript runtime is closed'
	}
}

fn evaluated_text_retention_trial(temporary bool) !i64 {
	mut runtime := Runtime.create()
	defer { runtime.close() }
	runtime.evaluate_host('var state="λ😀".repeat(8192);0;')!
	mut owner := platform.new_retained_arena('evaluated text retention')
	mut entered := owner.enter()
	defer {
		entered.finish()
		owner.release()
	}
	before := owner.arena.usage().used
	for _ in 0 .. 32 {
		if temporary {
			text := runtime.evaluate_host_temporary_text('state')!
			assert text.value.len == 6 * 8192
			text.finish()
		} else {
			assert runtime.evaluate_host('state')!.len == 6 * 8192
		}
	}
	return owner.arena.usage().used - before
}

fn test_temporary_evaluated_text_retires_the_native_conversion_buffers() {
	control := evaluated_text_retention_trial(false)!
	candidate := evaluated_text_retention_trial(true)!
	$if prealloc {
		assert control > 2 * 1024 * 1024
		assert candidate < control / 100, '${candidate} candidate versus ${control} control bytes'
		println('Temporary evaluated text: candidate=${candidate} control=${control} bytes')
	}
}
