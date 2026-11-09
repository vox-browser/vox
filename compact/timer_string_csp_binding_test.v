module main

import browserjs
import dom
import html
import platform
import time

fn test_native_string_timer_checks_csp_when_installed_and_reports_with_typed_events() {
	url := dom.URL{value:'https://timer-csp.test/'}
	mut document := html.parse_navigation_document('<!doctype html>',url,url.origin(),none)!
	mut runtime := browserjs.Runtime.create()
	defer { runtime.close(); document.finalize() }
	mut host := browserjs.TimerHost.create(document)!
	host.install(mut runtime)!
	runtime.install_window_event_handler_binding()!
	target := runtime.javascript_event_target(unsafe { &dom.EventTarget(document) },none)!
	runtime.define_value_host_function('__documentTarget',fn [target] (_ voidptr, _ []voidptr) !voidptr { return target })!
	mut settings := unsafe { &html.EnvironmentSettingsObject(document.relevant_settings_object()) }
	runtime.evaluate_host('globalThis.timerRan=false;globalThis.events=[];EventTarget.prototype.addEventListener.call(__documentTarget(),"securitypolicyviolation",e=>events.push([e.effectiveDirective,e.blockedURI,e.disposition]));setTimeout("timerRan=true",1)')!
	settings.set_policy_container(&html.PolicyContainer{csp_list:[html.parse_response_csp_policy("script-src 'self'",.enforce,settings.origin())]})
	scope := settings.window_or_worker_global_scope()!
	deadline := time.now().add(time.second)
	for scope.active_timer_count() > 0 && time.now() < deadline { platform.pump_native_events(0.005) }
	assert runtime.evaluate_host('timerRan&&setTimeout("timerRan=false",1)===0&&setInterval("timerRan=false",1)===0')! == 'true'
	mut loop := unsafe { &html.EventLoop(settings.responsible_event_loop()) }
	report_deadline := time.now().add(time.second)
	for time.now() < report_deadline && runtime.evaluate_host("events.length")! != "2" { loop.process();platform.pump_native_events(0.005) }
	assert runtime.evaluate_host('events.length===2&&events.every(e=>e.join()=== "script-src,eval,enforce")')! == 'true', runtime.evaluate_host('JSON.stringify(events)')!
}

fn test_cross_realm_string_timer_uses_the_actual_receiver_global() {
	url := dom.URL{value:'https://cross-timer.test/'}
	mut blocked_document := html.parse_navigation_document('<!doctype html>',url,url.origin(),none)!
	mut allowed_document := html.parse_navigation_document('<!doctype html>',url,url.origin(),none)!
	mut blocked_runtime := browserjs.Runtime.create()
	mut allowed_runtime := browserjs.Runtime.create()
	defer { blocked_runtime.close();allowed_runtime.close();blocked_document.finalize();allowed_document.finalize() }
	mut blocked_host := browserjs.TimerHost.create(blocked_document)!
	mut allowed_host := browserjs.TimerHost.create(allowed_document)!
	blocked_host.install(mut blocked_runtime)!
	allowed_host.install(mut allowed_runtime)!
	blocked_runtime.install_window_event_handler_binding()!
	allowed_runtime.install_window_event_handler_binding()!
	mut settings := unsafe { &html.EnvironmentSettingsObject(blocked_document.relevant_settings_object()) }
	settings.set_policy_container(&html.PolicyContainer{csp_list:[html.parse_response_csp_policy("script-src 'self'",.enforce,settings.origin())]})
	global := allowed_runtime.evaluate_host_value('globalThis')!
	timer := allowed_runtime.evaluate_host_value('setTimeout')!
	blocked_runtime.define_value_host_function('__allowedGlobal',fn [global] (_ voidptr, _ []voidptr) !voidptr { return global })!
	blocked_runtime.define_value_host_function('__allowedTimer',fn [timer] (_ voidptr, _ []voidptr) !voidptr { return timer })!
	assert blocked_runtime.evaluate_host('setTimeout.call(__allowedGlobal(),"globalThis.crossTimer=true",1)>0&&__allowedTimer().call(globalThis,"globalThis.crossTimer=true",1)===0')! == 'true'
	allowed_settings := unsafe { &html.EnvironmentSettingsObject(allowed_document.relevant_settings_object()) }
	scope := allowed_settings.window_or_worker_global_scope()!
	deadline := time.now().add(time.second)
	for scope.active_timer_count()>0 && time.now()<deadline { platform.pump_native_events(0.005) }
	assert allowed_runtime.evaluate_host('globalThis.crossTimer===true')! == 'true'
	assert blocked_runtime.evaluate_host('globalThis.crossTimer!==true')! == 'true'
}
