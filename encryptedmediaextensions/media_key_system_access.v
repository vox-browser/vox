// Copyright (c) 2026, Ladybird contributors
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of EncryptedMediaExtensions/MediaKeySystemAccess.cpp and its IDL.
module encryptedmediaextensions

import dom

@[heap]
pub struct MediaKeySystemAccess {
	key_system_        string
	configuration_     MediaKeySystemConfiguration
	cdm_implementation KeySystem
}

pub fn MediaKeySystemAccess.create(key_system string, configuration MediaKeySystemConfiguration, cdm_implementation KeySystem) &MediaKeySystemAccess {
	return &MediaKeySystemAccess{
		key_system_:        key_system
		configuration_:     configuration.clone()
		cdm_implementation: cdm_implementation
	}
}

pub fn (access &MediaKeySystemAccess) key_system() string {
	return access.key_system_
}

pub fn (access &MediaKeySystemAccess) get_configuration() MediaKeySystemConfiguration {
	return access.configuration_.clone()
}

pub fn (access &MediaKeySystemAccess) cdm_implementation() KeySystem {
	return access.cdm_implementation
}

// MediaKeys is intentionally opaque here: Ladybird's IDL marks
// createMediaKeys() FIXME and provides no C++ implementation yet.
@[heap]
pub struct MediaKeys {}

@[heap]
pub struct MediaKeysPromise {
mut:
	state_  dom.PromiseState
	value_  ?&MediaKeys
	reason_ string
}

pub fn (promise &MediaKeysPromise) state() dom.PromiseState {
	return promise.state_
}

pub fn (promise &MediaKeysPromise) value() ?&MediaKeys {
	return promise.value_
}

pub fn (promise &MediaKeysPromise) reason() string {
	return promise.reason_
}

// The IDL operation returns Promise<MediaKeys>, so an unavailable backend is
// represented as a rejected promise rather than a synchronously thrown V
// error. This is the WebIDL-visible boundary for Ladybird's [FIXME] method.
pub fn (access &MediaKeySystemAccess) create_media_keys() &MediaKeysPromise {
	_ = access
	return &MediaKeysPromise{
		state_:  .rejected
		value_:  none
		reason_: 'NotSupportedError: createMediaKeys is not implemented'
	}
}
