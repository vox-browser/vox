// Copyright (c) 2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause

// SubtleCrypto.cpp's WebIDL operation boundary. The deferred host callback and
// crypto task callback are separate, as in EventLoopPlugin/queue_global_task.
// Values and Promise jobs remain the translated WebIDL boundary pending LibJS.
module webcrypto

import webidl
import x.json2

pub type CryptoTaskScheduler = fn (fn ())

type CryptoOperation = fn () !webidl.Value

type NormalizedCryptoParams = AeadParams
	| AesCbcParams
	| AesCtrParams
	| AesGcmParams
	| AesKeyGenParams
	| AlgorithmParams
	| Argon2Params
	| CShakeParams
	| EcKeyGenParams
	| EcKeyImportParams
	| EcdhKeyDeriveParams
	| EcdsaParams
	| Ed448Params
	| HkdfParams
	| HmacImportParams
	| HmacKeyGenParams
	| KmacImportParams
	| KmacKeyGenParams
	| KmacParams
	| Pbkdf2Params
	| RsaHashedImportParams
	| RsaHashedKeyGenParams
	| RsaOaepParams
	| RsaPssParams

struct NormalizedCryptoAlgorithm {
	name   string
	params NormalizedCryptoParams
}

@[heap]
pub struct SubtleCryptoBinding {
	crypto            &SubtleCrypto @[required]
	context           webidl.PromiseContext
	deferred_invoke   CryptoTaskScheduler @[required]
	queue_crypto_task CryptoTaskScheduler @[required]
}

pub fn SubtleCryptoBinding.create(crypto &SubtleCrypto, context webidl.PromiseContext,
	deferred_invoke CryptoTaskScheduler, queue_crypto_task CryptoTaskScheduler) &SubtleCryptoBinding {
	return &SubtleCryptoBinding{
		crypto:            crypto
		context:           context
		deferred_invoke:   deferred_invoke
		queue_crypto_task: queue_crypto_task
	}
}

fn crypto_exception_value(message string) webidl.Value {
	separator := message.index(': ') or { return webidl.string_value(message) }
	name := message[..separator]
	text := message[separator + 2..]
	if name in ['TypeError', 'RangeError', 'InternalError'] {
		return webidl.object_value({
			'name':    webidl.string_value(name)
			'message': webidl.string_value(text)
		})
	}
	return webidl.dom_exception_value(webidl.DOMException.create(name, text))
}

fn (binding &SubtleCryptoBinding) rejected(message string) &webidl.Promise {
	return webidl.create_rejected_promise_for(binding.context, crypto_exception_value(message))
}

fn (binding &SubtleCryptoBinding) run(operation CryptoOperation, crypto_task bool) &webidl.Promise {
	mut promise := webidl.create_promise_for(binding.context)
	binding.deferred_invoke(fn [binding, operation, crypto_task, mut promise] () {
		result := operation() or {
			reason := crypto_exception_value(err.msg())
			if crypto_task {
				binding.queue_crypto_task(fn [reason, mut promise] () { promise.reject(reason) })
			} else {
				promise.reject(reason)
			}
			return
		}
		if crypto_task {
			binding.queue_crypto_task(fn [result, mut promise] () { promise.resolve(result) })
		} else {
			promise.resolve(result)
		}
	})
	return promise
}

fn crypto_buffer_value(bytes []u8) webidl.Value {
	return webidl.buffer_source_value(webidl.BufferSource.array_buffer(bytes))
}

fn binding_value_to_json(value webidl.Value) !json2.Any {
	return match value.kind {
		.string_ { json2.Any(value.string_value) }
		.number { json2.Any(value.number_value) }
		.boolean { json2.Any(value.boolean_value) }
		.buffer_source {
			source := value.buffer_value or { return error('TypeError: Invalid BufferSource') }
			mut bytes := []json2.Any{}
			for byte in webidl.get_buffer_source_copy(source) { bytes << json2.Any(f64(byte)) }
			json2.Any(bytes)
		}
		.object {
			mut object := map[string]json2.Any{}
			for name, property in value.object_value {
				if property.kind != .undefined { object[name] = binding_value_to_json(property)! }
			}
			json2.Any(object)
		}
		.sequence {
			mut sequence := []json2.Any{}
			for property in value.sequence_value { sequence << binding_value_to_json(property)! }
			json2.Any(sequence)
		}
		else { json2.Any(json2.Null{}) }
	}
}

