// Copyright (c) 2026, Ladybird contributors
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of EncryptedMediaExtensions/Algorithms.cpp.
module encryptedmediaextensions

import dom
import mimesniff

pub fn supports_container(container string) bool {
	_ = container
	// Ladybird currently leaves this as an FFmpeg capability FIXME.
	return true
}

// https://w3c.github.io/encrypted-media/#get-supported-capabilities-for-audio-video-type
pub fn get_supported_capabilities_for_audio_video_type(implementation KeySystem, type_ CapabilitiesType, requested_capabilities []MediaKeySystemMediaCapability, configuration MediaKeySystemConfiguration, restrictions MediaKeyRestrictions) ?[]MediaKeySystemMediaCapability {
	mut accumulated_configuration := configuration.clone()
	mut supported_media_capabilities := []MediaKeySystemMediaCapability{}
	for capability in requested_capabilities {
		if capability.content_type.len == 0 {
			return none
		}
		mime_type := mimesniff.MimeType.parse(capability.content_type) or { continue }
		container := mime_type.essence()
		if !supports_container(container) {
			continue
		}
		parameters := mime_type.parameters()
		media_types := parameters['codecs'] or { '' }
		if media_types.len == 0 {
			continue
		}
		if !mime_type.is_audio_or_video() {
			continue
		}
		if encryption_scheme := capability.encryption_scheme {
			if !implementation.supports_encryption_scheme(encryption_scheme) {
				continue
			}
		}
		if capability.robustness.len != 0
			&& !implementation.supports_robustness(capability.robustness) {
			continue
		}
		if implementation.definitely_supports_playback(container, media_types,
			capability.encryption_scheme, capability.robustness, accumulated_configuration,
			restrictions)
		{
			supported_media_capabilities << capability
			if type_ == .video {
				mut capabilities := accumulated_configuration.video_capabilities.clone()
				capabilities << capability
				accumulated_configuration = MediaKeySystemConfiguration{
					...accumulated_configuration
					video_capabilities: capabilities
				}
			} else {
				mut capabilities := accumulated_configuration.audio_capabilities.clone()
				capabilities << capability
				accumulated_configuration = MediaKeySystemConfiguration{
					...accumulated_configuration
					audio_capabilities: capabilities
				}
			}
		}
	}
	if supported_media_capabilities.len == 0 {
		return none
	}
	return supported_media_capabilities
}

// https://w3c.github.io/encrypted-media/#dfn-is-persistent-session-type
pub fn is_persistent_session_type(session_type string) bool {
	return match session_type {
		'temporary' { false }
		'persistent-license' { true }
		else { panic('invalid MediaKeySessionType: ${session_type}') }
	}
}

// https://w3c.github.io/encrypted-media/#get-consent-status
pub fn get_consent_status(accumulated_configuration MediaKeySystemConfiguration, mut restrictions MediaKeyRestrictions, origin dom.Origin) ConsentStatus {
	_ = accumulated_configuration
	_ = restrictions
	_ = origin
	// Faithful to Ladybird's current implementation while user consent UI is
	// not connected.
	return .allowed
}

// https://w3c.github.io/encrypted-media/#get-supported-configuration-and-consent
pub fn get_supported_configuration_and_consent(implementation KeySystem, candidate_configuration MediaKeySystemConfiguration, mut restrictions MediaKeyRestrictions, origin dom.Origin) ?ConsentConfiguration {
	mut accumulated_configuration := MediaKeySystemConfiguration{
		label: candidate_configuration.label
	}
	if candidate_configuration.init_data_types.len != 0 {
		mut supported_types := []string{}
		for init_data_type in candidate_configuration.init_data_types {
			if implementation.supports_init_data_type(init_data_type) {
				supported_types << init_data_type
			}
		}
		if supported_types.len == 0 {
			return none
		}
		accumulated_configuration = MediaKeySystemConfiguration{
			...accumulated_configuration
			init_data_types: supported_types
		}
	}

	mut distinctive_identifier_requirement := candidate_configuration.distinctive_identifier
	if distinctive_identifier_requirement == .optional && !restrictions.distinctive_identifiers {
		distinctive_identifier_requirement = .not_allowed
	}
	// Ladybird's required/not-allowed CDM constraint checks remain FIXMEs.
	accumulated_configuration = MediaKeySystemConfiguration{
		...accumulated_configuration
		distinctive_identifier: distinctive_identifier_requirement
	}

	mut persistent_state_requirement := candidate_configuration.persistent_state
	if persistent_state_requirement == .optional && !restrictions.persist_state {
		persistent_state_requirement = .not_allowed
	}
	accumulated_configuration = MediaKeySystemConfiguration{
		...accumulated_configuration
		persistent_state: persistent_state_requirement
	}

	mut session_types := if candidate_session_types := candidate_configuration.session_types {
		candidate_session_types.clone()
	} else {
		['temporary']
	}
	for session_type in session_types {
		persistent := is_persistent_session_type(session_type)
		if accumulated_configuration.persistent_state == .not_allowed && persistent {
			return none
		}
		if accumulated_configuration.persistent_state == .optional && persistent {
			accumulated_configuration = MediaKeySystemConfiguration{
				...accumulated_configuration
				persistent_state: .required
			}
		}
	}
	accumulated_configuration = MediaKeySystemConfiguration{
		...accumulated_configuration
		session_types: session_types
	}

	if candidate_configuration.video_capabilities.len == 0
		&& candidate_configuration.audio_capabilities.len == 0 {
		return none
	}
	if candidate_configuration.video_capabilities.len != 0 {
		video_capabilities := get_supported_capabilities_for_audio_video_type(implementation,
			.video, candidate_configuration.video_capabilities, accumulated_configuration,
			restrictions) or { return none }
		accumulated_configuration = MediaKeySystemConfiguration{
			...accumulated_configuration
			video_capabilities: video_capabilities
		}
	}
	if candidate_configuration.audio_capabilities.len != 0 {
		audio_capabilities := get_supported_capabilities_for_audio_video_type(implementation,
			.audio, candidate_configuration.audio_capabilities, accumulated_configuration,
			restrictions) or { return none }
		accumulated_configuration = MediaKeySystemConfiguration{
			...accumulated_configuration
			audio_capabilities: audio_capabilities
		}
	}

	if accumulated_configuration.distinctive_identifier == .optional {
		accumulated_configuration = MediaKeySystemConfiguration{
			...accumulated_configuration
			distinctive_identifier: .not_allowed
		}
	}
	if accumulated_configuration.persistent_state == .optional {
		accumulated_configuration = MediaKeySystemConfiguration{
			...accumulated_configuration
			persistent_state: .not_allowed
		}
	}

	consent_status := get_consent_status(accumulated_configuration, mut restrictions, origin)
	if consent_status == .consent_denied {
		return none
	}
	return ConsentConfiguration{
		status:        consent_status
		configuration: accumulated_configuration
	}
}

// https://w3c.github.io/encrypted-media/#get-supported-configuration
pub fn get_supported_configuration(implementation KeySystem, candidate_configuration MediaKeySystemConfiguration, origin dom.Origin) ?ConsentConfiguration {
	mut supported_configuration := ?ConsentConfiguration(ConsentConfiguration{})
	mut restrictions := MediaKeyRestrictions{}
	mut loop_count := uint(0)
	for supported_configuration != none
		&& supported_configuration or { break }.status == .consent_denied {
		supported_configuration = get_supported_configuration_and_consent(implementation,
			candidate_configuration, mut restrictions, origin)
		if loop_count > 5 {
			break
		}
		loop_count++
	}
	return supported_configuration
}
