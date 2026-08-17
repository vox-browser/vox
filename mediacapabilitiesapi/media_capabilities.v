// Copyright (c) 2026, Ladybird contributors
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of MediaCapabilitiesAPI/MediaCapabilities.{h,cpp,idl}.
module mediacapabilitiesapi

import dom
import encryptedmediaextensions
import html
import math
import mimesniff

pub enum MediaDecodingType {
	file
	media_source
	webrtc
}

pub fn (value MediaDecodingType) webidl_name() string {
	return match value {
		.file { 'file' }
		.media_source { 'media-source' }
		.webrtc { 'webrtc' }
	}
}

pub fn media_decoding_type_from_webidl(value string) !MediaDecodingType {
	return match value {
		'file' { .file }
		'media-source' { .media_source }
		'webrtc' { .webrtc }
		else { error('TypeError: ${value} is not a MediaDecodingType') }
	}
}

pub enum MediaEncodingType {
	record
	webrtc
}

pub fn (value MediaEncodingType) webidl_name() string {
	return match value {
		.record { 'record' }
		.webrtc { 'webrtc' }
	}
}

pub fn media_encoding_type_from_webidl(value string) !MediaEncodingType {
	return match value {
		'record' { .record }
		'webrtc' { .webrtc }
		else { error('TypeError: ${value} is not a MediaEncodingType') }
	}
}

pub enum HdrMetadataType {
	smpte_st2086
	smpte_st2094_10
	smpte_st2094_40
}

pub fn (value HdrMetadataType) webidl_name() string {
	return match value {
		.smpte_st2086 { 'smpteSt2086' }
		.smpte_st2094_10 { 'smpteSt2094-10' }
		.smpte_st2094_40 { 'smpteSt2094-40' }
	}
}

pub fn hdr_metadata_type_from_webidl(value string) !HdrMetadataType {
	return match value {
		'smpteSt2086' { .smpte_st2086 }
		'smpteSt2094-10' { .smpte_st2094_10 }
		'smpteSt2094-40' { .smpte_st2094_40 }
		else { error('TypeError: ${value} is not a HdrMetadataType') }
	}
}

pub enum ColorGamut {
	srgb
	p3
	rec2020
}

pub fn (value ColorGamut) webidl_name() string {
	return match value {
		.srgb { 'srgb' }
		.p3 { 'p3' }
		.rec2020 { 'rec2020' }
	}
}

pub fn color_gamut_from_webidl(value string) !ColorGamut {
	return match value {
		'srgb' { .srgb }
		'p3' { .p3 }
		'rec2020' { .rec2020 }
		else { error('TypeError: ${value} is not a ColorGamut') }
	}
}

pub enum TransferFunction {
	srgb
	pq
	hlg
}

pub fn (value TransferFunction) webidl_name() string {
	return match value {
		.srgb { 'srgb' }
		.pq { 'pq' }
		.hlg { 'hlg' }
	}
}

pub fn transfer_function_from_webidl(value string) !TransferFunction {
	return match value {
		'srgb' { .srgb }
		'pq' { .pq }
		'hlg' { .hlg }
		else { error('TypeError: ${value} is not a TransferFunction') }
	}
}

pub struct VideoConfiguration {
pub:
	content_type        string
	width               u32
	height              u32
	bitrate             u64
	framerate           f64
	has_alpha_channel   ?bool
	hdr_metadata_type   ?HdrMetadataType
	color_gamut         ?ColorGamut
	transfer_function   ?TransferFunction
	scalability_mode    ?string
	spatial_scalability ?bool
}

pub fn (configuration VideoConfiguration) is_valid_video_configuration() bool {
	return is_valid_video_mime_type(configuration.content_type)
		&& !math.is_nan(configuration.framerate) && !math.is_inf(configuration.framerate, 0)
		&& configuration.framerate > 0
}

pub struct AudioConfiguration {
pub:
	content_type      string
	channels          ?string
	bitrate           ?u64
	samplerate        ?u32
	spatial_rendering ?bool
}

pub fn (configuration AudioConfiguration) is_valid_audio_configuration() bool {
	return is_valid_audio_mime_type(configuration.content_type)
}

pub struct MediaConfiguration {
pub:
	video ?VideoConfiguration
	audio ?AudioConfiguration
}

pub fn (configuration MediaConfiguration) is_valid_media_configuration() bool {
	if configuration.audio == none && configuration.video == none {
		return false
	}
	if audio := configuration.audio {
		if !audio.is_valid_audio_configuration() {
			return false
		}
	}
	if video := configuration.video {
		if !video.is_valid_video_configuration() {
			return false
		}
	}
	return true
}

pub struct KeySystemTrackConfiguration {
pub:
	robustness        string
	encryption_scheme ?string
}

pub struct MediaCapabilitiesKeySystemConfiguration {
pub:
	key_system             string
	init_data_type         string
	distinctive_identifier encryptedmediaextensions.MediaKeysRequirement = .optional
	persistent_state       encryptedmediaextensions.MediaKeysRequirement = .optional
	session_types          ?[]string
	audio                  ?KeySystemTrackConfiguration
	video                  ?KeySystemTrackConfiguration
}

pub struct MediaDecodingConfiguration {
	MediaConfiguration
pub:
	type_                    MediaDecodingType
	key_system_configuration ?MediaCapabilitiesKeySystemConfiguration
}