fn binding_algorithm_fields(name string, operation string) []string {
	if operation in ['encrypt', 'decrypt'] {
		return match name {
			'AES-CBC' { ['iv'] }
			'AES-CTR' { ['counter', 'length'] }
			'AES-GCM', 'AES-OCB', 'ChaCha20-Poly1305' { ['iv', 'additionalData', 'tagLength'] }
			'RSA-OAEP' { ['label'] }
			else { []string{} }
		}
	}
	if operation in ['sign', 'verify'] {
		return match name {
			'RSA-PSS' { ['saltLength'] }
			'ECDSA' { ['hash'] }
			'Ed448', 'ML-DSA-44', 'ML-DSA-65', 'ML-DSA-87' { ['context'] }
			'KMAC128', 'KMAC256' { ['outputLength', 'customization'] }
			else { []string{} }
		}
	}
	if operation == 'digest' {
		return if name in ['cSHAKE128', 'cSHAKE256'] {
			['outputLength', 'functionName', 'customization']
		} else {
			[]string{}
		}
	}
	if operation == 'generateKey' {
		if name.starts_with('AES-') { return ['length'] }
		if name in ['RSA-OAEP', 'RSA-PSS', 'RSASSA-PKCS1-v1_5'] {
			return ['modulusLength', 'publicExponent', 'hash']
		}
		if name in ['ECDSA', 'ECDH'] { return ['namedCurve'] }
		if name == 'HMAC' { return ['hash', 'length'] }
		if name in ['KMAC128', 'KMAC256'] { return ['length'] }
	}
	if operation in ['importKey', 'get key length'] {
		if name in ['RSA-OAEP', 'RSA-PSS', 'RSASSA-PKCS1-v1_5'] { return ['hash'] }
		if name in ['ECDSA', 'ECDH'] { return ['namedCurve'] }
		if name == 'HMAC' { return ['hash', 'length'] }
		if name in ['KMAC128', 'KMAC256'] || (operation == 'get key length' && name.starts_with('AES-')) {
			return ['length']
		}
	}
	if operation == 'deriveBits' {
		return match name {
			'HKDF' { ['hash', 'salt', 'info'] }
			'PBKDF2' { ['salt', 'iterations', 'hash'] }
			'Argon2d', 'Argon2i', 'Argon2id' {
				['nonce', 'parallelism', 'memory', 'passes', 'version', 'secretValue', 'associatedData']
			}
			else { []string{} }
		}
	}
	return []string{}
}

