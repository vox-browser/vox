module webcrypto

import webidl

fn test_get_public_key_matches_all_supported_generated_key_families() {
	subtle := SubtleCrypto.create()
	parameters := [
		KeyGenerationParams(EcKeyGenParams{ name: 'ECDSA', named_curve: 'P-256' }),
		KeyGenerationParams(EcKeyGenParams{ name: 'ECDH', named_curve: 'P-384' }),
		KeyGenerationParams(RsaHashedKeyGenParams{ name: 'RSA-OAEP', modulus_length: 1024, public_exponent: [u8(1), 0, 1], hash: 'SHA-256' }),
		KeyGenerationParams(RsaHashedKeyGenParams{ name: 'RSA-PSS', modulus_length: 1024, public_exponent: [u8(1), 0, 1], hash: 'SHA-384' }),
		KeyGenerationParams(RsaHashedKeyGenParams{ name: 'RSASSA-PKCS1-v1_5', modulus_length: 1024, public_exponent: [u8(1), 0, 1], hash: 'SHA-512' }),
		KeyGenerationParams(AlgorithmParams{ name: 'Ed25519' }),
		KeyGenerationParams(AlgorithmParams{ name: 'Ed448' }),
		KeyGenerationParams(AlgorithmParams{ name: 'X25519' }),
		KeyGenerationParams(AlgorithmParams{ name: 'X448' }),
		KeyGenerationParams(AlgorithmParams{ name: 'ML-DSA-44' }),
		KeyGenerationParams(AlgorithmParams{ name: 'ML-DSA-65' }),
		KeyGenerationParams(AlgorithmParams{ name: 'ML-DSA-87' }),
		KeyGenerationParams(AlgorithmParams{ name: 'ML-KEM-512' }),
		KeyGenerationParams(AlgorithmParams{ name: 'ML-KEM-768' }),
		KeyGenerationParams(AlgorithmParams{ name: 'ML-KEM-1024' }),
	]
	for params in parameters {
		name := match params {
			EcKeyGenParams { params.name }
			RsaHashedKeyGenParams { params.name }
			AlgorithmParams { params.name }
			else { panic('unexpected test parameter') }
		}
		usages := if name in ['ECDH', 'X25519', 'X448'] { [KeyUsage.derive_bits] }
			else if name == 'RSA-OAEP' { [KeyUsage.decrypt, .encrypt] }
			else if name.starts_with('ML-KEM-') { [KeyUsage.decapsulate_key, .encapsulate_key] }
			else { [KeyUsage.sign, .verify] }
		generated := subtle.generate_key(params, false, usages)!
		pair := generated.pair or { panic('missing generated pair') }
		requested := public_key_usages(name)!
		mut derived := subtle.get_public_key(pair.private_key, requested)!
		assert !pair.private_key.extractable
		assert derived.type_ == .public_key && derived.extractable
		assert derived.algorithm_name() == name
		assert derived.usages == normalize_key_usages(requested)
		assert voidptr(derived) != voidptr(pair.public_key)
		assert voidptr(derived) != voidptr(subtle.get_public_key(pair.private_key, requested)!)
		matches := subtle.export_key(.spki, derived)! == subtle.export_key(.spki, pair.public_key)!
		assert matches, name
		assert subtle.get_public_key(pair.private_key, [])!.usages.len == 0
		derived.destroy()
		// A new public key owns its handle; destroying it cannot damage either
		// member of the generated pair or later derivations from the private key.
		assert subtle.export_key(.spki, subtle.get_public_key(pair.private_key, requested)!)! == subtle.export_key(.spki, pair.public_key)!
	}
}

