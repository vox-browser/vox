// SPDX-License-Identifier: BSD-2-Clause
// Crypto.{cpp,idl} generated binding using actual engine views and wrapper brands.
@[has_globals]
module browserjs

import webcrypto
import webidl


#include "crypto_views_darwin.h"

fn C.JSObjectMake(context voidptr, object_class voidptr, data voidptr) voidptr
fn C.vox_crypto_integer_view_kind(context voidptr, value voidptr, exception &voidptr) int
fn C.JSContextGetGlobalObject(context voidptr) voidptr
fn C.JSValueToBoolean(context voidptr, value voidptr) bool
fn C.JSObjectGetArrayBufferByteLength(context voidptr, object voidptr, exception &voidptr) uint

__global crypto_bindings_ = map[voidptr]&CryptoHost{}

pub fn (mut host CryptoHost) install(mut runtime Runtime) ! {
	runtime.require_javascript_value_context()!
	runtime.bind_scripting_environment(host.settings)!
	owner := voidptr(&runtime)
	if installed := crypto_bindings_[owner] {
		if voidptr(installed.service) == voidptr(host.service) { return }
		return error('Crypto binding already belongs to another global')
	}
	runtime.install_quota_exceeded_error_binding()!
	host.runtime = &runtime
	handle := voidptr(&host)
	operate := runtime.make_value_host_function(fn [handle] (_ voidptr, args []voidptr) !voidptr {
		mut host := unsafe { &CryptoHost(handle) }
		return host.operate(args) or { return host.exception(err) }
	})!
	host.array_is_view = runtime.evaluate_host_value('ArrayBuffer.isView')!
	host.view_validation = runtime.evaluate_host_value(r'(function(){const apply=Reflect.apply,get=Object.getOwnPropertyDescriptor,tp=Object.getPrototypeOf(Int8Array.prototype),tb=get(tp,"buffer").get,tag=get(tp,Symbol.toStringTag).get,db=get(DataView.prototype,"buffer").get,r=get(ArrayBuffer.prototype,"resizable"),shared=typeof SharedArrayBuffer==="function"?get(SharedArrayBuffer.prototype,"byteLength").get:null;return function(view){let buffer;try{buffer=apply(tb,view,[])}catch(error){buffer=apply(db,view,[])}if(shared){try{apply(shared,buffer,[]);return "The array buffer object cannot be a SharedArrayBuffer"}catch(error){}}if(r&&apply(r.get,buffer,[]))return "Not an object of type fixed-length "+(apply(tag,view,[])||"DataView");return ""}})()')!
	host.typed_array_witness = runtime.evaluate_host_value('(function(){const apply=Reflect.apply,values=Int8Array.prototype.values;return function(view){return apply(values,view,[])}})()')!
	installer := runtime.evaluate_host_value(crypto_native_bootstrap)!
	defer { runtime.release_javascript_value(installer) }
	prototypes := runtime.call_javascript_function(installer, C.JSValueMakeUndefined(runtime.context), [
		operate,
		C.JSValueMakeBoolean(runtime.context, host.settings.is_secure_context()),
	])!
	runtime.retain_javascript_value(prototypes)!
	defer { runtime.release_javascript_value(prototypes) }
	for index, kind in [CryptoHostKind.crypto, .subtle] {
		mut exception := unsafe { nil }
		prototype := C.JSObjectGetPropertyAtIndex(runtime.context, prototypes, u32(index), &exception)
		if exception != unsafe { nil } { return runtime.actual_javascript_exception(exception) }
		host.prototypes[kind] = runtime.retain_javascript_value(prototype)!
	}
	if host.settings.is_secure_context() {
		host.install_digest()!
		host.install_crypto_key()!
		host.install_generate_key()!
		host.install_export_key()!
		host.install_import_key()!
		host.install_cipher_operations()!
		host.install_signature_operations()!
		host.install_derivation_operations()!
		host.install_wrapping_operations()!
		host.install_kem_operations()!
	}
	crypto_bindings_[owner] = &host
	runtime.add_close_handler(fn [handle, owner] () {
		mut host := unsafe { &CryptoHost(handle) }
		host.close()
		crypto_bindings_.delete(owner)
	})
}

