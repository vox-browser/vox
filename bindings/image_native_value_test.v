@[has_globals]
module bindings

import browserjs
import dom

fn test_source_image_actual_number_conversion_order_modulo_and_original_exception() {
	$if !darwin {
		return
	}
	mut runtime := browserjs.Runtime.create()
	mut document := dom.Document.create(dom.URL{value: 'https://source-native-image.example.test/'})
	defer {
		runtime.close()
		document.finalize()
	}
	constructor := ImageConstructor.create(document)
	runtime.evaluate_host('globalThis.sourceImageLog=[];globalThis.sourceImageReason={original:true};')!
	width := dom.js_webidl_value(runtime.webidl_value(runtime.evaluate_host_value('({valueOf(){sourceImageLog.push("width");return 4294967297.8}})')!)!)
	height := dom.js_webidl_value(runtime.webidl_value(runtime.evaluate_host_value('({valueOf(){sourceImageLog.push("height");return -1}})')!)!)
	image := constructor.construct(width, height)!
	element := unsafe { &dom.Element(image) }
	assert element.get_attribute_value('width') == '1'
	assert element.get_attribute_value('height') == '4294967295'
	assert runtime.evaluate_host('sourceImageLog.join()')! == 'width,height'
	for source in ['NaN', 'Infinity', '-Infinity', '-0', '"0x10"', '" 24 "', '"invalid"'] {
		value := dom.js_webidl_value(runtime.webidl_value(runtime.evaluate_host_value(source)!)!)
		actual := constructor.construct(value, none)!
		assert unsafe { &dom.Element(actual) }.get_attribute_value('width') == match source {
			'"0x10"' { '16' }
			'" 24 "' { '24' }
			else { '0' }
		}
	}
	throwing := dom.js_webidl_value(runtime.webidl_value(runtime.evaluate_host_value('({valueOf(){sourceImageLog.push("throw");throw sourceImageReason}})')!)!)
	runtime.define_value_host_function('__sourceImageConstruct', fn [constructor, throwing, height] (_ voidptr, _ []voidptr) !voidptr {
		_ := constructor.construct(throwing, height)!
		return unsafe { nil }
	})!
	assert runtime.evaluate_host('{try{__sourceImageConstruct();false}catch(reason){reason===sourceImageReason}}')! == 'true'
	assert runtime.evaluate_host('sourceImageLog.join()')! == 'width,height,throw'
	for source in ['1n', 'Symbol("dimension")'] {
		value := dom.js_webidl_value(runtime.webidl_value(runtime.evaluate_host_value(source)!)!)
		runtime.define_value_host_function('__sourceImageTypeError', fn [constructor, value] (_ voidptr, _ []voidptr) !voidptr {
			_ := constructor.construct(value, none)!
			return unsafe { nil }
		})!
		assert runtime.evaluate_host('{try{__sourceImageTypeError();false}catch(reason){reason instanceof TypeError}}')! == 'true'
	}
}
