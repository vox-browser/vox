// Copyright (c) 2026, Ladybird contributors
//
// SPDX-License-Identifier: BSD-2-Clause

// Realm-scoped CryptoKey binding objects translated from CryptoKey.cpp.
@[has_globals]
module webcrypto

import webidl

@[heap]
struct CryptoKeyCacheEntry {
	key_address u64
mut:
	live              bool = true
	algorithm_objects map[string]webidl.Value
	usages_objects    map[string]webidl.Value
}

__global crypto_key_cache_entries_ = []&CryptoKeyCacheEntry{}
__global crypto_key_object_id_ = u64(1)

fn crypto_key_caches() []&CryptoKeyCacheEntry {
	return crypto_key_cache_entries_.clone()
}

fn prune_crypto_key_caches() {
	mut live_entries := []&CryptoKeyCacheEntry{cap: crypto_key_cache_entries_.len}
	for entry in crypto_key_caches() {
		if entry.live {
			live_entries << entry
		}
	}
	crypto_key_cache_entries_ = live_entries.clone()
}

fn cache_for(key &CryptoKey) &CryptoKeyCacheEntry {
	prune_crypto_key_caches()
	address := u64(voidptr(key))
	for entry in crypto_key_cache_entries_ {
		if entry.key_address == address {
			return entry
		}
	}
	entry := &CryptoKeyCacheEntry{
		key_address: address
	}
	crypto_key_cache_entries_ << entry
	return entry
}

fn next_crypto_key_object_id() u64 {
	id := crypto_key_object_id_
	crypto_key_object_id_++
	return id
}

fn create_uint8_array_from_bytes(_ string, bytes []u8) !webidl.Value {
	array := webidl.BufferSource.view(.uint8_array, bytes, 0, u32(bytes.len))!
	return webidl.buffer_source_value_with_id(array, next_crypto_key_object_id())
}

fn create_key_algorithm_object(_ string, name string) webidl.Value {
	return webidl.object_value_with_id({
		'name': webidl.string_value(name)
	}, next_crypto_key_object_id())
}

fn create_algorithm_object(realm string, algorithm CryptoKeyAlgorithm) !webidl.Value {
	mut properties := {
		'name': webidl.string_value(algorithm.name())
	}
	match algorithm {
		RsaKeyAlgorithm {
			properties['modulusLength'] = webidl.number_value(algorithm.modulus_length)
			properties['publicExponent'] = create_uint8_array_from_bytes(realm, algorithm.public_exponent)!
		}
		RsaHashedKeyAlgorithm {
			properties['modulusLength'] = webidl.number_value(algorithm.modulus_length)
			properties['publicExponent'] = create_uint8_array_from_bytes(realm, algorithm.public_exponent)!
			properties['hash'] = create_key_algorithm_object(realm, algorithm.hash)
		}
		EcKeyAlgorithm {
			properties['namedCurve'] = webidl.string_value(algorithm.named_curve)
		}
		AesKeyAlgorithm {
			properties['length'] = webidl.number_value(algorithm.length)
		}
		HmacKeyAlgorithm {
			properties['hash'] = create_key_algorithm_object(realm, algorithm.hash)
			properties['length'] = webidl.number_value(algorithm.length)
		}
		KmacKeyAlgorithm {
			properties['length'] = webidl.number_value(algorithm.length)
		}
		KeyAlgorithm {}
	}
	return webidl.object_value_with_id(properties, next_crypto_key_object_id())
}

fn invalidate_crypto_key_algorithm_cache(key &CryptoKey) {
	address := u64(voidptr(key))
	for mut entry in crypto_key_cache_entries_ {
		if entry.key_address == address {
			entry.algorithm_objects.clear()
			return
		}
	}
}

fn release_crypto_key_caches(key &CryptoKey) {
	address := u64(voidptr(key))
	for mut entry in crypto_key_cache_entries_ {
		if entry.key_address == address {
			entry.live = false
		}
	}
	prune_crypto_key_caches()
}

pub fn (key &CryptoKey) algorithm_for_realm(realm string) !webidl.Value {
	mut cache := cache_for(key)
	if object := cache.algorithm_objects[realm] {
		return object
	}
	object := create_algorithm_object(realm, key.algorithm)!
	cache.algorithm_objects[realm] = object
	return object
}

pub fn (key &CryptoKey) algorithm(realm string) !webidl.Value {
	return key.algorithm_for_realm(realm)
}

pub fn (key &CryptoKey) usages_for_realm(realm string) webidl.Value {
	mut cache := cache_for(key)
	if object := cache.usages_objects[realm] {
		return object
	}
	mut usages := []webidl.Value{cap: key.usages.len}
	for usage in key.usages {
		usages << webidl.string_value(key_usage_to_string(usage))
	}
	object := webidl.frozen_sequence_value_with_id(usages, next_crypto_key_object_id())
	cache.usages_objects[realm] = object
	return object
}

pub fn (key &CryptoKey) usages(realm string) webidl.Value {
	return key.usages_for_realm(realm)
}
