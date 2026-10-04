@[has_globals]
module bindings

import browserjs
import dom
import libjs
import math

fn test_source_platform_descriptor_actual_same_value_uses_identity_without_author_conversion() {
	$if !darwin {
		return
	}
	mut runtime := browserjs.Runtime.create()
	defer { runtime.close() }
	runtime.evaluate_host('globalThis.sourcePlatformConversions=0;globalThis.sourcePlatformObject={valueOf(){++sourcePlatformConversions;throw "author valueOf"},toString(){++sourcePlatformConversions;throw "author toString"}};globalThis.sourcePlatformOther={};globalThis.sourcePlatformSymbol=Symbol("token");0;')!
	realm := create_a_principal_javascript_realm()
	mut object := PlatformObject.create(realm)
	for source in ['sourcePlatformObject', 'sourcePlatformSymbol', '9007199254740993n', 'NaN',
		'-0', '"native"'] {
		actual := runtime.evaluate_host_value(source)!
		left := dom.js_webidl_value(runtime.webidl_value(actual)!)
		right := dom.js_webidl_value(runtime.webidl_value(actual)!)
		key := property_key(source)
		assert object.define_ordinary_property(key, data_property_descriptor(left, false, false, false))
		assert object.define_ordinary_property(key, data_property_descriptor(right, false, false, false))
	}
	other := dom.js_webidl_value(runtime.webidl_value(runtime.evaluate_host_value('sourcePlatformOther')!)!)
	assert !object.define_ordinary_property(property_key('sourcePlatformObject'), data_property_descriptor(other, false, false, false))
	positive_zero := dom.js_webidl_value(runtime.webidl_value(runtime.evaluate_host_value('0')!)!)
	assert !object.define_ordinary_property(property_key('-0'), data_property_descriptor(positive_zero, false, false, false))
	another_symbol := dom.js_webidl_value(runtime.webidl_value(runtime.evaluate_host_value('Symbol("token")')!)!)
	assert !object.define_ordinary_property(property_key('sourcePlatformSymbol'), data_property_descriptor(another_symbol, false, false, false))
	high := dom.js_webidl_value(runtime.webidl_value(runtime.evaluate_host_value('String.fromCharCode(0xd800)')!)!)
	low := dom.js_webidl_value(runtime.webidl_value(runtime.evaluate_host_value('String.fromCharCode(0xdc00)')!)!)
	assert object.define_ordinary_property(property_key('rawNative'), data_property_descriptor(high, false, false, false))
	assert object.define_ordinary_property(property_key('rawNative'), data_property_descriptor(high, false, false, false))
	assert !object.define_ordinary_property(property_key('rawNative'), data_property_descriptor(low, false, false, false))
	assert runtime.evaluate_host('sourcePlatformConversions')! == '0'
	runtime.evaluate_host('Object.is=function(){throw "author Object.is"}')!
	actual := dom.js_webidl_value(runtime.webidl_value(runtime.evaluate_host_value('sourcePlatformObject')!)!)
	assert object.define_ordinary_property(property_key('sourcePlatformObject'), data_property_descriptor(actual, false, false, false))
	assert runtime.evaluate_host('sourcePlatformConversions')! == '0'
}

fn test_source_platform_descriptor_scalar_same_value_preserves_nan_signed_zero_and_raw_strings() {
	realm := create_a_principal_javascript_realm()
	mut object := PlatformObject.create(realm)
	assert object.define_ordinary_property(property_key('nan'), data_property_descriptor(dom.js_number(math.nan()), false, false, false))
	assert object.define_ordinary_property(property_key('nan'), data_property_descriptor(dom.js_number(math.nan()), false, false, false))
	assert object.define_ordinary_property(property_key('zero'), data_property_descriptor(dom.js_number(0), false, false, false))
	assert !object.define_ordinary_property(property_key('zero'), data_property_descriptor(dom.js_number(-0.0), false, false, false))
	high := dom.js_utf16_string(libjs.utf16_string_from_code_units([u16(0xd800)]))
	low := dom.js_utf16_string(libjs.utf16_string_from_code_units([u16(0xdc00)]))
	assert object.define_ordinary_property(property_key('raw'), data_property_descriptor(high, false, false, false))
	assert object.define_ordinary_property(property_key('raw'), data_property_descriptor(high, false, false, false))
	assert !object.define_ordinary_property(property_key('raw'), data_property_descriptor(low, false, false, false))
}
