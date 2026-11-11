// SPDX-License-Identifier: BSD-2-Clause
module webcrypto

import encoding.hex
import webidl

// Exact fixtures from upstream WPT ecdsa_vectors.js.
fn ec_wpt_key_pair(curve string) CryptoKeyPair {
	mut d := []u8{}
	mut x := []u8{}
	mut y := []u8{}
	match curve {
		'P-256' {
			d = hex.decode('e6eecf9e626cca8e18079b92c5ee269e54ca128eafd48947ff51aba00ac0e5d6') or { panic(err) }
			x = hex.decode('0a051e386f67c4a6e1e5cbee7d37745b588ebe720f755916286f9629697a3917') or { panic(err) }
			y = hex.decode('11d86aeac96708d23a2623d8c6edbb54d9a43f64066931800f351d9e75ebee1e') or { panic(err) }
		}
		'P-384' {
			d = hex.decode('02a9a0d899efa87e7564110907e9d82c21bd6265a37abd9a6fdb0f80ec844dd3a1425320d67ddc30f5db74efb9a2e661') or { panic(err) }
			x = hex.decode('1d319d692dca5f5754ba7b32c11642c6d8d2b4fb8249c3f214d71e90b5252966d97f7beb1faab1e4f3e2605549c2eedb') or { panic(err) }
			y = hex.decode('520329b3bea6b5e55624a15150a16966635f1916ef04dd758e69409d0633cb4b25994179b22a769c743436910e799951') or { panic(err) }
		}
		'P-521' {
			d = hex.decode('01533e618f98ead1b513ec8878c8820d377a36d8f03f2ba046c931825a3d358730c0b26033dbb7f7e4a3d4434a035e24b707f9124766176e1af0b85df22eaaba9c25') or { panic(err) }
			x = hex.decode('00a6deecfb489117f1e41cc4a064073d8673086e51db25086e8db764d4eff60aad6358fdcf967ac68459275e2a804f8eeeb7e4c4284b1451c0a5ea76fe7007ac0547') or { panic(err) }
			y = hex.decode('01c5eddaf9a89e7c4fdcc924c737d8f585da9703a954c23be7c14aafa66654b256770a938e7f26e700c603931c7bd0bdb5d0632c7d1eab466f09d976c24a323e1b7c') or { panic(err) }
		}
		else { panic('curve') }
	}
	point := EcPublicKeyHandle{ x: x, y: y }
	algorithm := EcKeyAlgorithm{ name: 'ECDSA', named_curve: curve }
	return CryptoKeyPair{
		public_key:  CryptoKey.create_with_internal_handle(.public_key, true, algorithm, [.verify], point)
		private_key: CryptoKey.create_with_internal_handle(.private_key, true, algorithm, [.sign], EcPrivateKeyHandle{ d: d, public_key: point })
	}
}

