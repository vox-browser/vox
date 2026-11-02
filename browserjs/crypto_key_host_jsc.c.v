// Copyright (c) 2023, stelar7 <dudedbz@gmail.com>
// Copyright (c) 2024, Andrew Kaster <akaster@serenityos.org>
// Copyright (c) 2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause
// CryptoKey.{cpp,idl}: actual wrapper brands and cached algorithm/usages values.
module browserjs

import webcrypto
import webidl


fn (mut host CryptoHost) install_crypto_key() ! {
	mut runtime := unsafe { &Runtime(host.runtime) }
	host.define_data = runtime.evaluate_host_value(r'(function(){const define=Object.defineProperty;return function(object,key,value){define(object,key,{value,writable:true,enumerable:true,configurable:true})}})()')!
	host.freeze_object = runtime.evaluate_host_value('Object.freeze')!
	handle := voidptr(&host)
	get := runtime.make_value_host_function(fn [handle] (_ voidptr, args []voidptr) !voidptr {
		mut host := unsafe { &CryptoHost(handle) }
		return host.crypto_key_get(args) or { return host.exception(err) }
	})!
	installer := runtime.evaluate_host_value(crypto_key_native_bootstrap)!
	defer { runtime.release_javascript_value(installer) }
	prototype := runtime.call_javascript_function(installer, C.vox_jsc_JSValueMakeUndefined(runtime.context), [get])!
	host.prototypes[.key] = runtime.retain_javascript_value(prototype)!
}

fn (mut host CryptoHost) wrap_crypto_key(key &webcrypto.CryptoKey) !voidptr {
	if host.closed { return error('Crypto global has closed') }
	native := voidptr(key)
	if record := host.records[native] { return record.object }
	prototype := host.prototypes[.key] or { return error('CryptoKey is unavailable in this global') }
	mut record := &CryptoHostRecord{ host: host, kind: .key, native: native }
	object := C.JSObjectMake(host.runtime.context, unsafe { nil }, unsafe { nil })
	C.JSObjectSetPrototype(host.runtime.context, object, prototype)
	record.object = host.runtime.retain_javascript_value(object)!
	host.records[native] = record
	host.by_wrapper[object] = record
	return object
}

pub fn (mut runtime Runtime) javascript_crypto_key(key &webcrypto.CryptoKey) !voidptr {
	mut host := crypto_bindings_[voidptr(&runtime)] or { return error('Crypto binding is unavailable') }
	return host.wrap_crypto_key(key)
}

pub fn (runtime &Runtime) native_crypto_key(value voidptr) !&webcrypto.CryptoKey {
	host := crypto_bindings_[voidptr(runtime)] or { return error('Crypto binding is unavailable') }
	record := host.record(value, .key)!
	return unsafe { &webcrypto.CryptoKey(record.native) }
}

fn (mut host CryptoHost) crypto_key_get(args []voidptr) !voidptr {
	name := host.runtime.binding_dom_string(host.argument(args, 0))!
	record := host.record(host.argument(args, 1), .key)!
	key := unsafe { &webcrypto.CryptoKey(record.native) }
	// Each actual native engine global supplies its owning wrapper realm. The
	// typed source cache retains algorithm invalidation and frozen usages IDs.
	realm := u64(voidptr(host.settings.realm())).str()
	match name {
		'type' {
			mut type_name := 'secret'
			if key.bindings_type() == .public_key { type_name = 'public' }
			if key.bindings_type() == .private_key { type_name = 'private' }
			return host.runtime.binding_string(type_name)
		}
		'extractable' { return C.vox_jsc_JSValueMakeBoolean(host.runtime.context, key.extractable) }
		'algorithm' { return host.crypto_value(key.algorithm_for_realm(realm)!) }
		'usages' { return host.crypto_value(key.usages_for_realm(realm)) }
		else { return error('Unknown CryptoKey attribute') }
	}
}

fn (mut host CryptoHost) crypto_object(value webidl.Value) !voidptr {
	if value.opaque_id != 0 {
		if actual := host.object_wrappers[value.opaque_id] { return actual }
	}
	mut runtime := unsafe { &Runtime(host.runtime) }
	mut object := unsafe { nil }
	if value.kind == .sequence {
		mut call_arguments := []voidptr{cap: value.sequence_value.len}
		defer { for argument in call_arguments { runtime.release_javascript_value(argument) }
		 }
		for item in value.sequence_value {
			call_arguments << runtime.retain_javascript_value(host.crypto_value(item)!)!
		}
		mut exception := unsafe { nil }
		object = C.vox_jsc_JSObjectMakeArray(runtime.context, uint(call_arguments.len), call_arguments.data, &exception)
		if exception != unsafe { nil } { return runtime.actual_javascript_exception(exception) }
	} else {
		object = C.JSObjectMake(runtime.context, unsafe { nil }, unsafe { nil })
	}
	runtime.retain_javascript_value(object)!
	defer { if value.opaque_id == 0 { runtime.release_javascript_value(object) } }
	if value.kind == .object {
		for name, property in value.object_value {
			actual := runtime.retain_javascript_value(host.crypto_value(property)!)!
			defer { runtime.release_javascript_value(actual) }
			runtime.call_javascript_function(host.define_data, C.vox_jsc_JSValueMakeUndefined(runtime.context), [
				object,
				runtime.binding_string(name),
				actual,
			])!
		}
	}
	if value.frozen {
		runtime.call_javascript_function(host.freeze_object, C.vox_jsc_JSValueMakeUndefined(runtime.context), [object])!
	}
	if value.opaque_id != 0 { host.object_wrappers[value.opaque_id] = object }
	return object
}

const crypto_key_native_bootstrap = r'(function(get){
 const define=Object.defineProperty,T=TypeError;
 function CryptoKey(){throw new T("Illegal constructor")}
 define(CryptoKey.prototype,Symbol.toStringTag,{value:"CryptoKey",configurable:true});
 for(const name of ["type","extractable","algorithm","usages"]){const getter=function(){return get(name,this)};define(getter,"name",{value:"get "+name,configurable:true});define(CryptoKey.prototype,name,{get:getter,enumerable:true,configurable:true})}
 define(CryptoKey,"prototype",{writable:false});define(globalThis,"CryptoKey",{value:CryptoKey,writable:true,configurable:true});return CryptoKey.prototype;
})'
