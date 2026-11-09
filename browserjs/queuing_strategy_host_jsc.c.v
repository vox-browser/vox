// Copyright (c) 2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause
// CountQueuingStrategy.cpp, ByteLengthQueuingStrategy.cpp and generated IDL:
// actual native records, owning-global builtin size identity and GetV values.
@[has_globals]
module browserjs

import streams
import webidl


__global queuing_strategy_bindings_ = map[voidptr]&QueuingStrategyHost{}

pub fn (mut host QueuingStrategyHost) install(mut runtime Runtime) ! {
	runtime.require_javascript_value_context()!
	runtime.bind_scripting_environment(host.settings)!
	owner_handle := voidptr(&runtime)
	if existing := queuing_strategy_bindings_[owner_handle] {
		if voidptr(existing) == voidptr(&host) { return }
		return error('Queuing strategy binding already belongs to this runtime')
	}
	host.runtime = &runtime
	// An actual engine GetV preserves primitive receivers and original getter
	// completions; JSObjectGetProperty on a boxed primitive changes `this`.
	host.byte_length_get_v_ = runtime.evaluate_host_value(r'(function(chunk){return chunk.byteLength})')!
	host_handle := voidptr(&host)
	create := runtime.make_value_host_function(fn [host_handle] (_ voidptr, args []voidptr) !voidptr {
		mut host := unsafe { &QueuingStrategyHost(host_handle) }
		return host.construct(args) or { return host.runtime.actual_javascript_exception(host.runtime.binding_exception_value(err)) }
	})!
	operate := runtime.make_value_host_function(fn [host_handle] (_ voidptr, args []voidptr) !voidptr {
		mut host := unsafe { &QueuingStrategyHost(host_handle) }
		return host.operate(args) or { return host.runtime.actual_javascript_exception(host.runtime.binding_exception_value(err)) }
	})!
	installer := runtime.evaluate_host_value(queuing_strategy_native_bootstrap)!
	defer { runtime.release_javascript_value(installer) }
	prototypes := runtime.call_javascript_function(installer, C.vox_jsc_JSValueMakeUndefined(runtime.context), [create, operate])!
	runtime.retain_javascript_value(prototypes)!
	defer { runtime.release_javascript_value(prototypes) }
	for index, kind in [QueuingStrategyHostKind.count, .byte_length] {
		mut exception := unsafe { nil }
		prototype := C.vox_jsc_JSObjectGetPropertyAtIndex(runtime.context, prototypes, u32(index), &exception)
		if exception != unsafe { nil } { return runtime.actual_javascript_exception(exception) }
		host.prototypes[kind] = runtime.retain_javascript_value(prototype)!
	}
	host.scope.install_queuing_strategy_function_creator(fn [host_handle] (byte_length bool) !&webidl.CallbackType {
		mut host := unsafe { &QueuingStrategyHost(host_handle) }
		if host.closed { return error('Queuing strategy binding is closed') }
		actual := host.runtime.make_native_value_host_function('size', if byte_length { 1 } else { 0 }, fn [host_handle, byte_length] (_ voidptr, arguments []voidptr) !voidptr {
			mut host := unsafe { &QueuingStrategyHost(host_handle) }
			if host.closed { return error('Queuing strategy binding is closed') }
			// HTML/WindowOrWorkerGlobalScope.cpp builtin steps: Return 1, or
			// Return ? GetV(chunk, "byteLength"). Neither coerces the result.
			if !byte_length { return C.vox_jsc_JSValueMakeNumber(host.runtime.context, 1) }
			return host.runtime.call_javascript_function(host.byte_length_get_v_, C.vox_jsc_JSValueMakeUndefined(host.runtime.context), [host.argument(arguments, 0)])!
		})!
		callback := &webidl.CallbackType{...host.runtime.webidl_callback(actual, fn [host_handle] (value webidl.Value) !voidptr {
			mut host := unsafe { &QueuingStrategyHost(host_handle) }
			return host.value(value)
		})!}
		host.functions[voidptr(callback)] = actual
		return callback
	})!
	register_runtime_binding(mut queuing_strategy_bindings_, owner_handle, &host)
	runtime.add_close_handler(fn [host_handle, owner_handle] () {
		mut host := unsafe { &QueuingStrategyHost(host_handle) }
		host.close()
		unregister_runtime_binding(mut queuing_strategy_bindings_, owner_handle)
	})
}

fn (host &QueuingStrategyHost) argument(args []voidptr, index int) voidptr {
	if index < args.len { return args[index] }
	return C.vox_jsc_JSValueMakeUndefined(host.runtime.context)
}

fn (mut host QueuingStrategyHost) value(value webidl.Value) !voidptr {
	if host.closed { return error('Queuing strategy binding is closed') }
	if value.kind == .runtime_value { return host.runtime.actual_webidl_value(value) }
	return match value.kind {
		.undefined { C.vox_jsc_JSValueMakeUndefined(host.runtime.context) }
		.null_ { C.vox_jsc_JSValueMakeNull(host.runtime.context) }
		.boolean { C.vox_jsc_JSValueMakeBoolean(host.runtime.context, value.boolean_value) }
		.number { C.vox_jsc_JSValueMakeNumber(host.runtime.context, value.number_value) }
		.string_ { host.runtime.binding_string(value.string_value) }
		else { return error('Queuing strategy callback requires an actual engine value') }
	}
}

