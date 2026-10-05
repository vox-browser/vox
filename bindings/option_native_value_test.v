@[has_globals]
module bindings

import browserjs
import dom
import html

fn test_source_option_actual_string_boolean_conversion_order_and_original_exceptions() {
	$if !darwin {
		return
	}
	mut runtime := browserjs.Runtime.create()
	mut document := dom.Document.create(dom.URL{value: 'https://source-native-option.example.test/'})
	defer {
		runtime.close()
		document.finalize()
	}
	constructor := OptionConstructor.create(document)
	runtime.evaluate_host('globalThis.sourceOptionLog=[];globalThis.sourceOptionReason={original:true};')!
	text := dom.js_webidl_value(runtime.webidl_value(runtime.evaluate_host_value('({toString(){sourceOptionLog.push("text");return "native text"}})')!)!)
	value := dom.js_webidl_value(runtime.webidl_value(runtime.evaluate_host_value('({toString(){sourceOptionLog.push("value");return "native value"}})')!)!)
	truthy := dom.js_webidl_value(runtime.webidl_value(runtime.evaluate_host_value('({valueOf(){throw "author boolean conversion"},toString(){throw "author boolean conversion"}})')!)!)
	falsy := dom.js_webidl_value(runtime.webidl_value(runtime.evaluate_host_value('0n')!)!)
	option := constructor.construct(text, value, truthy, falsy)!
	element := unsafe { &dom.Element(option) }
	assert element.as_node().text_content()? == 'native text'
	assert element.get_attribute_value('value') == 'native value'
	assert element.has_attribute('selected')
	assert !html.html_option_element_selected(option)
	assert runtime.evaluate_host('sourceOptionLog.join()')! == 'text,value'
	selected := constructor.construct(none, none, falsy, truthy)!
	assert !unsafe { &dom.Element(selected) }.has_attribute('selected')
	assert html.html_option_element_selected(selected)
	throwing := dom.js_webidl_value(runtime.webidl_value(runtime.evaluate_host_value('({toString(){sourceOptionLog.push("throw");throw sourceOptionReason}})')!)!)
	runtime.define_value_host_function('__sourceOptionTextThrow', fn [constructor, throwing, value, truthy] (_ voidptr, _ []voidptr) !voidptr {
		_ := constructor.construct(throwing, value, truthy, truthy)!
		return unsafe { nil }
	})!
	assert runtime.evaluate_host('{try{__sourceOptionTextThrow();false}catch(reason){reason===sourceOptionReason}}')! == 'true'
	assert runtime.evaluate_host('sourceOptionLog.join()')! == 'text,value,throw'
	runtime.define_value_host_function('__sourceOptionValueThrow', fn [constructor, text, throwing, truthy] (_ voidptr, _ []voidptr) !voidptr {
		_ := constructor.construct(text, throwing, truthy, truthy)!
		return unsafe { nil }
	})!
	assert runtime.evaluate_host('{try{__sourceOptionValueThrow();false}catch(reason){reason===sourceOptionReason}}')! == 'true'
	assert runtime.evaluate_host('sourceOptionLog.join()')! == 'text,value,throw,text,throw'
	symbol := dom.js_webidl_value(runtime.webidl_value(runtime.evaluate_host_value('Symbol("text")')!)!)
	runtime.define_value_host_function('__sourceOptionSymbolText', fn [constructor, symbol] (_ voidptr, _ []voidptr) !voidptr {
		_ := constructor.construct(symbol, none, none, none)!
		return unsafe { nil }
	})!
	runtime.define_value_host_function('__sourceOptionSymbolValue', fn [constructor, symbol] (_ voidptr, _ []voidptr) !voidptr {
		_ := constructor.construct(none, symbol, none, none)!
		return unsafe { nil }
	})!
	assert runtime.evaluate_host('[__sourceOptionSymbolText,__sourceOptionSymbolValue].every(callback=>{try{callback();return false}catch(reason){return reason instanceof TypeError}})')! == 'true'
	for source in ['0n', '""', 'NaN', 'null', 'false'] {
		actual := dom.js_webidl_value(runtime.webidl_value(runtime.evaluate_host_value(source)!)!)
		option_ := constructor.construct(none, none, actual, actual)!
		assert !unsafe { &dom.Element(option_) }.has_attribute('selected')
		assert !html.html_option_element_selected(option_)
	}
	for source in ['1n', 'Symbol("selected")', '[]', '{}'] {
		actual := dom.js_webidl_value(runtime.webidl_value(runtime.evaluate_host_value('(${source})')!)!)
		option_ := constructor.construct(none, none, actual, actual)!
		assert unsafe { &dom.Element(option_) }.has_attribute('selected')
		assert html.html_option_element_selected(option_)
	}
}