fn test_get_public_key_computes_missing_ec_point_and_works_for_imported_private_key() {
	subtle := SubtleCrypto.create()
	generated := subtle.generate_key(EcKeyGenParams{ name: 'ECDSA', named_curve: 'P-256' }, true, [.sign, .verify])!
	pair := generated.pair or { panic('missing generated pair') }
	der := subtle.export_key(.pkcs8, pair.private_key)!
	mut private_key := subtle.import_key(.pkcs8, der, EcKeyImportParams{ name: 'ECDSA', named_curve: 'P-256' }, false, [.sign], '')!
	handle := private_key.internal_handle_ as EcPrivateKeyHandle
	private_key.install_deserialized_internal_handle(EcPrivateKeyHandle{ d: handle.d })
	derived := subtle.get_public_key(private_key, [.verify, .verify])!
	assert derived.usages == [.verify]
	assert !private_key.extractable
	assert subtle.export_key(.spki, derived)! == subtle.export_key(.spki, pair.public_key)!
	message := 'derived key verification'.bytes()
	signature := subtle.sign(EcdsaParams{ name: 'ECDSA', hash: 'SHA-256' }, private_key, message)!
	assert subtle.verify(EcdsaParams{ name: 'ECDSA', hash: 'SHA-256' }, derived, signature, message)!
	assert !subtle.verify(EcdsaParams{ name: 'ECDSA', hash: 'SHA-256' }, derived, signature, 'different'.bytes())!
}

fn test_get_public_key_rejects_unsupported_algorithms_before_type_and_usages() {
	subtle := SubtleCrypto.create()
	for name in ['AES-GCM', 'HMAC', 'HKDF', 'unregistered'] {
		key := CryptoKey.create(.secret, false, KeyAlgorithm{ name: name }, [], [])
		if _ := subtle.get_public_key(key, [.sign]) { assert false }
		else { assert err.msg().starts_with('NotSupportedError:') }
	}
	public_key := CryptoKey.create(.public_key, true, EcKeyAlgorithm{ name: 'ECDSA', named_curve: 'P-256' }, [], [])
	if _ := subtle.get_public_key(public_key, [.encrypt]) { assert false }
	else { assert err.msg().starts_with('InvalidAccessError:') }
	bad_handle := CryptoKey.create(.private_key, false, EcKeyAlgorithm{ name: 'ECDSA', named_curve: 'P-256' }, [.sign], [])
	if _ := subtle.get_public_key(bad_handle, [.verify, .encrypt]) { assert false }
	else { assert err.msg().starts_with('SyntaxError:') }
	if _ := subtle.get_public_key(bad_handle, [.verify]) { assert false }
	else { assert err.msg() == 'OperationError: Failed to derive the public key' }
}

@[heap]
struct PublicKeyWork {
mut:
	deferred []fn ()
	crypto []fn ()
}

fn test_get_public_key_binding_copies_usages_and_settles_on_crypto_tasks() {
	mut work := &PublicKeyWork{}
	binding := SubtleCryptoBinding.create(SubtleCrypto.create(), webidl.PromiseContext{ realm_id: 174 },
		fn [mut work] (task fn ()) { work.deferred << task },
		fn [mut work] (task fn ()) { work.crypto << task })
	mut requested := [KeyUsage.wrap_key, .encrypt, .wrap_key]
	private_key := CryptoKey.create_with_internal_handle(.private_key, false,
		RsaHashedKeyAlgorithm{ name: 'RSA-OAEP', modulus_length: 8, public_exponent: [u8(3)], hash: 'SHA-256' },
		[.decrypt], RsaPrivateKeyHandle{ modulus: [u8(17)], public_exponent: [u8(3)] })
	promise := binding.get_public_key(private_key, requested)
	requested[0] = .sign
	assert promise.state == .pending && work.deferred.len == 1 && work.crypto.len == 0
	work.deferred[0]()
	assert promise.state == .pending && work.crypto.len == 1
	work.crypto[0]()
	assert promise.state == .fulfilled
	key := crypto_key_from_value(promise.result)!
	assert key.usages == [.encrypt, .wrap_key]
	assert key.extractable && key.type_ == .public_key
	unsupported := binding.get_public_key(CryptoKey.create(.secret, false, KeyAlgorithm{ name: 'AES-GCM' }, [], []), [])
	assert unsupported.state == .rejected
	assert unsupported.result.object_value['name'].string_value == 'NotSupportedError'
	assert work.deferred.len == 1
}
