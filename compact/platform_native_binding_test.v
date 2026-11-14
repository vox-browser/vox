module main

import browserjs
import dom
import html
import loader
import webidl

fn platform_navigator_fixture() !(&browserjs.Runtime, &dom.Document, &browserjs.NavigatorHost) {
	if !loader.is_initialized() { loader.initialize() }
	document := html.parse_navigation_document('<!doctype html><body></body>', dom.URL{
		value: 'https://navigator-host.test/'
	}, dom.URL{
		value: 'https://navigator-host.test/'
	}.origin(), none)!
	mut runtime := browserjs.Runtime.create()
	mut host := browserjs.NavigatorHost.create(document)!
	host.install(mut runtime)!
	return runtime, document, host
}

fn test_native_navigator_languages_follow_the_owning_source_preferences_and_are_frozen() {
	$if !darwin {
		return
	}
	mut runtime, mut document, _ := platform_navigator_fixture()!
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

fn test_native_navigator_readonly_getters_brand_checks_and_legacy_alias() {
	$if !darwin {
		return
	}
	mut runtime, mut document, mut host := platform_navigator_fixture()!
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

fn test_navigator_native_getters_preserve_same_object_languages_and_cross_realm_branding() {
	$if !darwin {
		return
	}
	mut runtime, mut document, _ := platform_navigator_fixture()!
	mut other, mut other_document, _ := platform_navigator_fixture()!
	defer {
		other.close()
		runtime.close()
		other_document.finalize()
		document.finalize()
	}
	getter := runtime.evaluate_host_value('Object.getOwnPropertyDescriptor(Navigator.prototype,"userAgent").get')!
	navigator := other.evaluate_host_value('navigator')!
	actual := runtime.call_javascript_function(getter, navigator, [])!
	runtime.define_value_host_function('__borrowedUserAgent', fn [actual] (_ voidptr, _ []voidptr) !voidptr {
		return actual
	})!
	assert runtime.evaluate_host('__borrowedUserAgent()===navigator.userAgent')! == 'true'
	assert runtime.evaluate_host(r'
 const getter=Object.getOwnPropertyDescriptor(Navigator.prototype,"userAgent").get;
 let bad=false,nativeStack=false;
 try{getter.call(new Proxy(navigator,{}))}catch(error){bad=error instanceof TypeError;nativeStack=error.stack.startsWith("userAgent@[native code]\n")&&!error.stack.split("\n").some(line=>line==="@"||line.startsWith("check@"));}
 navigator.languages===navigator.languages&&bad&&nativeStack&&String(getter)==="function userAgent() {\n    [native code]\n}"&&getter.name==="get userAgent";
 ')! == 'true'
}

fn test_native_simple_exception_conversion_reuses_one_actual_engine_error_value() {
	$if !darwin {
		return
	}
	mut runtime := browserjs.Runtime.create()
	defer { runtime.close() }
	for type_ in [webidl.SimpleExceptionType.range_error, .type_error, .eval_error, .reference_error,
		.uri_error] {
		native := &webidl.SimpleException{ type_: type_, message: 'source completion message' }
		value := webidl.simple_exception_value_for_record(native)
		actual := runtime.javascript_simple_exception(value)!
		assert actual == runtime.javascript_simple_exception(value)!
		other := runtime.javascript_simple_exception(webidl.simple_exception_value(webidl.SimpleException{ type_: type_, message: native.message }))!
		assert actual != other
		function_name := '__sourceSimple' + native.name()
		runtime.define_value_host_function(function_name, fn [actual] (_ voidptr, _ []voidptr) !voidptr {
			return actual
		})!
		assert runtime.evaluate_host(function_name + '().name')! == native.name()
		assert runtime.evaluate_host(function_name + '() instanceof ' + native.name() + '&&' + function_name + '().message==="source completion message"')! == 'true'
	}
	runtime.evaluate_host('globalThis.actualRangeError=RangeError;globalThis.RangeError=function(){throw "author constructor"}')!
	actual := runtime.javascript_simple_exception(webidl.simple_exception_value(webidl.SimpleException{ type_: .range_error, message: 'captured intrinsic' }))!
	runtime.define_value_host_function('__sourceActualRangeError', fn [actual] (_ voidptr, _ []voidptr) !voidptr {
		return actual
	})!
	assert runtime.evaluate_host('__sourceActualRangeError() instanceof actualRangeError')! == 'true'
	completion := webidl.simple_exception_value(webidl.SimpleException{ type_: .range_error, message: 'source thrown completion' })
	thrown := runtime.javascript_simple_exception(completion)!
	runtime.define_value_host_function('__sourceRangeThrow', fn [completion] (_ voidptr, _ []voidptr) !voidptr {
		return webidl.throw_value(completion)
	})!
	runtime.define_value_host_function('__sourceRangeThrownObject', fn [thrown] (_ voidptr, _ []voidptr) !voidptr {
		return thrown
	})!
	assert runtime.evaluate_host('let caught;try{__sourceRangeThrow()}catch(error){caught=error}caught===__sourceRangeThrownObject()&&caught instanceof actualRangeError')! == 'true'
	runtime.close()
	if _ := runtime.javascript_simple_exception(webidl.simple_exception_value(webidl.SimpleException{ type_: .range_error })) {
		assert false
	} else {
		assert err.msg().contains('closed')
	}
}

fn test_native_platform_exception_stack_has_no_javascript_factory_frame() {
	$if !darwin {
		return
	}
	mut runtime := browserjs.Runtime.create()
	defer { runtime.close() }
	runtime.define_value_host_function('__platformFailure', fn (_ voidptr, _ []voidptr) !voidptr {
		return webidl.throw_value(webidl.simple_exception_value(webidl.SimpleException{ type_: .type_error, message: 'platform failure' }))
	})!
	assert runtime.evaluate_host(r'
 (function authorCallSite(){try{__platformFailure()}catch(error){return error instanceof TypeError&&error.stack.includes("authorCallSite@")&&!error.stack.split("\n").some(line=>line==="@");}})()
 ')! == 'true'
}