fn test_ecdsa_verifies_every_source_curve_and_hash_vector() {
	message := hex.decode('5f4dba4f320c0ce876725afce5fbd25bf83e5a7125a08cafe73c3ebac421779df9d55d180c3ae9942645e1d82fee8c9d294b3cb1a08a9931201b3c0e81fc47cacf8315a2af66324113c3b66230c34608c4f4593634ce02b267362277f0a840ca74bc3d1a6236952c5ed7aaf8a8fecbddfa7584e6978cea5d2a5b9fb7f1b48c8b0be58a305202754d8376107374793cf026aaee5300727d836cd71e71b345ddb2e44446ffc5b901635413890d910ea380984a90191031323f16dbcc9d6be168b84885384ca03e12600ac1c248028af3726cc93463882ea8c02aab')!
	pair0 := ec_wpt_key_pair('P-256')
	signature0 := hex.decode('ace07daa34539eb3559582d93bc900fbedc433f3dae7d3889df9db108cb29110b16844b35831dbb8d4ca6df86e40ca8107ade258c245a49e78788003730eb5c5')!
	assert SubtleCrypto.create().verify(EcdsaParams{ hash: 'sha-1' }, pair0.public_key, signature0, message)!
	assert !SubtleCrypto.create().verify(EcdsaParams{ hash: 'SHA-1' }, pair0.public_key, signature0, 'bad'.bytes())!
	pair1 := ec_wpt_key_pair('P-256')
	signature1 := hex.decode('53df3fe22a1d6a69e191c5b4769a6d6e42432ffb35becb41cf241339317a7c763b4ade862aebb4e58618cd51ab9c64da7ff27e351b4df9659d84f41e431e400c')!
	assert SubtleCrypto.create().verify(EcdsaParams{ hash: 'sha-256' }, pair1.public_key, signature1, message)!
	assert !SubtleCrypto.create().verify(EcdsaParams{ hash: 'SHA-256' }, pair1.public_key, signature1, 'bad'.bytes())!
	pair2 := ec_wpt_key_pair('P-256')
	signature2 := hex.decode('eb6fadf997fcda817b75881aa273f76ea9915fbde4622052225e9ac52f537c89d747def78716ddee4df7dfc22a9eafe04cb6388a61c4ee6d2a660d47012b385c')!
	assert SubtleCrypto.create().verify(EcdsaParams{ hash: 'sha-384' }, pair2.public_key, signature2, message)!
	assert !SubtleCrypto.create().verify(EcdsaParams{ hash: 'SHA-384' }, pair2.public_key, signature2, 'bad'.bytes())!
	pair3 := ec_wpt_key_pair('P-256')
	signature3 := hex.decode('4ac9afad456ba08ecb29e105499206285d8281239cabbea10c0aea7b0705706139b70f345ed74fffafde42eafdb43ea1070bf92576b90d66435465bd49846ece')!
	assert SubtleCrypto.create().verify(EcdsaParams{ hash: 'sha-512' }, pair3.public_key, signature3, message)!
	assert !SubtleCrypto.create().verify(EcdsaParams{ hash: 'SHA-512' }, pair3.public_key, signature3, 'bad'.bytes())!
	pair4 := ec_wpt_key_pair('P-384')
	signature4 := hex.decode('65fe070ec3eac35250d00b9ee6db4d2dadd5f3bbb9c495c8671d2a0d2b99149fb24f88af074e0b903268b3d0ed5f0e14685796b28fe34b2d8edcdf10845b24cf79b33627d8bd2c81621cb51e030c21a43abb0a8740fac26f8522e683c367ac96')!
	assert SubtleCrypto.create().verify(EcdsaParams{ hash: 'sha-1' }, pair4.public_key, signature4, message)!
	assert !SubtleCrypto.create().verify(EcdsaParams{ hash: 'SHA-1' }, pair4.public_key, signature4, 'bad'.bytes())!
	pair5 := ec_wpt_key_pair('P-384')
	signature5 := hex.decode('4bc2dfea3bcda4fbb4fd927b030f9b80b1f5d2ad9bb7aa06293869577120b2b1d0ef11ccd9fed0714aab36bef63928f784f53c7e09df93e9b3e5b0c883cf720951b4fe2382c7842edcfcd45d956a72d29a4030a038a900e6f7dd857a5650d3e8')!
	assert SubtleCrypto.create().verify(EcdsaParams{ hash: 'sha-256' }, pair5.public_key, signature5, message)!
	assert !SubtleCrypto.create().verify(EcdsaParams{ hash: 'SHA-256' }, pair5.public_key, signature5, 'bad'.bytes())!
	pair6 := ec_wpt_key_pair('P-384')
	signature6 := hex.decode('0dd9c2c7f0b6f4d9328254a902e87374b3c092195e6be21aa1a6dcd8eba60f7b0b38c4006dfa2146d4e9fd23dc336179974017493a1f4f74eecfe455be3da9ed99641d81610dfeb468b607da941d5714e7b51aee2c45aa0e9c4da021b2370090')!
	assert SubtleCrypto.create().verify(EcdsaParams{ hash: 'sha-384' }, pair6.public_key, signature6, message)!
	assert !SubtleCrypto.create().verify(EcdsaParams{ hash: 'SHA-384' }, pair6.public_key, signature6, 'bad'.bytes())!
	pair7 := ec_wpt_key_pair('P-384')
	signature7 := hex.decode('72fbdb369fd34c1c54264d07f4facd69b02e4206f8a8bb259b882a305c56fde2d35107e493c53cd6b4af0b31306f4d03fd43cfc762a1030e17a3d775453a1212b1429f7b3d93066a5f42a10b138cd177dc09616e827d598822d78d4627b754e6')!
	assert SubtleCrypto.create().verify(EcdsaParams{ hash: 'sha-512' }, pair7.public_key, signature7, message)!
	assert !SubtleCrypto.create().verify(EcdsaParams{ hash: 'SHA-512' }, pair7.public_key, signature7, 'bad'.bytes())!
	pair8 := ec_wpt_key_pair('P-521')
	signature8 := hex.decode('01781a17a60e43126960fd396e1210916c2115ca4428d968389c4b46c1553674ce937b8e21700ce60932ae0f575ca187dd597720db839eb1f20c7e3394787559dcd500207e570df5c7e4ad9fc0a5f72065e9ce1c9e3d12ca5e6dd9f44fe128561b75f4226c4fadf23d83536cc669ea4098e373b6cb919c8b5cfc0505a67d96b276a46a3d')!
	assert SubtleCrypto.create().verify(EcdsaParams{ hash: 'sha-1' }, pair8.public_key, signature8, message)!
	assert !SubtleCrypto.create().verify(EcdsaParams{ hash: 'SHA-1' }, pair8.public_key, signature8, 'bad'.bytes())!
	pair9 := ec_wpt_key_pair('P-521')
	signature9 := hex.decode('0174dba77b14d73f66f5716786a3e5a8d7c931445e6d320a9229d961d8a1b3efd11a5ea33c79495ac599bbb68a641a849d58d83ef854cc265fa6c917dff6ee435a6701b3d5527dac20fb0a7033c3fe79744eacef7b3ffc27b64dc863f86f42982cb2229245fe9de48aa59eb653d4497086d911a5bd270e95c51e7e98f7a5863fc7fb065c')!
	assert SubtleCrypto.create().verify(EcdsaParams{ hash: 'sha-256' }, pair9.public_key, signature9, message)!
	assert !SubtleCrypto.create().verify(EcdsaParams{ hash: 'SHA-256' }, pair9.public_key, signature9, 'bad'.bytes())!
	pair10 := ec_wpt_key_pair('P-521')
	signature10 := hex.decode('01f77db1e51378e117c5b8bec8a03f9657d244c54e837908bf7101255f4151525d9e89cf7f54631b3368919d3824ff9f7f78fe81239a1a9fde2b7a83e95ca6a0ca1101b98b1da4ed00ec769367e9958b8047d47f92ab8bff96f1330bf948c92209011b8cdbb496d464dbb916720eb702bdad928c99b980b76504e0ad1c12b4a85731c70c')!
	assert SubtleCrypto.create().verify(EcdsaParams{ hash: 'sha-384' }, pair10.public_key, signature10, message)!
	assert !SubtleCrypto.create().verify(EcdsaParams{ hash: 'SHA-384' }, pair10.public_key, signature10, 'bad'.bytes())!
	pair11 := ec_wpt_key_pair('P-521')
	signature11 := hex.decode('00b2caaf6798519a9d36dbfafe786b2fba1cc2acb99593c177b36e3a1ceeb702275ae23cfcca0aad78f6b6dee6b4718b95d0d1a715aa3378470e50b516c18e0f330501f0071e6a32867fa70f695cd39c4e87e142b9e4134d38740bd6fee354a575167e13524e94832637910fe11e53a85fb21b91adb81bb1779c4e2b8bc87c717dc35084')!
	assert SubtleCrypto.create().verify(EcdsaParams{ hash: 'sha-512' }, pair11.public_key, signature11, message)!
	assert !SubtleCrypto.create().verify(EcdsaParams{ hash: 'SHA-512' }, pair11.public_key, signature11, 'bad'.bytes())!
}

