// SPDX-License-Identifier: BSD-2-Clause
module libjsdom

import dom
import html
import libjs
import loader

fn navigator_fixture() !(&Host, &libjs.VM, &html.Navigator) {
	if !loader.is_initialized() { loader.initialize() }
	address := dom.URL{value: 'https://navigator-native.test/'}
	document := html.parse_navigation_document('<body></body>', address, address.origin(), none)!
	window := unsafe { &html.WindowModel(document.get_window() or { return error('Missing owning Window') }) }
	mut vm := libjs.VM.create()
	libjs.create_simple_execution_context(mut vm)
	return Host.create(vm, vm.realm(), document, Hooks{})!, vm, window.navigator()
}

fn navigator_eval(mut vm libjs.VM, source string) !libjs.Value {
	mut script := libjs.Script.parse(source, vm.realm(), 'navigator-native.js', unsafe { nil })!
	return vm.run_with_limits(mut script, libjs.ExecutionLimits{max_instructions: 10000}) or { return error(exception_message(err)) }
}

fn test_navigator_binds_actual_window_owner_and_native_id_and_system_values() {
	mut host, mut vm, native := navigator_fixture()!
	defer { host.close() }
	assert navigator_eval(mut vm, 'navigator===navigator&&navigator===clientInformation&&navigator instanceof Navigator&&Object.prototype.toString.call(navigator)==="[object Navigator]"&&navigator.appCodeName==="Mozilla"&&navigator.appName==="Netscape"&&navigator.product==="Gecko"&&navigator.vendorSub===""&&navigator.onLine&&navigator.cookieEnabled&&!navigator.webdriver&&!navigator.pdfViewerEnabled&&!navigator.javaEnabled()&&navigator.hardwareConcurrency>0')!.as_bool()
	assert voidptr(host.navigator_native) == voidptr(native)
	for name, value in {'userAgent': native.user_agent(), 'appVersion': native.app_version(), 'platform': native.platform(), 'vendor': native.vendor(), 'productSub': native.product_sub()} {
		assert navigator_eval(mut vm, 'navigator.' + name)!.as_string().str() == value
	}
}

fn test_navigator_languages_follow_native_preferences_and_keep_frozen_prior_values() {
	mut host, mut vm, _ := navigator_fixture()!
	mut resource := loader.ResourceLoader.the()
	previous := resource.preferred_languages()
	defer { host.close(); resource.set_preferred_languages(previous) or { panic(err) } }
	resource.set_preferred_languages(['fr-CA', 'en'])!
	assert navigator_eval(mut vm, 'var before=navigator.languages;navigator.language==="fr-CA"&&before.join(",")==="fr-CA,en"&&Object.isFrozen(before)&&before===navigator.languages')!.as_bool()
	resource.set_preferred_languages(['ja'])!
	assert navigator_eval(mut vm, 'navigator.language==="ja"&&navigator.languages.join(",")==="ja"&&Object.isFrozen(navigator.languages)&&before!==navigator.languages&&before.join(",")==="fr-CA,en"')!.as_bool()
}

fn test_navigator_brand_metadata_replaceable_alias_and_owner_teardown() {
	mut host, mut vm, _ := navigator_fixture()!
	assert navigator_eval(mut vm, 'var native=navigator,d=Object.getOwnPropertyDescriptor(Navigator.prototype,"language"),g=Object.getOwnPropertyDescriptor(window,"navigator"),n=0;for(var call of [()=>new Navigator(),()=>Navigator(),()=>d.get.call({}),()=>Navigator.prototype.javaEnabled.call(Object.create(navigator)),()=>g.get.call({})])try{call()}catch(e){if(e instanceof TypeError)n++}clientInformation=17;n===5&&d.enumerable&&d.configurable&&d.set===undefined&&d.get.name==="get language"&&d.get.length===0&&g.set===undefined&&navigator===native&&clientInformation===17')!.as_bool()
	host.close()
	// The embedding must stop VM entry before Host.close releases its native
	// closure storage. Inspect teardown without entering the retired VM.
	assert host.navigator_object == unsafe { nil } && host.navigator_native == unsafe { nil }
	assert host.navigator_frozen_languages == unsafe { nil } && host.navigator_languages.len == 0
}