fn (host &CryptoHost) exception(reason IError) IError {
	if reason is JavaScriptValueException { return reason }
	mut runtime := unsafe { &Runtime(host.runtime) }
	message := reason.msg()
	separator := message.index(':') or { return runtime.actual_javascript_exception(runtime.binding_exception_value(reason)) }
	name := message[..separator]
	text := message[separator + 1..].trim_left(' ')
	if name == 'QuotaExceededError' {
		native := webidl.QuotaExceededError.create(text)
		return runtime.actual_javascript_exception(runtime.javascript_quota_exceeded_error(&native) or { return err })
	}
	if name in ['TypeMismatchError', 'InvalidStateError', 'OperationError', 'NotSupportedError',
		'InvalidAccessError', 'DataError', 'SyntaxError'] {
		return runtime.actual_javascript_exception(runtime.javascript_dom_exception(webidl.dom_exception_value(webidl.DOMException.create(name, text))) or { return err })
	}
	return runtime.actual_javascript_exception(runtime.binding_exception_value(reason))
}

fn (mut host CryptoHost) wrap(kind CryptoHostKind) !voidptr {
	mut native := voidptr(host.service.crypto())
	if kind == .subtle { native = voidptr(host.service.crypto().subtle()) }
	if record := host.records[native] { return record.object }
	mut record := &CryptoHostRecord{ host: host, kind: kind, native: native }
	object := C.JSObjectMake(host.runtime.context, unsafe { nil }, unsafe { nil })
	C.JSObjectSetPrototype(host.runtime.context, object, host.prototypes[kind] or { return error('Crypto prototype unavailable') })
	record.object = host.runtime.retain_javascript_value(object)!
	host.records[native] = record
	host.by_wrapper[object] = record
	return object
}

fn (host &CryptoHost) record(value voidptr, kind CryptoHostKind) !&CryptoHostRecord {
	if host.closed { return error('Crypto global has closed') }
	interface_name := match kind { .subtle { 'SubtleCrypto' } .key { 'CryptoKey' } .crypto { 'Crypto' } }
	record := host.by_wrapper[value] or {
		return error('TypeError: Not an object of type ${interface_name}')
	}
	if voidptr(record.host) != voidptr(host) || record.kind != kind {
		return error('TypeError: Not an object of type ${interface_name}')
	}
	return record
}

pub fn (runtime &Runtime) native_crypto(value voidptr) !&webcrypto.Crypto {
	host := crypto_bindings_[voidptr(runtime)] or { return error('Crypto binding is unavailable') }
	record := host.record(value, .crypto)!
	return unsafe { &webcrypto.Crypto(record.native) }
}

pub fn (runtime &Runtime) native_subtle_crypto(value voidptr) !&webcrypto.SubtleCrypto {
	host := crypto_bindings_[voidptr(runtime)] or { return error('Crypto binding is unavailable') }
	record := host.record(value, .subtle)!
	return unsafe { &webcrypto.SubtleCrypto(record.native) }
}

fn (host &CryptoHost) argument(args []voidptr, index int) voidptr {
	if index < args.len { return args[index] }
	return C.JSValueMakeUndefined(host.runtime.context)
}

fn (mut host CryptoHost) operate(args []voidptr) !voidptr {
	if host.closed { return error('Crypto global has closed') }
	op := host.runtime.binding_dom_string(host.argument(args, 0))!
	receiver := host.argument(args, 1)
	if op == 'global' {
		if receiver != C.JSContextGetGlobalObject(host.runtime.context) {
			return error('TypeError: Illegal Window or Worker receiver')
		}
		return host.wrap(.crypto)
	}
	host.record(receiver, .crypto)!
	match op {
		'subtle' { return host.wrap(.subtle) }
		'uuid' { return host.runtime.binding_string(host.service.random_uuid()!) }
		'random' {
			if args.len < 3 {
				return error('TypeError: getRandomValues() needs one argument')
			}
			return host.random_values(args[2])
		}
		else { return error('TypeError: Unknown Crypto operation') }
	}
}