fn test_ecdsa_actual_signing_and_source_signature_split() {
	for curve in ['P-256', 'P-384', 'P-521'] {
		pair := ec_wpt_key_pair(curve)
		for hash in ['SHA-1', 'SHA-256', 'SHA-384', 'SHA-512'] {
			params := EcdsaParams{ hash: hash }
			signature := SubtleCrypto.create().sign(params, pair.private_key, 'message'.bytes())!
			assert signature.len == ec_scalar_size(curve) * 2
			assert SubtleCrypto.create().verify(params, pair.public_key, signature, 'message'.bytes())!
			mut odd := signature.clone()
			odd << u8(0xaa)
			assert ECDSA.create().verify(params, pair.public_key, odd, 'message'.bytes())!
			assert !ECDSA.create().verify(params, pair.public_key, signature[..signature.len - 1], 'message'.bytes())!
			assert !ECDSA.create().verify(params, pair.public_key, [], 'message'.bytes())!
			assert !ECDSA.create().verify(params, pair.public_key, []u8{len: signature.len}, 'message'.bytes())!
		}
	}
	pair := ec_wpt_key_pair('P-256')
	if _ := ECDSA.create().sign(EcdsaParams{ hash: 'bad' }, pair.public_key, []) {
		assert false
	} else {
		assert err.msg() == 'InvalidAccessError: Key is not a private key'
	}
	if _ := ECDSA.create().verify(EcdsaParams{ hash: 'bad' }, pair.public_key, [], []) {
		assert false
	} else {
		assert err.msg() == "NotSupportedError: Invalid hash function 'bad'"
	}
	if _ := SubtleCrypto.create().sign('ECDSA', pair.private_key, []) {
		assert false
	} else {
		assert err.msg() == 'TypeError: hash is required'
	}
}

