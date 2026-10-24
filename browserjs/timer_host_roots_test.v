module browserjs

import dom
import html
import highresolutiontime

fn timer_roots_host(mut runtime Runtime) &TimerHost {
	url := dom.URL{value: 'https://timer-roots.example.test/'}
	mut host := TimerHost.create(&dom.Document{url: url, origin_: url.origin()}) or { panic(err) }
	host.install(mut runtime) or { panic(err) }
	return host
}

fn test_completed_timers_release_callback_and_argument_roots_and_discard_results() {
	$if !darwin && !linux { return }
	mut runtime := Runtime.create()
	defer { runtime.close() }
	host := timer_roots_host(mut runtime)
	mut scope := unsafe { &html.WindowOrWorkerGlobalScopeMixin(host.scope) }
	baseline := runtime.protected_values_.len
	runtime.evaluate_host('globalThis.timerRootCalls=0')!
	for _ in 0 .. 32 {
		runtime.evaluate_host(r'setTimeout(function(payload){if(payload.byteLength!==65536)throw "lost timer argument";timerRootCalls++;return {bytes:new ArrayBuffer(65536),get then(){throw "ignored return"}}},60000,new ArrayBuffer(65536))')!
		assert runtime.protected_values_.len == baseline + 2
		scope.run_all_timers()
		assert scope.active_timer_count() == 0 && host.ids.len == 0
		assert runtime.protected_values_.len == baseline
	}
	// Classic timer scripts also have a discarded completion value.
	runtime.evaluate_host('setTimeout("timerRootCalls++;({bytes:new ArrayBuffer(65536)})",60000)')!
	scope.run_all_timers()
	assert runtime.protected_values_.len == baseline
	assert scope.reported_errors().len == 0
	assert runtime.evaluate_host('timerRootCalls')! == '33'
}

fn test_timer_cancellation_releases_only_the_cancelled_handles_roots() {
	$if !darwin && !linux { return }
	mut runtime := Runtime.create()
	defer { runtime.close() }
	host := timer_roots_host(mut runtime)
	mut scope := unsafe { &html.WindowOrWorkerGlobalScopeMixin(host.scope) }
	baseline := runtime.protected_values_.len
	runtime.evaluate_host(r'
globalThis.sharedTimerCalls=0;
globalThis.sharedTimerPayload=new ArrayBuffer(65536);
globalThis.sharedTimerCallback=function(payload){if(payload!==sharedTimerPayload)throw "lost shared argument";sharedTimerCalls++};
globalThis.firstRootTimer=setTimeout(sharedTimerCallback,60000,sharedTimerPayload);
globalThis.secondRootTimer=setInterval(sharedTimerCallback,60000,sharedTimerPayload);
')!
	assert runtime.protected_values_.len == baseline + 4
	runtime.evaluate_host('clearInterval(firstRootTimer);clearTimeout(firstRootTimer);clearTimeout(-1)')!
	assert runtime.protected_values_.len == baseline + 2
	assert host.ids.len == 1
	scope.run_all_timers()
	assert runtime.evaluate_host('sharedTimerCalls')! == '1'
	assert runtime.protected_values_.len == baseline + 2
	// Worker shutdown and native callers clear the source map directly.
	scope.clear_map_of_active_timers()
	assert runtime.protected_values_.len == baseline
	assert host.ids.len == 0
}

fn test_interval_results_do_not_accumulate_roots_and_self_cancellation_is_safe() {
	$if !darwin && !linux { return }
	mut runtime := Runtime.create()
	defer { runtime.close() }
	host := timer_roots_host(mut runtime)
	mut scope := unsafe { &html.WindowOrWorkerGlobalScopeMixin(host.scope) }
	baseline := runtime.protected_values_.len
	runtime.evaluate_host(r'
globalThis.intervalRootCalls=0;
globalThis.intervalRootTimer=setInterval(function(payload){
 if(payload.byteLength!==65536)throw "lost interval argument";
 if(++intervalRootCalls===32)clearTimeout(intervalRootTimer);
 return new ArrayBuffer(65536);
},60000,new ArrayBuffer(65536));
')!
	now := highresolutiontime.unsafe_shared_current_time()
	for tick in 0 .. 32 {
		scope.process_timers(now + f64((tick + 1) * 60001))
		assert runtime.evaluate_host('intervalRootCalls')! == (tick + 1).str()
		expected_roots := baseline + if tick == 31 { 0 } else { 2 }
		assert runtime.protected_values_.len == expected_roots
	}
	assert scope.active_timer_count() == 0 && host.ids.len == 0
	assert scope.reported_errors().len == 0
	assert runtime.evaluate_host('intervalRootCalls')! == '32'
}