fn (mut host QueuingStrategyHost) construct(args []voidptr) !voidptr {
	if host.closed { return error('Queuing strategy binding is closed') }
	kind := if C.JSValueToBoolean(host.runtime.context, host.argument(args, 0)) { QueuingStrategyHostKind.byte_length } else { QueuingStrategyHostKind.count }
	argc := webidl.value_to_number(host.runtime.webidl_value(host.argument(args, 1))!)!
	if argc < 1 { return error('TypeError: Queuing strategy requires an init dictionary') }
	init := host.argument(args, 2)
	if C.JSValueIsUndefined(host.runtime.context, init) || C.JSValueIsNull(host.runtime.context, init) {
		return error('TypeError: Queuing strategy highWaterMark is required')
	}
	if !C.JSValueIsObject(host.runtime.context, init) { return error('TypeError: Queuing strategy init must be a dictionary') }
	actual_hwm := host.runtime.binding_property(init, 'highWaterMark')!
	if C.JSValueIsUndefined(host.runtime.context, actual_hwm) { return error('TypeError: Queuing strategy highWaterMark is required') }
	hwm := webidl.value_to_number(host.runtime.webidl_value(actual_hwm)!)!
	// Unlike ExtractHighWaterMark, the constructor stores unrestricted double
	// directly, including negative, NaN and infinite values.
	mut native := unsafe { nil }
	if kind == .count {
		native = voidptr(streams.CountQueuingStrategy.create_for_constructor(streams.QueuingStrategyInit{high_water_mark: hwm}))
	} else {
		native = voidptr(streams.ByteLengthQueuingStrategy.create_for_constructor(streams.QueuingStrategyInit{high_water_mark: hwm}))
	}
	mut record := &QueuingStrategyHostRecord{host: host, kind: kind, native: native}
	object := host.runtime.make_native_stream_wrapper(record)!
	mut prototype := host.prototypes[kind] or { return error('Queuing strategy prototype is missing') }
	desired := host.argument(args, 3)
	if C.JSValueIsObject(host.runtime.context, desired) { prototype = desired }
	C.JSObjectSetPrototype(host.runtime.context, object, prototype)
	record.object = object
	host.records[native] = record
	return object
}

fn (host &QueuingStrategyHost) record(value voidptr, kind QueuingStrategyHostKind) !&QueuingStrategyHostRecord {
	if host.closed { return error('Queuing strategy binding is closed') }
	data := host.runtime.native_stream_wrapper_record(value)
	if data == unsafe { nil } { return error('TypeError: Illegal queuing strategy interface receiver') }
	record := unsafe { &QueuingStrategyHostRecord(data) }
	if voidptr(record.host) != voidptr(host) || record.kind != kind { return error('TypeError: Illegal queuing strategy interface receiver') }
	return record
}

fn (mut host QueuingStrategyHost) operate(args []voidptr) !voidptr {
	if host.closed { return error('Queuing strategy binding is closed') }
	kind := if C.JSValueToBoolean(host.runtime.context, host.argument(args, 1)) { QueuingStrategyHostKind.byte_length } else { QueuingStrategyHostKind.count }
	record := host.record(host.argument(args, 0), kind)!
	if C.JSValueToBoolean(host.runtime.context, host.argument(args, 2)) {
		mut global := host.scope
		callback := if kind == .count { unsafe { &streams.CountQueuingStrategy(record.native) }.size_callback(mut global)! }
			else { unsafe { &streams.ByteLengthQueuingStrategy(record.native) }.size_callback(mut global)! }
		return host.functions[voidptr(callback)] or { return error('Queuing strategy builtin has no actual engine function') }
	}
	hwm := if kind == .count { unsafe { &streams.CountQueuingStrategy(record.native) }.high_water_mark() }
		else { unsafe { &streams.ByteLengthQueuingStrategy(record.native) }.high_water_mark() }
	return C.vox_jsc_JSValueMakeNumber(host.runtime.context, hwm)
}

const queuing_strategy_native_bootstrap = r'(function(create,operate){
 const define=Object.defineProperty,Type=TypeError,ConstructProxy=Proxy;
 const CountQueuingStrategy=new ConstructProxy(function CountQueuingStrategy(init){throw new Type("CountQueuingStrategy requires new")},{construct(target,args,newTarget){const prototype=newTarget.prototype;return create(false,args.length,args[0],prototype)}});
 const ByteLengthQueuingStrategy=new ConstructProxy(function ByteLengthQueuingStrategy(init){throw new Type("ByteLengthQueuingStrategy requires new")},{construct(target,args,newTarget){const prototype=newTarget.prototype;return create(true,args.length,args[0],prototype)}});
 for(const [Constructor,name,bytes] of [[CountQueuingStrategy,"CountQueuingStrategy",false],[ByteLengthQueuingStrategy,"ByteLengthQueuingStrategy",true]]){
  define(Constructor,"prototype",{writable:false});
  define(Constructor.prototype,"constructor",{value:Constructor,writable:true,configurable:true});
  define(Constructor.prototype,"highWaterMark",{enumerable:true,configurable:true,get(){return operate(this,bytes,false)}});
  define(Constructor.prototype,"size",{enumerable:true,configurable:true,get(){return operate(this,bytes,true)}});
  define(Constructor.prototype,Symbol.toStringTag,{value:name,configurable:true});
  define(globalThis,name,{value:Constructor,writable:true,configurable:true})
 }
 return [CountQueuingStrategy.prototype,ByteLengthQueuingStrategy.prototype]
})'