fn test_ecdh_matches_upstream_coordinate_and_truncates_nullable_bits() {
	algorithm256 := EcKeyAlgorithm{ name: 'ECDH', named_curve: 'P-256' }
	public256 := hex.decode('047cf27b188d034f7e8a52380304b51ac3c08969e277f21b35a60b48fc4766997807775510db8ed040293d9ac69f7430dbba7dade63ce982299e04b79d227873d1')!
	private256 := CryptoKey.create_with_internal_handle(.private_key, false, algorithm256, [
		.derive_bits,
		.derive_key,
	], EcPrivateKeyHandle{ d: hex.decode('0000000000000000000000000000000000000000000000000000000000000001')! })
	point256 := CryptoKey.create_with_internal_handle(.public_key, true, algorithm256, [], EcPublicKeyHandle{ x: public256[1..33].clone(), y: public256[33..].clone() })
	params256 := EcdhKeyDeriveParams{ name: 'ECDH', public_key: point256 }
	secret256 := hex.decode('7cf27b188d034f7e8a52380304b51ac3c08969e277f21b35a60b48fc47669978')!
	assert SubtleCrypto.create().derive_bits(params256, private256, none)! == secret256
	assert SubtleCrypto.create().derive_bits(params256, private256, 0)!.len == 0
	assert SubtleCrypto.create().derive_bits(params256, private256, 9)! == [
		secret256[0],
		secret256[1] & 0x80,
	]
	if _ := SubtleCrypto.create().derive_bits(params256, private256, 257) {
		assert false
	} else {
		assert err.msg() == 'OperationError: Length is too large'
	}
	derived256 := SubtleCrypto.create().derive_key(params256, private256, 'AES-GCM', 128, false, [.encrypt])!
	assert derived256.handle() == secret256[..16]
	algorithm384 := EcKeyAlgorithm{ name: 'ECDH', named_curve: 'P-384' }
	public384 := hex.decode('0408d999057ba3d2d969260045c55b97f089025959a6f434d651d207d19fb96e9e4fe0e86ebe0e64f85b96a9c75295df618e80f1fa5b1b3cedb7bfe8dffd6dba74b275d875bc6cc43e904e505f256ab4255ffd43e94d39e22d61501e700a940e80')!
	private384 := CryptoKey.create_with_internal_handle(.private_key, false, algorithm384, [
		.derive_bits,
		.derive_key,
	], EcPrivateKeyHandle{ d: hex.decode('000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001')! })
	point384 := CryptoKey.create_with_internal_handle(.public_key, true, algorithm384, [], EcPublicKeyHandle{ x: public384[1..49].clone(), y: public384[49..].clone() })
	params384 := EcdhKeyDeriveParams{ name: 'ECDH', public_key: point384 }
	secret384 := hex.decode('08d999057ba3d2d969260045c55b97f089025959a6f434d651d207d19fb96e9e4fe0e86ebe0e64f85b96a9c75295df61')!
	assert SubtleCrypto.create().derive_bits(params384, private384, none)! == secret384
	assert SubtleCrypto.create().derive_bits(params384, private384, 0)!.len == 0
	assert SubtleCrypto.create().derive_bits(params384, private384, 9)! == [
		secret384[0],
		secret384[1] & 0x80,
	]
	if _ := SubtleCrypto.create().derive_bits(params384, private384, 385) {
		assert false
	} else {
		assert err.msg() == 'OperationError: Length is too large'
	}
	derived384 := SubtleCrypto.create().derive_key(params384, private384, 'AES-GCM', 128, false, [.encrypt])!
	assert derived384.handle() == secret384[..16]
	algorithm521 := EcKeyAlgorithm{ name: 'ECDH', named_curve: 'P-521' }
	public521 := hex.decode('0400433c219024277e7e682fcb288148c282747403279b1ccc06352c6e5505d769be97b3b204da6ef55507aa104a3a35c5af41cf2fa364d60fd967f43e3933ba6d783d00f4bb8cc7f86db26700a7f3eceeeed3f0b5c6b5107c4da97740ab21a29906c42dbbb3e377de9f251f6b93937fa99a3248f4eafcbe95edc0f4f71be356d661f41b02')!
	private521 := CryptoKey.create_with_internal_handle(.private_key, false, algorithm521, [
		.derive_bits,
		.derive_key,
	], EcPrivateKeyHandle{ d: hex.decode('000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001')! })
	point521 := CryptoKey.create_with_internal_handle(.public_key, true, algorithm521, [], EcPublicKeyHandle{ x: public521[1..67].clone(), y: public521[67..].clone() })
	params521 := EcdhKeyDeriveParams{ name: 'ECDH', public_key: point521 }
	secret521 := hex.decode('00433c219024277e7e682fcb288148c282747403279b1ccc06352c6e5505d769be97b3b204da6ef55507aa104a3a35c5af41cf2fa364d60fd967f43e3933ba6d783d')!
	assert SubtleCrypto.create().derive_bits(params521, private521, none)! == secret521
	assert SubtleCrypto.create().derive_bits(params521, private521, 0)!.len == 0
	assert SubtleCrypto.create().derive_bits(params521, private521, 9)! == [
		secret521[0],
		secret521[1] & 0x80,
	]
	if _ := SubtleCrypto.create().derive_bits(params521, private521, 529) {
		assert false
	} else {
		assert err.msg() == 'OperationError: Length is too large'
	}
	derived521 := SubtleCrypto.create().derive_key(params521, private521, 'AES-GCM', 128, false, [.encrypt])!
	assert derived521.handle() == secret521[..16]
}

