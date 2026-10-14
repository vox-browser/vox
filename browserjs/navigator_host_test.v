module browserjs

import dom
import html
import loader

fn navigator_host_fixture() !(&Runtime, &dom.Document, &NavigatorHost) {
	if !loader.is_initialized() { loader.initialize() }
	document := html.parse_navigation_document('<!doctype html><body></body>', dom.URL{
		value: 'https://navigator-host.test/'
	}, dom.URL{
		value: 'https://navigator-host.test/'
	}.origin(), none)!
	mut runtime := Runtime.create()
	mut host := NavigatorHost.create(document)!
	host.install(mut runtime)!
	return runtime, document, host
}

fn test_native_navigator_languages_follow_the_owning_source_preferences_and_are_frozen() {
	$if !darwin { return }
	mut runtime, mut document, _ := navigator_host_fixture()!
	mut resource_loader := loader.ResourceLoader.the()
	previous := resource_loader.preferred_languages()
	defer {
		resource_loader.set_preferred_languages(previous) or { panic(err) }
		runtime.close()
		document.finalize()
	}
	resource_loader.set_preferred_languages(['fr-CA', 'en'])!
	assert runtime.evaluate_host('navigator.language==="fr-CA"&&navigator.languages.join(",")==="fr-CA,en"&&Object.isFrozen(navigator.languages)')! == 'true'
	runtime.evaluate_host('globalThis.oldLanguages=navigator.languages')!
	resource_loader.set_preferred_languages(['ja'])!
	assert runtime.evaluate_host('navigator.language==="ja"&&navigator.languages.join(",")==="ja"&&oldLanguages.join(",")==="fr-CA,en"')! == 'true'
}

fn test_native_navigator_exposes_actual_owner_id_and_system_values() {
	$if !darwin { return }
	mut runtime, mut document, host := navigator_host_fixture()!
	defer {
		runtime.close()
		document.finalize()
	}
	window := document.get_window() or { panic('missing Window') }
	actual_window := unsafe { &html.WindowModel(window) }
	assert voidptr(host.navigator) == voidptr(actual_window.navigator())
	assert runtime.evaluate_host('navigator.userAgent')! == host.navigator.user_agent()
	assert runtime.evaluate_host('navigator.platform')! == host.navigator.platform()
	assert runtime.evaluate_host('navigator.vendor')! == host.navigator.vendor()
	assert runtime.evaluate_host('navigator.appVersion')! == host.navigator.app_version()
	assert runtime.evaluate_host('navigator.appName==="Netscape"&&navigator.appCodeName==="Mozilla"&&navigator.product==="Gecko"&&navigator.vendorSub===""&&navigator.onLine&&navigator.cookieEnabled&&!navigator.webdriver&&!navigator.pdfViewerEnabled&&!navigator.javaEnabled()&&navigator.hardwareConcurrency>0')! == 'true'
}

fn test_native_navigator_readonly_getters_brand_checks_and_legacy_alias() {
	$if !darwin { return }
	mut runtime, mut document, mut host := navigator_host_fixture()!
	defer {
		runtime.close()
		document.finalize()
	}
	assert runtime.evaluate_host(r'
 const nativeNavigator=navigator,attribute=Object.getOwnPropertyDescriptor(Navigator.prototype,"language"),globalAttribute=Object.getOwnPropertyDescriptor(this,"navigator");
 let rejected=0;for(const call of [()=>new Navigator(),()=>Navigator(),()=>attribute.get.call({}),()=>Navigator.prototype.javaEnabled.call({}),()=>globalAttribute.get.call({})]){try{call()}catch(error){if(error instanceof TypeError)rejected++}}
 const metadata=attribute.enumerable&&attribute.configurable&&attribute.set===undefined&&attribute.get.name==="get language"&&attribute.get.length===0&&globalAttribute.set===undefined;
 const originalAlias=clientInformation===nativeNavigator;clientInformation=17;
 rejected===5&&metadata&&originalAlias&&clientInformation===17&&navigator===nativeNavigator&&navigator instanceof Navigator&&Object.prototype.toString.call(navigator)==="[object Navigator]";
 ')! == 'true'
	host.install(mut runtime)!
	assert runtime.evaluate_host('clientInformation===17&&navigator===nativeNavigator')! == 'true'
}