fn normalize_binding_algorithm(algorithm webidl.Value, operation string) !NormalizedCryptoAlgorithm {
	value := if algorithm.kind == .string_ {
		create_algorithm_dictionary(algorithm.string_value)
	} else {
		algorithm
	}
	if value.kind != .object { return error('TypeError: Algorithm must be an object or string') }
	initial_name := value.object_value['name'] or { return error('TypeError: Not an object of type Algorithm') }
	if initial_name.kind == .undefined { return error('TypeError: Not an object of type Algorithm') }
	if initial_name.kind !in [.null_, .boolean, .number, .string_, .bigint] {
		return error('TypeError: name cannot be converted to a string by this value boundary')
	}
	name := normalize_an_algorithm(webidl.to_string(initial_name)!, operation)!
	// BufferSource fields are converted before the deferred operation and copied
	// through get_buffer_source_copy, including offset DataView/TypedArray views.
	mut object := map[string]json2.Any{}
	for field in binding_algorithm_fields(name, operation) {
        property := value.object_value[field] or {
            if (name in ['Argon2d', 'Argon2i', 'Argon2id'] && field in ['nonce', 'parallelism', 'memory', 'passes']) || field == 'outputLength' {
                return error('TypeError: Required property ${field} is missing or undefined')
            }
            if field == 'hash' { return error('TypeError: hash is required') }
            if field == 'publicExponent' { return error('TypeError: Not an object of type Uint8Array') }
            if field in ['iv', 'counter', 'salt', 'info'] { return error('TypeError: Not an object of type BufferSource') }
            continue
        }
        if field == 'namedCurve' {
            if property.kind !in [.undefined, .null_, .boolean, .number, .string_, .bigint] {
                return error('TypeError: namedCurve cannot be converted to a string by this value boundary')
            }
            object[field] = webidl.to_string(property)!
            continue
        }
        if field == 'hash' {
            // Normalize the nested digest at its source read position, before
            // later numeric/buffer fields. Preserve its copied dictionary for
            // the parameter body, including cSHAKE required fields.
            _ = normalize_binding_algorithm(property, 'digest')!
            object[field] = binding_value_to_json(property)!
            continue
        }
        if field in ['parallelism', 'memory', 'passes', 'version', 'outputLength'] {
            if property.kind !in [.undefined, .null_, .boolean, .number, .string_, .bigint] {
                return error('TypeError: ${field} cannot be converted to a number by this value boundary')
            }
            converted := json2.Any(webidl.value_to_number(property)!)
            width := if field == 'version' { 8 } else { 32 }
            object[field] = i64(algorithm_enforce_uint({field: converted}, field, width)!)
            continue
        }
        if field in ['length', 'tagLength', 'modulusLength', 'saltLength', 'iterations'] {
            if property.kind !in [.undefined, .null_, .boolean, .number, .string_, .bigint] {
                return error('TypeError: ${field} cannot be converted to a number by this value boundary')
            }
            converted := json2.Any(webidl.value_to_number(property)!)
            width := if field == 'tagLength' || (name == 'AES-CTR' && field == 'length' && operation in ['encrypt', 'decrypt']) { 8 } else if name.starts_with('AES-') && field == 'length' { 16 } else { 32 }
            object[field] = i64(algorithm_enforce_uint({field: converted}, field, width)!)
            continue
        }
        if name == 'RSA-OAEP' && field == 'label' && property.kind in [.null_, .undefined] { continue }
        if field == 'publicExponent' {
            source := property.buffer_value or { return error('TypeError: Not an object of type Uint8Array') }
            if property.kind != .buffer_source || source.kind != .uint8_array { return error('TypeError: Not an object of type Uint8Array') }
            object[field] = binding_value_to_json(property)!
            continue
        }
        if field in ['iv', 'counter', 'salt', 'info', 'nonce', 'additionalData', 'functionName',
            'customization', 'context', 'label', 'secretValue', 'associatedData'] {
            if property.kind != .buffer_source { return error('TypeError: Not an object of type BufferSource') }
            object[field] = binding_value_to_json(property)!
            continue
        }
        if property.kind == .undefined || property.kind == .platform_object { continue }
		object[field] = binding_value_to_json(property)!
	}
	input := json2.Any(object)
	mut params := NormalizedCryptoParams(AlgorithmParams{ name: name })
	if operation in ['encrypt', 'decrypt'] {
		params = match name {
			'AES-CBC' {
				p := AesCbcParams.from_value(input)!
				NormalizedCryptoParams(AesCbcParams{ ...p, name: name })
			}
			'AES-CTR' {
				p := AesCtrParams.from_value(input)!
				NormalizedCryptoParams(AesCtrParams{ ...p, name: name })
			}
			'AES-GCM' {
				p := AesGcmParams.from_value(input)!
				NormalizedCryptoParams(AesGcmParams{ ...p, name: name })
			}
			'AES-OCB', 'ChaCha20-Poly1305' {
				p := AeadParams.from_value(input)!
				NormalizedCryptoParams(AeadParams{ ...p, name: name })
			}
			'RSA-OAEP' {
				p := RsaOaepParams.from_value(input)!
				NormalizedCryptoParams(RsaOaepParams{ ...p, name: name })
			}
			else { params }
		}
	} else if operation in ['sign', 'verify'] {
		params = match name {
			'RSA-PSS' {
				p := RsaPssParams.from_value(input)!
				NormalizedCryptoParams(RsaPssParams{ ...p, name: name })
			}
			'ECDSA' {
				p := EcdsaParams.from_value(input)!
				NormalizedCryptoParams(EcdsaParams{ ...p, name: name })
			}
			'Ed448', 'ML-DSA-44', 'ML-DSA-65', 'ML-DSA-87' {
				p := Ed448Params.from_value(input)!
				NormalizedCryptoParams(Ed448Params{ ...p, name: name })
			}
			'KMAC128', 'KMAC256' {
				p := KmacParams.from_value(input)!
				NormalizedCryptoParams(KmacParams{ ...p, name: name })
			}
			else { params }
		}
	} else if operation == 'digest' && name in ['cSHAKE128', 'cSHAKE256'] {
		p := CShakeParams.from_value(input)!
		params = CShakeParams{ ...p, name: name }
	} else if operation == 'generateKey' {
		if name.starts_with('AES-') {
			p := AesKeyGenParams.from_value(input)!
			params = AesKeyGenParams{ ...p, name: name }
		} else if name in ['RSA-OAEP', 'RSA-PSS', 'RSASSA-PKCS1-v1_5'] {
			p := RsaHashedKeyGenParams.from_value(input)!
			params = RsaHashedKeyGenParams{ ...p, name: name }
		} else if name in ['ECDSA', 'ECDH'] {
			p := EcKeyGenParams.from_value(input)!
			params = EcKeyGenParams{ ...p, name: name }
		} else if name == 'HMAC' {
			p := HmacKeyGenParams.from_value(input)!
			params = HmacKeyGenParams{ ...p, name: name }
		} else if name in ['KMAC128', 'KMAC256'] {
			p := KmacKeyGenParams.from_value(input)!
			params = KmacKeyGenParams{ ...p, name: name }
		}
	} else if operation in ['importKey', 'get key length'] {
		if name in ['RSA-OAEP', 'RSA-PSS', 'RSASSA-PKCS1-v1_5'] {
			p := RsaHashedImportParams.from_value(input)!
			params = RsaHashedImportParams{ ...p, name: name }
		} else if name in ['ECDSA', 'ECDH'] {
			p := EcKeyImportParams.from_value(input)!
			params = EcKeyImportParams{ ...p, name: name }
		} else if name == 'HMAC' {
			p := HmacImportParams.from_value(input)!
			params = HmacImportParams{ ...p, name: name }
		} else if name in ['KMAC128', 'KMAC256'] {
			p := KmacImportParams.from_value(input)!
			params = KmacImportParams{ ...p, name: name }
		} else if operation == 'get key length' && name.starts_with('AES-') {
			p := AesKeyGenParams.from_value(input)!
			params = AesKeyGenParams{ ...p, name: name }
		}
	} else if operation == 'deriveBits' {
		params = match name {
			'HKDF' {
				p := HKDFParams.from_value(input)!
				NormalizedCryptoParams(HkdfParams{ ...p, name: name })
			}
			'PBKDF2' {
				p := PBKDF2Params.from_value(input)!
				NormalizedCryptoParams(Pbkdf2Params{ ...p, name: name })
			}
			'Argon2d', 'Argon2i', 'Argon2id' {
				p := Argon2Params.from_value(input)!
				NormalizedCryptoParams(Argon2Params{ ...p, name: name })
			}
			else {
				public_value := value.object_value['public'] or { return error('TypeError: public is required') }
				NormalizedCryptoParams(EcdhKeyDeriveParams{ name: name, public_key: crypto_key_from_value(public_value)! })
			}
		}
	}
	return NormalizedCryptoAlgorithm{ name: name, params: params }
}

