// Copyright (c) 2026, Ladybird contributors
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of EncryptedMediaExtensions/EncryptedMediaExtensions.h and the
// dictionaries and enums in MediaKeySystemAccess.idl.
module encryptedmediaextensions

pub enum MediaKeysRequirement {
	required
	optional
	not_allowed
}

pub fn (requirement MediaKeysRequirement) webidl_name() string {
	return match requirement {
		.required { 'required' }
		.optional { 'optional' }
		.not_allowed { 'not-allowed' }
	}
}

pub fn media_keys_requirement_from_webidl(value string) !MediaKeysRequirement {
	return match value {
		'required' { .required }
		'optional' { .optional }
		'not-allowed' { .not_allowed }
		else { error('TypeError: ${value} is not a MediaKeysRequirement') }
	}
}

pub enum MediaKeySessionType {
	temporary
	persistent_license
}

pub fn (session_type MediaKeySessionType) webidl_name() string {
	return match session_type {
		.temporary { 'temporary' }
		.persistent_license { 'persistent-license' }
	}
}

pub fn media_key_session_type_from_webidl(value string) !MediaKeySessionType {
	return match value {
		'temporary' { .temporary }
		'persistent-license' { .persistent_license }
		else { error('TypeError: ${value} is not a MediaKeySessionType') }
	}
}

pub struct MediaKeySystemMediaCapability {
pub:
	content_type      string
	encryption_scheme ?string
	robustness        string
}

pub struct MediaKeySystemConfiguration {
pub:
	label                  string
	init_data_types        []string
	audio_capabilities     []MediaKeySystemMediaCapability
	video_capabilities     []MediaKeySystemMediaCapability
	distinctive_identifier MediaKeysRequirement = .optional
	persistent_state       MediaKeysRequirement = .optional
	// `none` records that the WebIDL member was absent. An explicitly empty
	// sequence is observably different and is retained as `some([])`.
	session_types ?[]string
}

pub fn (configuration MediaKeySystemConfiguration) clone() MediaKeySystemConfiguration {
	return MediaKeySystemConfiguration{
		label:                  configuration.label
		init_data_types:        configuration.init_data_types.clone()
		audio_capabilities:     configuration.audio_capabilities.clone()
		video_capabilities:     configuration.video_capabilities.clone()
		distinctive_identifier: configuration.distinctive_identifier
		persistent_state:       configuration.persistent_state
		session_types:          if session_types := configuration.session_types {
			session_types.clone()
		} else {
			none
		}
	}
}

pub struct MediaKeyRestrictions {
pub mut:
	distinctive_identifiers bool = true
	persist_state           bool = true
}

pub enum CapabilitiesType {
	audio
	video
}

pub enum ConsentStatus {
	consent_denied
	inform_user
	allowed
}

pub struct ConsentConfiguration {
pub:
	status        ConsentStatus = .consent_denied
	configuration ?MediaKeySystemConfiguration
}