fn test_ecdh_rejects_source_public_and_curve_mismatches() {
	a := SubtleCrypto.create().generate_key(EcKeyGenParams{ name: 'ECDH', named_curve: 'P-256' }, false, [.derive_bits])!.pair or { panic('pair') }
	b := SubtleCrypto.create().generate_key(EcKeyGenParams{ name: 'ECDH', named_curve: 'P-384' }, false, [.derive_bits])!.pair or { panic('pair') }
	if _ := ECDH.create().derive_bits(EcdhKeyDeriveParams{ name: 'ECDH', public_key: a.private_key }, a.private_key, none) {
		assert false
	} else {
		assert err.msg() == 'InvalidAccessError: Public key is not a public key'
	}
	if _ := ECDH.create().derive_bits(EcdhKeyDeriveParams{ name: 'ECDH', public_key: b.public_key }, a.private_key, none) {
		assert false
	} else {
		assert err.msg() == 'InvalidAccessError: Curve mismatch'
	}
	c := ec_wpt_key_pair('P-256')
	if _ := ECDH.create().derive_bits(EcdhKeyDeriveParams{ name: 'ECDH', public_key: c.public_key }, a.private_key, none) {
		assert false
	} else {
		assert err.msg() == 'InvalidAccessError: Algorithm mismatch'
	}
	invalid := CryptoKey.create_with_internal_handle(.public_key, true, a.public_key.algorithm, [], EcPublicKeyHandle{ x: [u8(0)], y: [u8(0)] })
	if _ := ECDH.create().derive_bits(EcdhKeyDeriveParams{ name: 'ECDH', public_key: invalid }, a.private_key, none) {
		assert false
	} else {
		assert err.msg() == 'OperationError: Failed to compute secret: Invalid point size for curve'
	}
	// Correct-width coordinates still reach and exercise native point validation.
	off_curve := CryptoKey.create_with_internal_handle(.public_key, true, a.public_key.algorithm, [], EcPublicKeyHandle{ x: []u8{len: 32}, y: []u8{len: 32} })
	if _ := ECDH.create().derive_bits(EcdhKeyDeriveParams{ name: 'ECDH', public_key: off_curve }, a.private_key, none) {
		assert false
	} else {
		assert err.msg().starts_with('OperationError: Failed to compute secret: EC_POINT_set_affine_coordinates')
	}
}