fn binding_validate_key(key &CryptoKey, name string, usage KeyUsage) ! {
	if key.algorithm_name() != name {
		message := if usage in [.encapsulate_bits, .encapsulate_key] {
			'Invalid encapsulation key algorithm'
		} else if usage in [.decapsulate_bits, .decapsulate_key] {
			'Invalid algorithm name'
		} else {
			'Algorithm mismatch'
		}
		return error('InvalidAccessError: ${message}')
	}
	if key.permits(usage) { return }
	message := match usage {
		.encrypt { 'Key does not support encryption' }
		.decrypt { 'Key does not support decryption' }
		.sign { 'Key does not support signing' }
		.verify { 'Key does not support verification' }
		.derive_bits { 'Key does not support deriving bits' }
		.derive_key { 'Key does not support deriving keys' }
		.wrap_key { 'Key does not support wrapping keys' }
		.unwrap_key { 'Key does not support unwrapping keys' }
		.encapsulate_bits { 'Invalid encapsulation key usages' }
		.encapsulate_key { 'Invalid encapsulation key usage' }
		.decapsulate_bits, .decapsulate_key { 'Invalid key usages' }
	}
	return error('InvalidAccessError: ${message}')
}

fn normalized_encrypt(algorithm NormalizedCryptoAlgorithm, key &CryptoKey, data []u8, decrypt bool) ![]u8 {
	params := algorithm.params
	if params is RsaOaepParams {
		return if decrypt {
			RSAOAEP.create().decrypt(params, key, data)!
		} else {
			RSAOAEP.create().encrypt(params, key, data)!
		}
	}
	return match params {
		AesCbcParams {
			if decrypt {
				aes_cbc_decrypt(params, key, data)!
			} else {
				aes_cbc_encrypt(params, key, data)!
			}
		}
		AesCtrParams { aes_ctr_crypt(params, key, data, decrypt)! }
		AesGcmParams {
			if decrypt {
				aes_gcm_decrypt(params, key, data)!
			} else {
				aes_gcm_encrypt(params, key, data)!
			}
		}
		AeadParams {
			if algorithm.name == 'AES-OCB' {
				aes_ocb_crypt(params, key, data, decrypt)!
			} else {
				chacha20_poly1305_crypt(params, key, data, decrypt)!
			}
		}
		else { error('NotSupportedError: Algorithm does not support encryption') }
	}
}

fn normalized_sign(algorithm NormalizedCryptoAlgorithm, key &CryptoKey, data []u8) ![]u8 {
	params := algorithm.params
	return match params {
		RsaPssParams { RSAPSS.create().sign(params, key, data)! }
		EcdsaParams { ECDSA.create().sign(params, key, data)! }
		Ed448Params {
			if algorithm.name == 'Ed448' {
				ED448.create().sign(params, key, data)!
			} else {
				MLDSA.create().sign(params, key, data)!
			}
		}
		KmacParams { KMAC.create().sign(params, key, data)! }
		else {
			if algorithm.name == 'RSASSA-PKCS1-v1_5' {
				RSASSAPKCS1.create().sign(AlgorithmParams{ name: algorithm.name }, key, data)!
			} else {
				SubtleCrypto.create().sign(algorithm.name, key, data)!
			}
		}
	}
}

fn normalized_verify(algorithm NormalizedCryptoAlgorithm, key &CryptoKey, signature []u8, data []u8) !bool {
	params := algorithm.params
	return match params {
		RsaPssParams { RSAPSS.create().verify(params, key, signature, data)! }
		EcdsaParams { ECDSA.create().verify(params, key, signature, data)! }
		Ed448Params {
			if algorithm.name == 'Ed448' {
				ED448.create().verify(params, key, signature, data)!
			} else {
				MLDSA.create().verify(params, key, signature, data)!
			}
		}
		KmacParams { KMAC.create().verify(params, key, signature, data)! }
		else {
			if algorithm.name == 'RSASSA-PKCS1-v1_5' {
				RSASSAPKCS1.create().verify(AlgorithmParams{ name: algorithm.name }, key, signature, data)!
			} else {
				SubtleCrypto.create().verify(algorithm.name, key, signature, data)!
			}
		}
	}
}

fn normalized_generate(algorithm NormalizedCryptoAlgorithm, extractable bool, usages []KeyUsage) !GeneratedKey {
	params := algorithm.params
    if algorithm.name == 'ChaCha20-Poly1305' { return generate_chacha_key(extractable, usages) }
	return match params {
		AesKeyGenParams {
			GeneratedKey{ key: generate_aes_key(params, extractable, usages)! }
		}
		HmacKeyGenParams { GeneratedKey{ key: generate_hmac_key(params, extractable, usages)! } }
		KmacKeyGenParams { KMAC.create().generate_key(params, extractable, usages)! }
		RsaHashedKeyGenParams {
			match algorithm.name {
				'RSA-OAEP' { RSAOAEP.create().generate_key(params, extractable, usages)! }
				'RSA-PSS' { RSAPSS.create().generate_key(params, extractable, usages)! }
				else { RSASSAPKCS1.create().generate_key(params, extractable, usages)! }
			}
		}
		EcKeyGenParams {
			if algorithm.name == 'ECDH' {
				ECDH.create().generate_key(params, extractable, usages)!
			} else {
				ECDSA.create().generate_key(params, extractable, usages)!
			}
		}
		else {
			basic := AlgorithmParams{ name: algorithm.name }
			match algorithm.name {
				'X25519' { X25519.create().generate_key(basic, extractable, usages)! }
				'X448' { X448.create().generate_key(basic, extractable, usages)! }
				'Ed448' { ED448.create().generate_key(basic, extractable, usages)! }
				'Ed25519' { ED25519.create().generate_key(basic, extractable, usages)! }
				'ML-DSA-44', 'ML-DSA-65', 'ML-DSA-87' {
					MLDSA.create().generate_key(basic, extractable, usages)!
				}
				'ML-KEM-512', 'ML-KEM-768', 'ML-KEM-1024' {
					MLKEM.create().generate_key(basic, extractable, usages)!
				}
				else { SubtleCrypto.create().generate_key(basic, extractable, usages)! }
			}
		}
	}
}

