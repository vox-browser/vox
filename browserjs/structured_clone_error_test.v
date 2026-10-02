module browserjs

import html
import webidl

fn test_actual_engine_source_error_clone_type_order_and_absent_optional_fields() {
	$if !darwin { return }
	mut runtime := Runtime.create()
	defer { runtime.close() }
	bridge := StructuredCloneBridge.create(runtime)!
	runtime.evaluate_host(r'globalThis.__sourceErrorConstructors=[Error,EvalError,RangeError,ReferenceError,SyntaxError,TypeError,URIError]')!
	for index, source_type in [u8(0), 1, 3, 4, 5, 6, 7] {
		value := runtime.evaluate_host_value('new __sourceErrorConstructors[' + index.str() + ']()')!
		record := bridge.serialize(value, false)!
		assert record.data == [u8(16), source_type, 0, 0]
		cloned := bridge.deserialize(record)!
		binding := '__actualErrorClone' + index.str()
		runtime.define_value_host_function(binding, fn [cloned] (_ voidptr, _ []voidptr) !voidptr { return cloned })!
		assert runtime.evaluate_host('Object.getPrototypeOf(' + binding + '())===__sourceErrorConstructors[' + index.str() + '].prototype&&!Object.hasOwn(' + binding + '(),"message")&&!Object.hasOwn(' + binding + '(),"cause")')! == 'true'
	}
}

fn test_actual_engine_source_error_clone_descriptor_tostring_order_utf16_and_aliases() {
	$if !darwin { return }
	mut runtime := Runtime.create()
	defer { runtime.close() }
	bridge := StructuredCloneBridge.create(runtime)!
	value := runtime.evaluate_host_value(r'globalThis.__errorTrace=[];const value=new Error();Object.defineProperty(value,"name",{get(){__errorTrace.push("name");return "TypeError"}});Object.defineProperty(value,"message",{value:{[Symbol.toPrimitive](hint){__errorTrace.push("message:"+hint);return String.fromCharCode(0xd800)}},configurable:true});Object.defineProperty(value,"cause",{value:{toString(){__errorTrace.push("cause");return "source cause"}},configurable:true});({value,again:value})')!
	for for_storage in [false, true] {
		runtime.evaluate_host('__errorTrace.length=0')!
		record := bridge.serialize(value, for_storage)!
		assert runtime.evaluate_host('__errorTrace.join("|")')! == 'name|message:string|cause'
		cloned := bridge.deserialize(record)!
		binding := '__nativeErrorDescriptorClone' + if for_storage { 'Storage' } else { 'IPC' }
		runtime.define_value_host_function(binding, fn [cloned] (_ voidptr, _ []voidptr) !voidptr { return cloned })!
		assert runtime.evaluate_host('{const result=' + binding + r'(),message=Object.getOwnPropertyDescriptor(result.value,"message"),cause=Object.getOwnPropertyDescriptor(result.value,"cause");result.value===result.again&&result.value instanceof TypeError&&message.value===String.fromCharCode(0xd800)&&cause.value==="source cause"&&message.writable&&!message.enumerable&&message.configurable&&cause.writable&&!cause.enumerable&&cause.configurable}')! == 'true'
	}
}

fn test_actual_engine_source_error_clone_skips_accessor_descriptors_and_uses_captured_constructor() {
	$if !darwin { return }
	mut runtime := Runtime.create()
	defer { runtime.close() }
	bridge := StructuredCloneBridge.create(runtime)!
	value := runtime.evaluate_host_value(r'globalThis.__sourceTypeErrorCtor=TypeError;globalThis.__errorAccessorCalls=0;const value=new TypeError();Object.defineProperty(value,"message",{get(){++__errorAccessorCalls;throw new Error("accessor")}});Object.defineProperty(value,"cause",{get(){++__errorAccessorCalls;throw new Error("accessor")}});globalThis.TypeError=class FakeError {};String.prototype.concat=()=>{throw new Error("overridden")};value')!
	cloned := bridge.clone(value)!
	runtime.define_value_host_function('__capturedErrorClone', fn [cloned] (_ voidptr, _ []voidptr) !voidptr { return cloned })!
	assert runtime.evaluate_host(r'{const value=__capturedErrorClone();value instanceof __sourceTypeErrorCtor&&!Object.hasOwn(value,"message")&&!Object.hasOwn(value,"cause")&&__errorAccessorCalls===0}')! == 'true'
}

fn test_actual_engine_source_error_tostring_propagates_original_abrupt_and_symbol_typeerror() {
	$if !darwin { return }
	mut runtime := Runtime.create()
	defer { runtime.close() }
	bridge := StructuredCloneBridge.create(runtime)!
	value := runtime.evaluate_host_value(r'globalThis.__errorMarker={};const value=new Error();Object.defineProperty(value,"message",{value:{[Symbol.toPrimitive](hint){throw __errorMarker}}});value')!
	marker := runtime.evaluate_host_value('__errorMarker')!
	if _ := bridge.serialize(value, false) { assert false } else {
		assert err is JavaScriptValueException
		if err is JavaScriptValueException { assert err.value == marker }
	}
	symbol := runtime.evaluate_host_value(r'{const value=new Error();Object.defineProperty(value,"message",{value:Symbol("source")});value}')!
	if _ := bridge.serialize(symbol, false) { assert false } else {
		assert err is JavaScriptValueException
		if err is JavaScriptValueException {
			thrown := err.value
			runtime.define_value_host_function('__errorStringThrow', fn [thrown] (_ voidptr, _ []voidptr) !voidptr { return thrown })!
			assert runtime.evaluate_host('__errorStringThrow() instanceof TypeError')! == 'true'
		}
	}
	if _ := bridge.deserialize(html.SerializationRecord{data: [u8(16), 2, 0, 0]}) { assert false } else {
		assert webidl.exception_value(err).dom_exception_?.name() == 'DataCloneError'
	}
}