fn (mut host CryptoHost) random_values(value voidptr) !voidptr {
	runtime := host.runtime
	is_view := runtime.call_javascript_function(host.array_is_view, C.JSValueMakeUndefined(runtime.context), [value])!
	if !C.JSValueToBoolean(runtime.context, is_view) {
		// The pinned union conversion has no matching concrete view branch.
		return error('TypeError: No union types matched')
	}
	validation := runtime.call_javascript_function(host.view_validation, C.JSValueMakeUndefined(runtime.context), [value])!
	validation_error := runtime.binding_dom_string(validation)!
	if validation_error != '' { return error('TypeError: ${validation_error}') }
	mut exception := unsafe { nil }
	kind := C.vox_crypto_integer_view_kind(runtime.context, value, &exception)
	if exception != unsafe { nil } { return runtime.actual_javascript_exception(exception) }
	if kind < 0 {
		_ := host.service.crypto().get_random_values_for_view(.data_view, false, 0)!
		return error('InvalidStateError: Non-integer Crypto view unexpectedly succeeded')
	}
	mut out_of_bounds := false
	runtime.call_javascript_function(host.typed_array_witness, C.JSValueMakeUndefined(runtime.context), [value]) or { out_of_bounds = true }
	if out_of_bounds {
		_ := host.service.crypto().get_random_values_for_view(unsafe { webcrypto.RandomValuesArrayKind(kind) }, true, 0)!
	}
	length := C.JSObjectGetTypedArrayByteLength(runtime.context, value, &exception)
	if exception != unsafe { nil } { return runtime.actual_javascript_exception(exception) }
	random := host.service.crypto().get_random_values_for_view(unsafe { webcrypto.RandomValuesArrayKind(kind) }, out_of_bounds, u64(length))!
	if random.len == 0 { return value }
	buffer := C.JSObjectGetTypedArrayBuffer(runtime.context, value, &exception)
	if exception != unsafe { nil } { return runtime.actual_javascript_exception(exception) }
	offset := C.JSObjectGetTypedArrayByteOffset(runtime.context, value, &exception)
	if exception != unsafe { nil } { return runtime.actual_javascript_exception(exception) }
	pointer := C.JSObjectGetArrayBufferBytesPtr(runtime.context, buffer, &exception)
	if exception != unsafe { nil } { return runtime.actual_javascript_exception(exception) }
	unsafe { C.memcpy(&u8(pointer) + offset, random.data, uint(random.len)) }
	return value
}

const crypto_native_bootstrap = r'(function(operate,secure){
 const define=Object.defineProperty,T=TypeError;
 function Crypto(){throw new T("Illegal constructor")}
 function SubtleCrypto(){throw new T("Illegal constructor")}
 define(Crypto.prototype,Symbol.toStringTag,{value:"Crypto",configurable:true});define(SubtleCrypto.prototype,Symbol.toStringTag,{value:"SubtleCrypto",configurable:true});
 define(Crypto.prototype,"getRandomValues",{value:function getRandomValues(array){return arguments.length===0?operate("random",this):operate("random",this,array)},writable:true,enumerable:true,configurable:true});
 if(secure){define(Crypto.prototype,"randomUUID",{value:function randomUUID(){return operate("uuid",this)},writable:true,enumerable:true,configurable:true});define(Crypto.prototype,"subtle",{get:function(){return operate("subtle",this)},enumerable:true,configurable:true});define(globalThis,"SubtleCrypto",{value:SubtleCrypto,writable:true,configurable:true})}
 define(Crypto,"prototype",{writable:false});define(SubtleCrypto,"prototype",{writable:false});define(globalThis,"Crypto",{value:Crypto,writable:true,configurable:true});
 define(globalThis,"crypto",{get:function(){return operate("global",this)},enumerable:true,configurable:true});
 return [Crypto.prototype,SubtleCrypto.prototype];
})'