fn normalized_import(algorithm NormalizedCryptoAlgorithm, format KeyFormat, bytes []u8, extractable bool, usages []KeyUsage) !&CryptoKey {
	params := algorithm.params
    if algorithm.name == 'AES-OCB' { return import_aes_ocb_key(format, bytes, extractable, usages) }
    if algorithm.name == 'ChaCha20-Poly1305' { return import_chacha_key(format, bytes, extractable, usages) }
    if algorithm.name in ['AES-CBC', 'AES-CTR', 'AES-GCM', 'AES-KW'] { return import_aes_key(algorithm.name, format, bytes, extractable, usages) }
	if params is HmacImportParams { return HMAC.create().import_key(params, format, bytes, extractable, usages) }
    if params is KmacImportParams { return KMAC.create().import_key(params, format, bytes, extractable, usages) }
	if params is RsaHashedImportParams {
		return match algorithm.name {
			'RSA-OAEP' { RSAOAEP.create().import_key(params, format, bytes, extractable, usages)! }
			'RSA-PSS' { RSAPSS.create().import_key(params, format, bytes, extractable, usages)! }
			else { RSASSAPKCS1.create().import_key(params, format, bytes, extractable, usages)! }
		}
	}
	if params is EcKeyImportParams {
		return if algorithm.name == 'ECDH' {
			ECDH.create().import_key(params, format, bytes, extractable, usages)!
		} else {
			ECDSA.create().import_key(params, format, bytes, extractable, usages)!
		}
	}
	basic := AlgorithmParams{ name: algorithm.name }
	if algorithm.name == 'Ed25519' { return ED25519.create().import_key(basic, format, bytes, extractable, usages) }
    if algorithm.name == 'Ed448' { return ED448.create().import_key(basic, format, bytes, extractable, usages) }
	if algorithm.name == 'X25519' {
		return X25519.create().import_key(basic, format, bytes, extractable, usages)
	}
	if algorithm.name == 'X448' {
		return X448.create().import_key(basic, format, bytes, extractable, usages)
	}
	if algorithm.name.starts_with('ML-DSA-') {
		return MLDSA.create().import_key(basic, format, bytes, extractable, usages)
	}
	if algorithm.name.starts_with('ML-KEM-') {
		return MLKEM.create().import_key(basic, format, bytes, extractable, usages)
	}
	if algorithm.name in ['HKDF', 'PBKDF2'] { return import_kdf_key(algorithm.name, format, bytes, extractable, usages) }
	if algorithm.name in ['Argon2d', 'Argon2i', 'Argon2id'] { return import_argon2_key(algorithm.name, format, bytes, extractable, usages) }
	mut import_params := ImportKeyParams(algorithm.name)
	mut hash_name := ''
	if params is KmacImportParams { import_params = params }
	if params is HmacImportParams { hash_name = params.hash }
	if format == .jwk {
		return SubtleCrypto.create().import_jwk(decode_json_web_key_dictionary(bytes)!, import_params, extractable, usages, hash_name)
	}
	if format in [.raw, .raw_secret] && algorithm.name in ['AES-CBC', 'AES-CTR', 'AES-GCM', 'AES-KW', 'HMAC', 'HKDF', 'PBKDF2', 'ChaCha20-Poly1305'] {
		// Invoke the algorithm import body; public importKey applies the common
		// empty-private/secret-usages check afterward. KEM key-returning methods
		// call this body directly and do not perform that separate check.
		return import_secret_key(algorithm.name, bytes, extractable, usages, hash_name)
	}
	return SubtleCrypto.create().import_key(format, bytes, import_params, extractable, usages, hash_name)
}

fn normalized_derive(algorithm NormalizedCryptoAlgorithm, key &CryptoKey, length ?u32, usage KeyUsage) ![]u8 {
	binding_validate_key(key, algorithm.name, usage)!
	params := algorithm.params
	return match params {
		HkdfParams {
			hkdf_derive_bits(params, key, length)!
		}
		Pbkdf2Params {
			pbkdf2_derive_bits(params, key, length)!
		}
		Argon2Params {
			argon2_derive_bits(params, key, length)!
		}
		EcdhKeyDeriveParams {
			match algorithm.name {
				'ECDH' { ECDH.create().derive_bits(params, key, length)! }
				'X25519' { X25519.create().derive_bits(params, key, length)! }
				else { X448.create().derive_bits(params, key, length)! }
			}
		}
		else { error('NotSupportedError: Algorithm does not support deriving bits') }
	}
}

fn normalized_key_length(algorithm NormalizedCryptoAlgorithm) !KeyLengthResult {
	params := algorithm.params
	return match params {
		AesKeyGenParams { KeyLengthResult{ value: if algorithm.name == 'AES-OCB' { aes_ocb_key_length(params)! } else { aes_key_length(params)! } } }
		HmacImportParams { HMAC.create().get_key_length(params)! }
		KmacImportParams { KMAC.create().get_key_length(params)! }
		else {
			if algorithm.name == 'ChaCha20-Poly1305' {
				KeyLengthResult{ value: u32(256) }
			} else {
				KeyLengthResult{}
			}
		}
	}
}

