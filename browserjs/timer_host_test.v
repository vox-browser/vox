module browserjs

import dom
import html
import platform
import time

fn timer_host_document() &dom.Document {
	url := dom.URL{value: 'https://timer-host.example.test/page.html'}
	return &dom.Document{url: url, origin_: url.origin()}
}

fn wait_for_timer_host(condition fn () bool) {
	deadline := time.sys_mono_now() + i64(2_000_000_000)
	for !condition() && time.sys_mono_now() < deadline { platform.pump_native_events(0.01) }
	assert condition()
}

fn test_native_timer_callback_uses_owner_task_this_arguments_context_and_ignores_thenable_return() {
	$if !darwin { return }
	if !platform.native_timer_scheduling_available() { return }
	mut runtime := Runtime.create()
	defer { runtime.close() }
	mut host := TimerHost.create(timer_host_document())!
	host.install(mut runtime)!
	settings := host.settings
	assert html.can_run_script_for_settings(settings) == .run
	owner_handle := voidptr(runtime)
	runtime.define_value_host_function('__timerOwnerContext', fn [settings, owner_handle] (_ voidptr, _ []voidptr) !voidptr {
		runtime := unsafe { &Runtime(owner_handle) }
		task := settings.responsible_event_loop().currently_running_task() or { panic('missing source timer task') }
		assert task.source() == .timer_task && task.timer_nesting_level() == 1
		assert voidptr(task.document() or { panic('missing owning timer document') }) == voidptr(settings.responsible_document() or { panic('missing document') })
		assert runtime.libjs_vm().has_running_execution_context()
		assert settings.realm().script_execution_depth >= 2 && settings.realm().callback_execution_depth >= 2
		assert voidptr(html.incumbent_settings_object()) == voidptr(settings)
		return C.vox_jsc_JSValueMakeBoolean(runtime.context, true)
	})!
	runtime.evaluate_host(r'
 globalThis.nativeTimerRan=false;globalThis.nativeTimerArgument={};globalThis.nativeTimerThenAccesses=0;
 globalThis.nativeTimerID=setTimeout(function(first,second){"use strict";globalThis.nativeTimerChecks=[this===globalThis,first===nativeTimerArgument,second===undefined,__timerOwnerContext()];nativeTimerRan=nativeTimerChecks.every(Boolean);return {get then(){nativeTimerThenAccesses++;throw "must ignore timer result"}}},5,nativeTimerArgument,undefined);
')!
	assert runtime.evaluate_host('nativeTimerID>0&&Number.isInteger(nativeTimerID)&&!nativeTimerRan')! == 'true'
	mut scope := host.scope
	wait_for_timer_host(fn [scope] () bool { return scope.active_timer_count() == 0 })
	assert html.can_run_script_for_settings(settings) == .run
	assert scope.reported_errors().map(it.to_string_value()) == []string{}
	assert runtime.evaluate_host('nativeTimerChecks.join(",")')! == 'true,true,true,true'
	assert runtime.evaluate_host('nativeTimerRan&&nativeTimerThenAccesses===0')! == 'true'
	assert settings.realm().script_execution_depth == 0 && settings.realm().callback_execution_depth == 0
	assert !runtime.libjs_vm().has_running_execution_context()
	assert runtime.take_document_state_dirty()
}

fn test_native_clear_timer_cancels_already_queued_owner_task_and_interval_reuses_source_id() {
	$if !darwin { return }
	if !platform.native_timer_scheduling_available() { return }
	mut runtime := Runtime.create()
	defer { runtime.close() }
	mut host := TimerHost.create(timer_host_document())!
	host.install(mut runtime)!
	mut loop := unsafe { &html.EventLoop(host.settings.responsible_event_loop()) }
	pause_handle := loop.pause()
	defer { if loop.execution_paused() { loop.unpause(pause_handle) } }
	runtime.evaluate_host('globalThis.cancelledTimerCalls=0;globalThis.cancelledTimer=setTimeout(()=>cancelledTimerCalls++,5)')!
	wait_for_timer_host(fn [loop] () bool {
		if task := loop.task_queue().last_added_task() { return task.source() == .timer_task }
		return false
	})
	runtime.evaluate_host('globalThis.clearTimerCoercions=0;clearInterval({valueOf(){clearTimerCoercions++;return cancelledTimer}})')!
	assert host.scope.active_timer_count() == 0
	loop.unpause(pause_handle)
	loop.schedule()
	wait_for_timer_host(fn [loop] () bool { return loop.task_queue().is_empty() })
	assert runtime.evaluate_host('cancelledTimerCalls===0&&clearTimerCoercions===1')! == 'true'
	runtime.evaluate_host('globalThis.nativeIntervalCalls=0;globalThis.nativeIntervalID=setInterval(function(){nativeIntervalCalls++;if(nativeIntervalCalls===2)clearTimeout(nativeIntervalID)},5)')!
	mut scope := host.scope
	wait_for_timer_host(fn [scope] () bool { return scope.active_timer_count() == 0 })
	assert runtime.evaluate_host('nativeIntervalCalls===2&&nativeIntervalID!==cancelledTimer')! == 'true'
}

fn test_native_timer_conversion_order_original_throws_and_real_string_script_execution() {
	$if !darwin { return }
	if !platform.native_timer_scheduling_available() { return }
	mut runtime := Runtime.create()
	defer { runtime.close() }
	mut host := TimerHost.create(timer_host_document())!
	host.install(mut runtime)!
	assert runtime.evaluate_host(r'
 globalThis.timerConversionOrder=[];globalThis.stringTimerRan=0;
 const handler={[Symbol.toPrimitive](hint){timerConversionOrder.push(hint);return "globalThis.stringTimerRan++"}};
 const delay={valueOf(){timerConversionOrder.push("number");return 4294967301.75}};
 setTimeout(handler,delay);timerConversionOrder.join(",")==="string,number"&&stringTimerRan===0&&setTimeout.length===1&&setInterval.length===1&&clearTimeout.length===0&&clearInterval.length===0;
')! == 'true'
	mut scope := host.scope
	wait_for_timer_host(fn [scope] () bool { return scope.active_timer_count() == 0 })
	assert runtime.evaluate_host('stringTimerRan===1')! == 'true'
	assert runtime.evaluate_host(r'
 const marker={};let sameHandler=false,sameDelay=false;
 try{setTimeout({[Symbol.toPrimitive](){throw marker}},0)}catch(reason){sameHandler=reason===marker}
 try{setInterval(()=>{},{valueOf(){throw marker}})}catch(reason){sameDelay=reason===marker}
 const invalid=[()=>setTimeout(),()=>setInterval(),()=>setTimeout(Symbol("handler")),()=>setTimeout(()=>{},1n),()=>setTimeout(()=>{},Symbol("delay")),()=>clearTimeout(1n),()=>clearInterval(Symbol("id"))];
 sameHandler&&sameDelay&&invalid.every(operation=>{try{operation();return false}catch(error){return error instanceof TypeError}})
')! == 'true'
}

fn test_native_timer_callback_and_string_script_report_original_engine_reasons_and_current_csp() {
	$if !darwin { return }
	if !platform.native_timer_scheduling_available() { return }
	mut runtime := Runtime.create()
	defer { runtime.close() }
	mut host := TimerHost.create(timer_host_document())!
	host.install(mut runtime)!
	mut scope := host.scope
	actual := runtime.evaluate_host_value('globalThis.nativeTimerReason={toString(){throw "do not coerce timer reason"}};nativeTimerReason')!
	runtime.evaluate_host('setTimeout(()=>{throw nativeTimerReason},5);setTimeout("throw nativeTimerReason",5)')!
	wait_for_timer_host(fn [scope] () bool { return scope.reported_errors().len == 2 })
	for reason in scope.reported_errors() {
		assert runtime.actual_webidl_value(reason.as_webidl_value()!)! == actual
	}
	mut settings := host.settings
	runtime.evaluate_host('globalThis.blockedTimerRan=false;globalThis.blockedTimerID=setTimeout("blockedTimerRan=true",5);globalThis.IntrinsicEvalError=EvalError;globalThis.EvalError=function(){throw "replaced author constructor"}')!
	settings.set_policy_container(&html.PolicyContainer{csp_list: [html.parse_response_csp_policy("script-src 'self'", .enforce, settings.origin())]})
	wait_for_timer_host(fn [scope] () bool { return scope.active_timer_count() == 0 })
	assert runtime.evaluate_host('blockedTimerRan&&blockedTimerID>0')! == 'true'
	assert scope.reported_errors().len == 2
	assert runtime.evaluate_host('setTimeout("blockedTimerRan=false",5)===0&&setInterval("blockedTimerRan=false",5)===0')! == 'true'
	assert scope.active_timer_count() == 0 && scope.reported_errors().len == 2
	settings.set_policy_container(&html.PolicyContainer{csp_list: [html.parse_response_csp_policy("script-src 'self'", .report, settings.origin())]})
	runtime.evaluate_host('setTimeout("blockedTimerRan=true",5)')!
	wait_for_timer_host(fn [scope] () bool { return scope.active_timer_count() == 0 })
	assert runtime.evaluate_host('blockedTimerRan')! == 'true'
}

fn test_native_timer_close_cancels_only_public_handles_preserving_source_abort_timeout() {
	$if !darwin { return }
	if !platform.native_timer_scheduling_available() { return }
	mut runtime := Runtime.create()
	document := timer_host_document()
	mut abort_host := AbortSignalHost.create(document)!
	abort_host.install(mut runtime)!
	mut host := TimerHost.create(document)!
	host.install(mut runtime)!
	actual := runtime.evaluate_host_value('globalThis.afterCloseSignal=AbortSignal.timeout(5);setInterval(()=>{throw "closed callback must not run"},5);afterCloseSignal')!
	native := runtime.native_abort_signal(actual)!
	runtime.close()
	wait_for_timer_host(fn [native] () bool { return native.aborted() })
	assert host.closed && host.scope.active_timer_count() == 0
}
