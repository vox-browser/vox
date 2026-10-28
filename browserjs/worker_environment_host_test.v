module browserjs

import dom
import html
import loader
import platform

fn worker_environment_fixture(url string, secure bool) &html.WorkerEnvironmentSettingsObject {
	parsed := dom.URL{ value: url }
	mut realm := &html.ScriptingRealm{}
	scope := html.DedicatedWorkerGlobalScope.create(parsed, html.WorkerOptions{}, realm)
	return html.WorkerEnvironmentSettingsObject.setup(&scope.WorkerGlobalScope, mut realm,
		html.SerializedEnvironmentSettingsObject{
			creation_url: parsed
			api_base_url: parsed
			origin:       parsed.origin()
			global:       html.SerializedWorkerGlobalScope{ relevant_settings_object_is_secure_context: secure }
		}, 12)
}

fn test_worker_environment_uses_actual_navigator_and_live_location_without_a_document() {
	environment := worker_environment_fixture('https://worker-info.test:8443/agents/map.js?lang=ru#start', true)
	mut runtime := Runtime.create()
	mut host := WorkerEnvironmentHost.create(environment)!
	host.install(mut runtime)!
	defer { runtime.close() }
	assert environment.settings.responsible_document() == none
	assert runtime.evaluate_host('navigator.userAgent')! == environment.global_scope.navigator().user_agent()
	assert runtime.evaluate_host('navigator.platform')! == environment.global_scope.navigator().platform()
	assert runtime.evaluate_host(r'
 navigator===navigator&&navigator instanceof WorkerNavigator&&Object.prototype.toString.call(navigator)==="[object WorkerNavigator]"&&navigator.hardwareConcurrency>0&&navigator.deviceMemory>=1&&navigator.deviceMemory<=4&&navigator.onLine&&navigator.appName==="Netscape"&&navigator.appCodeName==="Mozilla"&&navigator.product==="Gecko"&&typeof document==="undefined"&&typeof window==="undefined"&&typeof Navigator==="undefined"&&typeof clientInformation==="undefined"&&["vendor","vendorSub","productSub","cookieEnabled","javaEnabled"].every(name=>!(name in navigator)&&!(name in WorkerNavigator.prototype));
 ')! == 'true'
	assert runtime.evaluate_host(r'
 location===location&&location instanceof WorkerLocation&&String(location)==="https://worker-info.test:8443/agents/map.js?lang=ru#start"&&location.href===String(location)&&location.origin==="https://worker-info.test:8443"&&location.protocol==="https:"&&location.host==="worker-info.test:8443"&&location.hostname==="worker-info.test"&&location.port==="8443"&&location.pathname==="/agents/map.js"&&location.search==="?lang=ru"&&location.hash==="#start"&&Object.prototype.toString.call(location)==="[object WorkerLocation]";
 ')! == 'true'
	runtime.evaluate_host('globalThis.savedWorkerLocation=location;globalThis.savedWorkerNavigator=navigator')!
	mut scope := environment.global_scope
	scope.set_url(dom.URL{ value: 'https://redirected-info.test/final.js' })
	assert runtime.evaluate_host('savedWorkerLocation===location&&savedWorkerNavigator===navigator&&String(location)==="https://redirected-info.test/final.js"&&location.host==="redirected-info.test"&&location.port===""&&location.search===""&&location.hash===""')! == 'true'
}

fn test_worker_navigator_languages_are_frozen_and_follow_source_preferences() {
	environment := worker_environment_fixture('https://worker-info.test/languages.js', true)
	mut host := WorkerEnvironmentHost.create(environment)!
	mut runtime := Runtime.create()
	host.install(mut runtime)!
	mut resource_loader := loader.ResourceLoader.the()
	previous := resource_loader.preferred_languages()
	defer {
		resource_loader.set_preferred_languages(previous) or { panic(err) }
		runtime.close()
	}
	resource_loader.set_preferred_languages(['ru-RU', 'en-US'])!
	assert runtime.evaluate_host('navigator.language==="ru-RU"&&navigator.languages.join(",")==="ru-RU,en-US"&&Object.isFrozen(navigator.languages)')! == 'true'
	runtime.evaluate_host('globalThis.workerLanguages=navigator.languages')!
	resource_loader.set_preferred_languages(['de'])!
	assert runtime.evaluate_host('navigator.language==="de"&&navigator.languages.join() === "de"&&workerLanguages.join(",")==="ru-RU,en-US"')! == 'true'
}

fn test_worker_environment_checks_receivers_readonly_metadata_and_secure_context_exposure() {
	environment := worker_environment_fixture('http://worker-info.test/agent.js', false)
	mut runtime := Runtime.create()
	mut host := WorkerEnvironmentHost.create(environment)!
	host.install(mut runtime)!
	defer { runtime.close() }
	assert runtime.evaluate_host(r'
 const desc=Object.getOwnPropertyDescriptor,nav=desc(WorkerNavigator.prototype,"language"),loc=desc(WorkerLocation.prototype,"href"),globalNav=desc(globalThis,"navigator");
 let rejected=0;for(const call of [()=>new WorkerNavigator(),()=>WorkerNavigator(),()=>new WorkerLocation(),()=>WorkerLocation(),()=>nav.get.call({}),()=>loc.get.call({}),()=>WorkerLocation.prototype.toString.call({}),()=>globalNav.get.call({}),()=>{ "use strict";location.href="other" }]){try{call()}catch(error){if(error instanceof TypeError)rejected++}}
 rejected===9&&nav.enumerable&&nav.configurable&&nav.set===undefined&&nav.get.name==="get language"&&nav.get.length===0&&loc.enumerable&&loc.configurable&&loc.set===undefined&&globalNav.enumerable&&globalNav.configurable&&globalNav.set===undefined&&!("deviceMemory" in navigator)&&WorkerLocation.prototype.toString.name==="toString"&&WorkerLocation.prototype.toString.length===0;
 ')! == 'true'
	host.install(mut runtime)!
	assert runtime.evaluate_host('globalThis.navigator===navigator&&location.href==="http://worker-info.test/agent.js"')! == 'true'
}

fn test_worker_environment_rejects_mismatched_owners_and_closes_its_registration() {
	first := worker_environment_fixture('https://worker-info.test/first.js', true)
	second := worker_environment_fixture('https://worker-info.test/second.js', true)
	mut runtime := Runtime.create()
	mut host := WorkerEnvironmentHost.create(first)!
	host.install(mut runtime)!
	mut foreign := WorkerEnvironmentHost.create(second)!
	foreign.install(mut runtime) or {
		assert err.msg().contains('different scripting environment')
		assert runtime.evaluate_host('location.href==="https://worker-info.test/first.js"')! == 'true'
		runtime.close()
		assert host.closed
		assert voidptr(runtime) !in worker_environment_bindings_
		return
	}
	runtime.close()
	assert false, 'worker environment installed with a different owner'
}

fn test_worker_environment_bindings_survive_caller_and_delivery_scratch_resets() {
	environment := worker_environment_fixture('https://worker-info.test/Санкт-Петербург.js?lang=ru#map', true)
	mut runtime := Runtime.create()
	defer { runtime.close() }
	mut caller := platform.begin_thread_scratch('worker environment caller')
	mut host := WorkerEnvironmentHost.create(environment)!
	host.install(mut runtime)!
	runtime.evaluate_host('globalThis.retainedWorkerNavigator=navigator;globalThis.retainedWorkerLocation=location;globalThis.retainedWorkerLanguages=navigator.languages')!
	caller.finish()
	mut delivery := platform.begin_thread_scratch('worker environment delivery')
	assert runtime.evaluate_host('retainedWorkerNavigator===navigator&&retainedWorkerLocation===location&&retainedWorkerLanguages[0]===navigator.language&&Object.isFrozen(retainedWorkerLanguages)&&location.hash==="#map"')! == 'true'
	delivery.finish()
	assert runtime.evaluate_host('String(retainedWorkerLocation)===location.href&&navigator===retainedWorkerNavigator&&navigator.hardwareConcurrency>0')! == 'true'
}