fn binding_key_result(realm string, generated GeneratedKey) !webidl.Value {
	if key := generated.key {
		if key.type_ in [.secret, .private_key] && key.usages.len == 0 {
			return error('SyntaxError: usages must not be empty')
		}
		mut normalized_key := unsafe { &CryptoKey(key) }
		normalized_key.set_usages(normalize_key_usages(key.usages))
		return crypto_key(realm, key)
	}
	pair := generated.pair or { return error('OperationError: No generated key') }
	if pair.private_key.usages.len == 0 { return error('SyntaxError: usages must not be empty') }
	return webidl.object_value(crypto_key_pair(realm, &pair))
}

pub fn (binding &SubtleCryptoBinding) digest(algorithm webidl.Value, data webidl.BufferSource) &webidl.Promise {
	normalized := normalize_binding_algorithm(algorithm, 'digest') or { return binding.rejected(err.msg()) }
	bytes := webidl.get_buffer_source_copy(data)
	return binding.run(fn [normalized, bytes] () !webidl.Value {
		params := normalized.params
		digest := if params is CShakeParams {
			CShake.create().digest(params, bytes)!
		} else {
			digest_bytes(normalized.name, bytes)!
		}
		return crypto_buffer_value(digest)
	}, true)
}

pub fn (binding &SubtleCryptoBinding) encrypt(algorithm webidl.Value, key &CryptoKey, data webidl.BufferSource) &webidl.Promise {
	normalized := normalize_binding_algorithm(algorithm, 'encrypt') or { return binding.rejected(err.msg()) }
	bytes := webidl.get_buffer_source_copy(data)
	return binding.run(fn [normalized, key, bytes] () !webidl.Value {
		binding_validate_key(key, normalized.name, .encrypt)!
		return crypto_buffer_value(normalized_encrypt(normalized, key, bytes, false)!)
	}, true)
}

pub fn (binding &SubtleCryptoBinding) decrypt(algorithm webidl.Value, key &CryptoKey, data webidl.BufferSource) &webidl.Promise {
	normalized := normalize_binding_algorithm(algorithm, 'decrypt') or { return binding.rejected(err.msg()) }
	bytes := webidl.get_buffer_source_copy(data)
	return binding.run(fn [normalized, key, bytes] () !webidl.Value {
		binding_validate_key(key, normalized.name, .decrypt)!
		return crypto_buffer_value(normalized_encrypt(normalized, key, bytes, true)!)
	}, true)
}

pub fn (binding &SubtleCryptoBinding) sign(algorithm webidl.Value, key &CryptoKey, data webidl.BufferSource) &webidl.Promise {
	normalized := normalize_binding_algorithm(algorithm, 'sign') or { return binding.rejected(err.msg()) }
	bytes := webidl.get_buffer_source_copy(data)
	return binding.run(fn [normalized, key, bytes] () !webidl.Value {
		binding_validate_key(key, normalized.name, .sign)!
		return crypto_buffer_value(normalized_sign(normalized, key, bytes)!)
	}, true)
}

pub fn (binding &SubtleCryptoBinding) verify(algorithm webidl.Value, key &CryptoKey, signature webidl.BufferSource, data webidl.BufferSource) &webidl.Promise {
	normalized := normalize_binding_algorithm(algorithm, 'verify') or { return binding.rejected(err.msg()) }
	signature_bytes := webidl.get_buffer_source_copy(signature)
	bytes := webidl.get_buffer_source_copy(data)
	return binding.run(fn [normalized, key, signature_bytes, bytes] () !webidl.Value {
		binding_validate_key(key, normalized.name, .verify)!
		return webidl.boolean_value(normalized_verify(normalized, key, signature_bytes, bytes)!)
	}, true)
}

pub fn (binding &SubtleCryptoBinding) generate_key(algorithm webidl.Value, extractable bool, usages []KeyUsage) &webidl.Promise {
	normalized := normalize_binding_algorithm(algorithm, 'generateKey') or { return binding.rejected(err.msg()) }
	realm := binding.context.realm_id.str()
	copied_usages := usages.clone()
	return binding.run(fn [normalized, extractable, copied_usages, realm] () !webidl.Value {
		return binding_key_result(realm, normalized_generate(normalized, extractable, copied_usages)!)
	}, false)
}

pub fn (binding &SubtleCryptoBinding) import_key(format KeyFormat, material webidl.Value, algorithm webidl.Value, extractable bool, usages []KeyUsage) &webidl.Promise {
	// Source copies key data before algorithm normalization.
	bytes := if format == .jwk {
		if material.kind != .object {
			return binding.rejected('TypeError: keyData must be a JsonWebKey dictionary')
		}
		json2.encode(binding_value_to_json(material) or { return binding.rejected(err.msg()) }).bytes()
	} else {
		source := material.buffer_value or { return binding.rejected('TypeError: keyData must be a BufferSource') }
		webidl.get_buffer_source_copy(source)
	}
	normalized := normalize_binding_algorithm(algorithm, 'importKey') or { return binding.rejected(err.msg()) }
	realm := binding.context.realm_id.str()
	copied_usages := usages.clone()
	return binding.run(fn [normalized, format, bytes, extractable, copied_usages, realm] () !webidl.Value {
		mut key := normalized_import(normalized, format, bytes, extractable, copied_usages)!
		if key.type_ in [.secret, .private_key] && copied_usages.len == 0 {
			return error('SyntaxError: usages must not be empty')
		}
		key.set_extractable(extractable)
		key.set_usages(normalize_key_usages(copied_usages))
		return crypto_key(realm, key)
	}, false)
}

