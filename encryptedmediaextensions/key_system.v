// Copyright (c) 2026, Ladybird contributors
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of EncryptedMediaExtensions/KeySystem.h.
module encryptedmediaextensions

// KeySystem is the typed boundary between the specification algorithms and a
// content-decryption-module implementation. The present Ladybird source only
// supplies Clear Key.
pub interface KeySystem {
	supports_init_data_type(init_data_type string) bool
	supports_encryption_scheme(encryption_scheme string) bool
	supports_robustness(robustness string) bool
	definitely_supports_playback(container string, media_types string, encryption_scheme ?string, robustness string, accumulated_configuration MediaKeySystemConfiguration, restrictions MediaKeyRestrictions) bool
}

pub struct ClearKeySystem {}

// https://w3c.github.io/encrypted-media/#clear-key-behavior
pub fn (implementation ClearKeySystem) supports_init_data_type(init_data_type string) bool {
	_ = implementation
	return init_data_type == 'keyids'
}

// https://w3c.github.io/encrypted-media/#clear-key-capabilities
pub fn (implementation ClearKeySystem) supports_encryption_scheme(encryption_scheme string) bool {
	_ = implementation
	return encryption_scheme == 'cenc'
}

pub fn (implementation ClearKeySystem) supports_robustness(robustness string) bool {
	_ = implementation
	return robustness.len == 0
}

pub fn (implementation ClearKeySystem) definitely_supports_playback(container string, media_types string, encryption_scheme ?string, robustness string, accumulated_configuration MediaKeySystemConfiguration, restrictions MediaKeyRestrictions) bool {
	_ = implementation
	_ = container
	_ = media_types
	_ = encryption_scheme
	_ = robustness
	_ = accumulated_configuration
	_ = restrictions
	// Ladybird currently has a FIXME at this platform capability boundary and
	// returns true after the preceding validation has succeeded.
	return true
}

pub fn is_supported_key_system(key_system string) bool {
	return key_system == 'org.w3.clearkey'
}

pub fn key_system_from_string(key_system string) KeySystem {
	if key_system == 'org.w3.clearkey' {
		return KeySystem(ClearKeySystem{})
	}
	// Algorithms.cpp only calls this after is_supported_key_system(); its C++
	// fallthrough is VERIFY_NOT_REACHED rather than a recoverable result.
	panic('unsupported key system passed to key_system_from_string: ${key_system}')
}