pub fn (configuration MediaDecodingConfiguration) is_valid_media_decoding_configuration() bool {
	// Key-system validation remains FIXME in the upstream implementation.
	return configuration.MediaConfiguration.is_valid_media_configuration()
}

pub struct MediaEncodingConfiguration {
	MediaConfiguration
pub:
	type_ MediaEncodingType
}

pub struct MediaCapabilitiesInfo {
pub:
	supported       bool
	smooth          bool
	power_efficient bool
}

pub struct MediaCapabilitiesDecodingInfo {
	MediaCapabilitiesInfo
pub:
	configuration MediaDecodingConfiguration
	// keySystemAccess is marked FIXME in the upstream IDL and is not exposed.
}

pub struct MediaCapabilitiesEncodingInfo {
	MediaCapabilitiesInfo
pub:
	configuration ?MediaEncodingConfiguration
}

fn clone_key_system_configuration(configuration MediaCapabilitiesKeySystemConfiguration) MediaCapabilitiesKeySystemConfiguration {
	return MediaCapabilitiesKeySystemConfiguration{
		...configuration
		session_types: if values := configuration.session_types { values.clone() } else { none }
	}
}

pub fn (configuration MediaDecodingConfiguration) clone() MediaDecodingConfiguration {
	return MediaDecodingConfiguration{
		MediaConfiguration:       MediaConfiguration{
			video: configuration.video
			audio: configuration.audio
		}
		type_:                    configuration.type_
		key_system_configuration: if value := configuration.key_system_configuration {
			clone_key_system_configuration(value)
		} else {
			none
		}
	}
}

pub fn is_valid_audio_mime_type(value string) bool {
	mime_type := mimesniff.MimeType.parse(value) or { return false }
	return mime_type.type_() == 'audio' || mime_type.type_() == 'application'
}

pub fn is_valid_video_mime_type(value string) bool {
	mime_type := mimesniff.MimeType.parse(value) or { return false }
	return mime_type.type_() == 'video' || mime_type.type_() == 'application'
}

pub fn is_able_to_decode_media(configuration MediaDecodingConfiguration) bool {
	if configuration.type_ != .media_source {
		return false
	}
	if video := configuration.video {
		mime_type := mimesniff.MimeType.parse(video.content_type) or { return false }
		if mime_type.subtype() !in ['webm', 'mp4', 'mpeg', 'ogg'] {
			return false
		}
	}
	if audio := configuration.audio {
		mime_type := mimesniff.MimeType.parse(audio.content_type) or { return false }
		if mime_type.subtype() !in ['flac', 'mp3', 'mpeg', 'ogg', 'wav', 'webm'] {
			return false
		}
	}
	return true
}

pub fn create_a_media_capabilities_decoding_info(configuration MediaDecodingConfiguration) MediaCapabilitiesDecodingInfo {
	cloned := configuration.clone()
	return MediaCapabilitiesDecodingInfo{
		MediaCapabilitiesInfo: MediaCapabilitiesInfo{
			supported:       is_able_to_decode_media(cloned)
			smooth:          false
			power_efficient: false
		}
		configuration:         cloned
	}
}

@[heap]
pub struct MediaCapabilitiesDecodingInfoPromise {
mut:
	state_  dom.PromiseState
	value_  ?MediaCapabilitiesDecodingInfo
	reason_ string
}

fn MediaCapabilitiesDecodingInfoPromise.pending() &MediaCapabilitiesDecodingInfoPromise {
	return &MediaCapabilitiesDecodingInfoPromise{
		state_: .pending
		value_: none
	}
}

pub fn (promise &MediaCapabilitiesDecodingInfoPromise) state() dom.PromiseState {
	return promise.state_
}

pub fn (promise &MediaCapabilitiesDecodingInfoPromise) value() ?MediaCapabilitiesDecodingInfo {
	return promise.value_
}

pub fn (promise &MediaCapabilitiesDecodingInfoPromise) reason() string {
	return promise.reason_
}

fn (mut promise MediaCapabilitiesDecodingInfoPromise) resolve(value MediaCapabilitiesDecodingInfo) {
	if promise.state_ != .pending {
		return
	}
	promise.state_ = .fulfilled
	promise.value_ = value
}

fn (mut promise MediaCapabilitiesDecodingInfoPromise) reject(reason string) {
	if promise.state_ != .pending {
		return
	}
	promise.state_ = .rejected
	promise.reason_ = reason
}

@[heap]
pub struct MediaCapabilities {
	event_loop ?&html.EventLoop
}

pub fn MediaCapabilities.create(event_loop ?&html.EventLoop) &MediaCapabilities {
	return &MediaCapabilities{
		event_loop: event_loop
	}
}

// https://w3c.github.io/media-capabilities/#dom-mediacapabilities-decodinginfo
pub fn (capabilities &MediaCapabilities) decoding_info(configuration MediaDecodingConfiguration) &MediaCapabilitiesDecodingInfoPromise {
	mut promise := MediaCapabilitiesDecodingInfoPromise.pending()
	if !configuration.is_valid_media_decoding_configuration() {
		promise.reject('TypeError: The given configuration is not a valid MediaDecodingConfiguration')
		return promise
	}
	cloned := configuration.clone()
	html.queue_a_task(.media_capabilities, capabilities.event_loop, none, fn [cloned, promise] () {
		result := create_a_media_capabilities_decoding_info(cloned)
		mut mutable_promise := unsafe { &MediaCapabilitiesDecodingInfoPromise(promise) }
		mutable_promise.resolve(result)
	})
	return promise
}