pub fn (binding &SubtleCryptoBinding) export_key(format KeyFormat, key &CryptoKey) &webidl.Promise {
	return binding.run(fn [binding, format, key] () !webidl.Value {
		normalize_an_algorithm(key.algorithm_name(), 'exportKey')!
		if !key.extractable { return error('InvalidAccessError: Key is not extractable') }
        if key.algorithm_name() in ['Ed25519', 'ChaCha20-Poly1305'] {
            bytes := if key.algorithm_name() == 'Ed25519' { export_ed25519_key(format, key)! } else { export_chacha_key(format, key)! }
            if format == .jwk { return export_key_result_to_js_value('', ExportKeyResult(JsonWebKey.parse(bytes)!)) }
            return crypto_buffer_value(bytes)
        }
		if format == .jwk {
			return export_key_result_to_js_value('', ExportKeyResult(binding.crypto.export_jwk(key)!))
		}
		return crypto_buffer_value(binding.crypto.export_key(format, key)!)
	}, false)
}

pub fn (binding &SubtleCryptoBinding) derive_bits(algorithm webidl.Value, key &CryptoKey, length ?u32) &webidl.Promise {
	normalized := normalize_binding_algorithm(algorithm, 'deriveBits') or { return binding.rejected(err.msg()) }
	return binding.run(fn [normalized, key, length] () !webidl.Value {
		return crypto_buffer_value(normalized_derive(normalized, key, length, .derive_bits)!)
	}, false)
}

pub fn (binding &SubtleCryptoBinding) derive_key(algorithm webidl.Value, key &CryptoKey, derived_algorithm webidl.Value, extractable bool, usages []KeyUsage) &webidl.Promise {
	return binding.derive_key_with_parameter_snapshots(algorithm, key, derived_algorithm, derived_algorithm, extractable, usages)
}

// Native bindings perform the two observable destination normalizations on the
// original engine object. Keep their independently copied parameter snapshots.
pub fn (binding &SubtleCryptoBinding) derive_key_with_parameter_snapshots(algorithm webidl.Value, key &CryptoKey, derived_import webidl.Value, derived_length webidl.Value, extractable bool, usages []KeyUsage) &webidl.Promise {
	normalized := normalize_binding_algorithm(algorithm, 'deriveBits') or { return binding.rejected(err.msg()) }
	normalized_import_params := normalize_binding_algorithm(derived_import, 'importKey') or { return binding.rejected(err.msg()) }
	normalized_length := normalize_binding_algorithm(derived_length, 'get key length') or { return binding.rejected(err.msg()) }
	realm := binding.context.realm_id.str()
	copied_usages := usages.clone()
	return binding.run(fn [normalized, key, normalized_import_params, normalized_length, extractable, copied_usages, realm] () !webidl.Value {
		binding_validate_key(key, normalized.name, .derive_key)!
		length := normalized_key_length(normalized_length)!
		bytes := normalized_derive(normalized, key, length.value, .derive_key)!
		mut result := normalized_import(normalized_import_params, .raw, bytes, extractable, copied_usages)!
		if result.type_ in [.secret, .private_key] && copied_usages.len == 0 {
			return error('SyntaxError: usages must not be empty')
		}
		result.set_extractable(extractable)
		result.set_usages(normalize_key_usages(copied_usages))
		return crypto_key(realm, result)
	}, false)
}

fn normalize_wrapping_algorithm(algorithm webidl.Value, unwrap bool) !NormalizedCryptoAlgorithm {
	return normalize_binding_algorithm(algorithm, if unwrap { 'unwrapKey' } else { 'wrapKey' }) or {
		normalize_binding_algorithm(algorithm, if unwrap { 'decrypt' } else { 'encrypt' })!
	}
}

pub fn (binding &SubtleCryptoBinding) wrap_key(format KeyFormat, key &CryptoKey, wrapping_key &CryptoKey, algorithm webidl.Value) &webidl.Promise {
	normalized := normalize_wrapping_algorithm(algorithm, false) or { return binding.rejected(err.msg()) }
	return binding.run(fn [binding, normalized, format, key, wrapping_key] () !webidl.Value {
		binding_validate_key(wrapping_key, normalized.name, .wrap_key)!
		if !key.extractable { return error('InvalidAccessError: Key is not extractable') }
		normalize_an_algorithm(key.algorithm_name(), 'exportKey')!
		bytes := if key.algorithm_name() == 'Ed25519' { export_ed25519_key(format, key)! } else if key.algorithm_name() == 'ChaCha20-Poly1305' { export_chacha_key(format, key)! } else { binding.crypto.export_key_bytes_for_wrapping(format, key)! }
		wrapped := if normalized.name == 'AES-KW' {
			aes_key_wrap(wrapping_key, bytes)!
		} else {
			normalized_encrypt(normalized, wrapping_key, bytes, false)!
		}
		return crypto_buffer_value(wrapped)
	}, false)
}

