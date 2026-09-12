// Copyright (c) 2026, Ladybird contributors
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of Crypto/CryptoKey.{h,cpp}.
module webcrypto

pub enum CryptoKeyHandleKind {
	bytes
	json_web_key
}

// Structured serialization copies these four internal slots. Ladybird leaves
// [[handle]] out pending a backend-specific serialization strategy.
pub struct SerializedCryptoKey {
pub:
	type_       KeyType
	extractable bool
	algorithm   CryptoKeyAlgorithm
	usages      []KeyUsage
}

@[heap]
pub struct CryptoKey {
pub mut:
	type_       KeyType
	extractable bool
	algorithm   CryptoKeyAlgorithm
	usages      []KeyUsage
mut:
	handle_     []u8
	jwk_handle_ ?JsonWebKey
	destroyed_  bool
}

pub fn CryptoKey.create(type_ KeyType, extractable bool, algorithm CryptoKeyAlgorithm, usages []KeyUsage, handle []u8) &CryptoKey {
	return &CryptoKey{
		type_:       type_
		extractable: extractable
		algorithm:   clone_key_algorithm(algorithm)
		usages:      usages.clone()
		handle_:     handle.clone()
	}
}

pub fn CryptoKey.create_empty() &CryptoKey {
	return CryptoKey.create(.public_key, false, KeyAlgorithm{}, []KeyUsage{}, []u8{})
}

fn clone_json_web_key(key JsonWebKey) JsonWebKey {
	return JsonWebKey{
		kty:     key.kty
		use:     key.use
		key_ops: if values := key.key_ops { values.clone() } else { none }
		alg:     key.alg
		ext:     key.ext
		crv:     key.crv
		x:       key.x
		y:       key.y
		d:       key.d
		n:       key.n
		e:       key.e
		p:       key.p
		q:       key.q
		dp:      key.dp
		dq:      key.dq
		qi:      key.qi
		oth:     if values := key.oth { values.clone() } else { none }
		k:       key.k
		pub_:    key.pub_
		priv:    key.priv
	}
}

pub fn CryptoKey.create_from_json_web_key(type_ KeyType, extractable bool, algorithm CryptoKeyAlgorithm, usages []KeyUsage, handle JsonWebKey) &CryptoKey {
	return &CryptoKey{
		type_:       type_
		extractable: extractable
		algorithm:   clone_key_algorithm(algorithm)
		usages:      usages.clone()
		jwk_handle_: clone_json_web_key(handle)
	}
}

pub fn (mut key CryptoKey) set_extractable(extractable bool) {
	key.extractable = extractable
}

pub fn (mut key CryptoKey) set_type(type_ KeyType) {
	key.type_ = type_
}

pub fn (mut key CryptoKey) set_algorithm(algorithm CryptoKeyAlgorithm) {
	key.algorithm = clone_key_algorithm(algorithm)
}

pub fn (mut key CryptoKey) set_usages(usages []KeyUsage) {
	// CryptoKey.cpp preserves the supplied vector exactly. Validation and
	// duplicate rejection belong to the individual WebCrypto algorithms.
	key.usages = usages.clone()
}

pub fn (key &CryptoKey) internal_usages() []KeyUsage {
	return key.usages.clone()
}

pub fn (key &CryptoKey) internal_algorithm() CryptoKeyAlgorithm {
	return clone_key_algorithm(key.algorithm)
}

pub fn (key &CryptoKey) rsa_hashed_algorithm() RsaHashedKeyAlgorithm {
	if key.algorithm is RsaHashedKeyAlgorithm {
		return key.algorithm
	}
	panic('CryptoKey algorithm is not an RSA hashed algorithm')
}

pub fn (key &CryptoKey) ec_algorithm() EcKeyAlgorithm {
	if key.algorithm is EcKeyAlgorithm {
		return key.algorithm
	}
	panic('CryptoKey algorithm is not an EC algorithm')
}

pub fn (key &CryptoKey) hmac_algorithm() HmacKeyAlgorithm {
	if key.algorithm is HmacKeyAlgorithm {
		return key.algorithm
	}
	panic('CryptoKey algorithm is not an HMAC algorithm')
}

pub fn (key &CryptoKey) handle() []u8 {
	return key.handle_.clone()
}

pub fn (key &CryptoKey) json_web_key_handle() ?JsonWebKey {
	if handle := key.jwk_handle_ {
		return clone_json_web_key(handle)
	}
	return none
}

pub fn (key &CryptoKey) handle_kind() CryptoKeyHandleKind {
	return if key.jwk_handle_ != none { .json_web_key } else { .bytes }
}

pub fn (key &CryptoKey) algorithm_name() string {
	return key.algorithm.name()
}

pub fn (key &CryptoKey) bindings_type() KeyType {
	return key.type_
}

pub fn (key &CryptoKey) permits(usage KeyUsage) bool {
	return usage in key.usages
}

pub fn (key &CryptoKey) serialization_steps() SerializedCryptoKey {
	return SerializedCryptoKey{
		type_:       key.type_
		extractable: key.extractable
		algorithm:   clone_key_algorithm(key.algorithm)
		usages:      key.usages.clone()
	}
}

pub fn (key &CryptoKey) serialize() SerializedCryptoKey {
	return key.serialization_steps()
}

pub fn CryptoKey.deserialize(serialized SerializedCryptoKey) &CryptoKey {
	// CryptoKey.cpp likewise creates an empty handle because step 5 remains a
	// FIXME upstream.
	return CryptoKey.create(serialized.type_, serialized.extractable, serialized.algorithm,
		serialized.usages, []u8{})
}

pub fn (mut key CryptoKey) deserialization_steps(serialized SerializedCryptoKey) {
	key.type_ = serialized.type_
	key.extractable = serialized.extractable
	key.algorithm = clone_key_algorithm(serialized.algorithm)
	key.usages = serialized.usages.clone()
	for mut byte in key.handle_ {
		byte = 0
	}
	key.handle_.clear()
	key.jwk_handle_ = none
	key.destroyed_ = false
}

pub fn (key &CryptoKey) clone_key() &CryptoKey {
	if handle := key.jwk_handle_ {
		return CryptoKey.create_from_json_web_key(key.type_, key.extractable, key.algorithm,
			key.usages, handle)
	}
	return CryptoKey.create(key.type_, key.extractable, key.algorithm, key.usages, key.handle_)
}

// V does not expose a per-object finalizer. Embedders call destroy when a key
// leaves their ownership; this performs CryptoKey::finalize's secure clearing.
pub fn (mut key CryptoKey) destroy() {
	if key.destroyed_ {
		return
	}
	for mut byte in key.handle_ {
		byte = 0
	}
	key.handle_.clear()
	key.jwk_handle_ = none
	key.destroyed_ = true
}

pub fn (key &CryptoKey) destroyed() bool {
	return key.destroyed_
}

pub struct CryptoKeyPair {
pub:
	public_key  &CryptoKey
	private_key &CryptoKey
}

pub fn CryptoKeyPair.create(public_key &CryptoKey, private_key &CryptoKey) &CryptoKeyPair {
	return &CryptoKeyPair{
		public_key:  public_key
		private_key: private_key
	}
}

pub fn (pair &CryptoKeyPair) public_key_value() &CryptoKey {
	return pair.public_key
}

pub fn (pair &CryptoKeyPair) private_key_value() &CryptoKey {
	return pair.private_key
}