@[heap]
struct EcOperationsBindingHost {
mut:
	work   []fn ()
	settle []fn ()
}

fn test_ecdsa_binding_copies_message_and_hash_then_queues_settlement() {
	mut host := &EcOperationsBindingHost{}
	binding := SubtleCryptoBinding.create(SubtleCrypto.create(), webidl.PromiseContext{}, fn [mut host] (task fn ()) {
		host.work << task
	}, fn [mut host] (task fn ()) { host.settle << task })
	pair := ec_wpt_key_pair('P-256')
	mut message := webidl.BufferSource.array_buffer('message'.bytes())
	mut hash := {
		'name': webidl.string_value('SHA-256')
	}
	algorithm := webidl.object_value({
		'name': webidl.string_value('ECDSA')
		'hash': webidl.object_value(hash)
	})
	promise := binding.sign(algorithm, pair.private_key, message)
	message.write('badtext'.bytes(), 0)!
	hash['name'] = webidl.string_value('SHA-512')
	host.work[0]()
	assert promise.state == .pending && host.settle.len == 1
	host.settle[0]()
	assert promise.state == .fulfilled
	signature := promise.result.buffer_value or { panic('signature') }
	assert ECDSA.create().verify(EcdsaParams{ hash: 'SHA-256' }, pair.public_key, webidl.get_buffer_source_copy(signature), 'message'.bytes())!
}
