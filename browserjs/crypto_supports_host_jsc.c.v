// Copyright (c) 2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause
module browserjs

import webcrypto
import webidl

fn (mut host CryptoHost) install_supports() ! {
 mut runtime := unsafe { &Runtime(host.runtime) }
 handle := voidptr(&host)
 operate := runtime.make_value_host_function(fn [handle] (_ voidptr, args []voidptr) !voidptr {
  host := unsafe { &CryptoHost(handle) }
  value := host.supports_operation(args) or { return host.exception(err) }
  return C.vox_jsc_JSValueMakeBoolean(host.runtime.context, value)
 })!
 constructor := runtime.binding_property(host.prototypes[.subtle] or { return error('Missing SubtleCrypto prototype') }, 'constructor')!
 installer := runtime.evaluate_host_value(r'(function(constructor,operate){Object.defineProperty(constructor,"supports",{value:function supports(operation,algorithm){return arguments.length<2?operate():arguments.length<3?operate(operation,algorithm):operate(operation,algorithm,arguments[2])},writable:true,enumerable:true,configurable:true})})')!
 defer { runtime.release_javascript_value(installer) }
 runtime.call_javascript_function(installer, C.vox_jsc_JSValueMakeUndefined(runtime.context), [constructor,operate])!
}

fn (host &CryptoHost) supports_normalize(operation string, algorithm voidptr) !webidl.Value {
 object := C.JSValueIsObject(host.runtime.context, algorithm)
 return match operation {
  'generateKey' { host.normalize_generation(algorithm, object)! }
  'importKey', 'get key length' { host.normalize_import_for_operation(algorithm, object, operation)! }
  'encrypt','decrypt' { host.normalize_cipher(algorithm, object, operation)! }
  'sign','verify' { host.normalize_signature(algorithm, object, operation)! }
  'digest' { host.normalize_digest(algorithm, object)! }
  'deriveBits' { host.normalize_derivation(algorithm, object)! }
  else {
   dictionary := host.algorithm_dictionary(algorithm, object)!
   host.runtime.retain_javascript_value(dictionary)!
   defer { host.runtime.release_javascript_value(dictionary) }
   initial := host.runtime.binding_property(dictionary, 'name')!
   if C.JSValueIsUndefined(host.runtime.context, initial) { return error('TypeError: Missing algorithm name') }
   name := webcrypto.normalize_an_algorithm(host.algorithm_string(initial)!, operation)!
   webcrypto.create_algorithm_dictionary(name)
  }
 }
}

fn (host &CryptoHost) check_crypto_support(operation string, algorithm voidptr, length ?u32) bool {
 if operation == 'getPublicKey' {
  normalized := host.supports_normalize('exportKey', algorithm) or { return false }
  webcrypto.public_key_usages(normalized.object_value['name'].string_value) or { return false }
  return true
 }
 mapped := match operation { 'encapsulateKey','encapsulateBits' { 'encapsulate' } 'decapsulateKey','decapsulateBits' { 'decapsulate' } else { operation } }
 normalized := host.supports_normalize(mapped, algorithm) or {
  if mapped == 'wrapKey' { return host.check_crypto_support('encrypt', algorithm, none) }
  if mapped == 'unwrapKey' { return host.check_crypto_support('decrypt', algorithm, none) }
  return false
 }
 return webcrypto.supports_parameters(mapped, normalized, length)
}

fn (host &CryptoHost) supports_operation(args []voidptr) !bool {
 if args.len < 2 { return error('TypeError: supports() needs 2 arguments') }
 operation := host.algorithm_string(args[0])!
 // AlgorithmIdentifier converts primitives before overload dispatch; dictionary
 // members are read by normalization, where failures become a false result.
 mut algorithm := args[1]
 if !C.JSValueIsObject(host.runtime.context, algorithm) { algorithm = host.runtime.binding_string(host.algorithm_string(algorithm)!) }
 host.runtime.retain_javascript_value(algorithm)!
 defer { host.runtime.release_javascript_value(algorithm) }
 third := host.argument(args, 2)
 additional := C.JSValueIsObject(host.runtime.context, third) || C.JSValueIsString(host.runtime.context, third)
 mut length := ?u32(none)
 if !additional && !C.JSValueIsUndefined(host.runtime.context, third) && !C.JSValueIsNull(host.runtime.context, third) {
  length = u32(webidl.convert_to_int(webidl.number_value(host.algorithm_number(third)!), 32, false, .yes, .no)!)
 }
 if !webcrypto.supports_operation(operation) { return false }
 if additional {
  if operation in ['deriveKey','unwrapKey'] && !host.check_crypto_support('importKey', third, none) { return false }
  if operation == 'wrapKey' && !host.check_crypto_support('exportKey', third, none) { return false }
  if operation in ['encapsulateKey','decapsulateKey'] {
   host.supports_normalize('encapsulate', algorithm) or { return false }
   normalized := host.supports_normalize('importKey', third) or { return false }
   if !webcrypto.supports_shared_key_import(normalized, 256) { return false }
  }
  if operation == 'deriveKey' {
   if !host.check_crypto_support('get key length', third, none) { return false }
   normalized := host.supports_normalize('get key length', third) or { return false }
   key_length := webcrypto.supported_key_length(normalized) or { return false }
   length = key_length.value
   return host.check_crypto_support('deriveBits', algorithm, length)
  }
 }
 return host.check_crypto_support(operation, algorithm, length)
}