pub fn (binding &SubtleCryptoBinding) unwrap_key(format KeyFormat, wrapped_key webidl.BufferSource, unwrapping_key &CryptoKey, algorithm webidl.Value, unwrapped_algorithm webidl.Value, extractable bool, usages []KeyUsage) &webidl.Promise {
	normalized := normalize_wrapping_algorithm(algorithm, true) or { return binding.rejected(err.msg()) }
	normalized_import_params := normalize_binding_algorithm(unwrapped_algorithm, 'importKey') or { return binding.rejected(err.msg()) }
	bytes := webidl.get_buffer_source_copy(wrapped_key)
	copied_usages := usages.clone()
	realm := binding.context.realm_id.str()
	return binding.run(fn [normalized, normalized_import_params, format, bytes, unwrapping_key, extractable, copied_usages, realm] () !webidl.Value {
		binding_validate_key(unwrapping_key, normalized.name, .unwrap_key)!
		unwrapped := if normalized.name == 'AES-KW' {
			aes_key_unwrap(unwrapping_key, bytes)!
		} else {
			normalized_encrypt(normalized, unwrapping_key, bytes, true)!
		}
		// unwrap parses JWK JSON before entering the concrete import body; an
		// ordinary importKey dictionary has no separate mandatory-kty parse step.
		if format == .jwk { _ = JsonWebKey.parse(unwrapped)! }
		mut key := normalized_import(normalized_import_params, format, unwrapped, extractable, copied_usages)!
		if key.type_ in [.secret, .private_key] && copied_usages.len == 0 {
			return error('SyntaxError: Usages must not be empty')
		}
		key.set_extractable(extractable)
		key.set_usages(normalize_key_usages(copied_usages))
		return crypto_key(realm, key)
	}, false)
}

pub fn (binding &SubtleCryptoBinding) encapsulate_bits(algorithm webidl.Value, key &CryptoKey) &webidl.Promise {
	normalized := normalize_binding_algorithm(algorithm, 'encapsulate') or { return binding.rejected(err.msg()) }
	realm := binding.context.realm_id.str()
	return binding.run(fn [normalized, key, realm] () !webidl.Value {
		binding_validate_key(key, normalized.name, .encapsulate_bits)!
		bits := MLKEM.create().encapsulate(AlgorithmParams{ name: normalized.name }, key)!
		return webidl.object_value(encapsulated_bits(realm, bits))
	}, true)
}

pub fn (binding &SubtleCryptoBinding) encapsulate_key(algorithm webidl.Value, key &CryptoKey, shared_algorithm webidl.Value, extractable bool, usages []KeyUsage) &webidl.Promise {
	normalized := normalize_binding_algorithm(algorithm, 'encapsulate') or { return binding.rejected(err.msg()) }
	shared_params := normalize_binding_algorithm(shared_algorithm, 'importKey') or { return binding.rejected(err.msg()) }
	copied_usages := usages.clone()
	realm := binding.context.realm_id.str()
	return binding.run(fn [normalized, key, shared_params, extractable, copied_usages, realm] () !webidl.Value {
		binding_validate_key(key, normalized.name, .encapsulate_key)!
		bits := MLKEM.create().encapsulate(AlgorithmParams{ name: normalized.name }, key)!
		shared_bytes := bits.shared_key or { return error('OperationError: Encapsulation produced no shared key') }
		mut shared_key := normalized_import(shared_params, .raw_secret, shared_bytes, extractable, copied_usages)!
		shared_key.set_extractable(extractable)
		shared_key.set_usages(normalize_key_usages(copied_usages))
		return webidl.object_value(encapsulated_key(realm, EncapsulatedKey{ shared_key: shared_key, ciphertext: bits.ciphertext }))
	}, true)
}

pub fn (binding &SubtleCryptoBinding) decapsulate_bits(algorithm webidl.Value, key &CryptoKey, ciphertext webidl.BufferSource) &webidl.Promise {
	bytes := webidl.get_buffer_source_copy(ciphertext)
	normalized := normalize_binding_algorithm(algorithm, 'decapsulate') or { return binding.rejected(err.msg()) }
	return binding.run(fn [normalized, key, bytes] () !webidl.Value {
		binding_validate_key(key, normalized.name, .decapsulate_bits)!
		return crypto_buffer_value(MLKEM.create().decapsulate(AlgorithmParams{ name: normalized.name }, key, bytes)!)
	}, true)
}

pub fn (binding &SubtleCryptoBinding) decapsulate_key(algorithm webidl.Value, key &CryptoKey, ciphertext webidl.BufferSource, shared_algorithm webidl.Value, extractable bool, usages []KeyUsage) &webidl.Promise {
	bytes := webidl.get_buffer_source_copy(ciphertext)
	normalized := normalize_binding_algorithm(algorithm, 'decapsulate') or { return binding.rejected(err.msg()) }
	shared_params := normalize_binding_algorithm(shared_algorithm, 'importKey') or { return binding.rejected(err.msg()) }
	copied_usages := usages.clone()
	realm := binding.context.realm_id.str()
	return binding.run(fn [normalized, key, bytes, shared_params, extractable, copied_usages, realm] () !webidl.Value {
		binding_validate_key(key, normalized.name, .decapsulate_key)!
		shared_bytes := MLKEM.create().decapsulate(AlgorithmParams{ name: normalized.name }, key, bytes)!
		mut shared_key := normalized_import(shared_params, .raw_secret, shared_bytes, extractable, copied_usages)!
		shared_key.set_extractable(extractable)
		shared_key.set_usages(normalize_key_usages(copied_usages))
		return crypto_key(realm, shared_key)
	}, true)
}
