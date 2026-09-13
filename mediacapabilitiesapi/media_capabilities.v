// Copyright (c) 2026, Ladybird contributors
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of MediaCapabilitiesAPI/MediaCapabilities.{h,cpp,idl}.
module mediacapabilitiesapi

import dom
import encryptedmediaextensions
import html
import math
import mediasourceextensions
import mimesniff

enum MediaTrackType {
	audio
	video
}

enum MediaContainer {
	isobmff
	matroska
	webm
	ogg
	mpeg_audio
	adts
	flac
	wav
}

enum MediaCodec {
	vp8
	vp9
	h264
	h265
	mp3
	aac
	av1
	theora
	vorbis
	opus
	flac
	pcm_u8
	pcm_s16
	pcm_s24
	pcm_s32
	pcm_f32
	alaw
	mulaw
}

struct ParsedMediaCodec {
	kind            MediaCodec
	fully_specified bool
}

pub struct DecoderCapabilities {
pub:
	smooth          bool
	power_efficient bool
}

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
	return is_valid_video_mime_type(configuration.content_type) && !math.is_nan(configuration.framerate) && !math.is_inf(configuration.framerate, 0) && configuration.framerate > 0
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

// Current Ladybird's to_object() exposes only these three properties; its
// upstream FIXME does not yet add configuration to the JS object.
pub struct MediaCapabilitiesDecodingInfoObject {
pub:
	supported       bool
	smooth          bool
	power_efficient bool
}

pub fn (info MediaCapabilitiesDecodingInfo) to_object() MediaCapabilitiesDecodingInfoObject {
	return MediaCapabilitiesDecodingInfoObject{
		supported: info.supported
		smooth: info.smooth
		power_efficient: info.power_efficient
	}
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
		MediaConfiguration: MediaConfiguration{
			video: configuration.video
			audio: configuration.audio
		}
		type_: configuration.type_
		key_system_configuration: if value := configuration.key_system_configuration {
			clone_key_system_configuration(value)
		} else {
			none
		}
	}
}

fn container_from_mime_type(type_ string, subtype string) ?MediaContainer {
	if type_ !in ['audio', 'video', 'application'] {
		return none
	}
	return match subtype {
		'mp4' { MediaContainer.isobmff }
		'webm' {
			if type_ == 'application' { none } else { MediaContainer.webm }
		}
		'matroska', 'x-matroska' {
			if type_ == 'application' { none } else { MediaContainer.matroska }
		}
		'ogg' { MediaContainer.ogg }
		'mpeg', 'mp3', 'x-mp3' {
			if type_ == 'audio' { MediaContainer.mpeg_audio } else { none }
		}
		'aac' {
			if type_ == 'audio' { MediaContainer.adts } else { none }
		}
		'flac' {
			if type_ == 'audio' { MediaContainer.flac } else { none }
		}
		'wav', 'wave', 'x-wav' {
			if type_ == 'audio' { MediaContainer.wav } else { none }
		}
		else { none }
	}
}

fn codec_track_type(codec MediaCodec) MediaTrackType {
	return match codec {
		.vp8, .vp9, .h264, .h265, .av1, .theora { .video }
		else { .audio }
	}
}

fn is_decimal_string(value string) bool {
	if value == '' {
		return false
	}
	for ch in value.bytes() {
		if ch < `0` || ch > `9` {
			return false
		}
	}
	return true
}

fn is_hex_string(value string) bool {
	if value == '' {
		return false
	}
	for ch in value.bytes() {
		if !((ch >= `0` && ch <= `9`) || (ch >= `a` && ch <= `f`)
			|| (ch >= `A` && ch <= `F`)) {
			return false
		}
	}
	return true
}

fn parse_media_codec(value string) ?ParsedMediaCodec {
	return match value {
		'vp8', 'vp8.0' { ParsedMediaCodec{ kind: .vp8, fully_specified: true } }
		'vp9', 'vp9.0' { ParsedMediaCodec{ kind: .vp9, fully_specified: true } }
		'mp3' { ParsedMediaCodec{ kind: .mp3, fully_specified: true } }
		'theora' { ParsedMediaCodec{ kind: .theora, fully_specified: true } }
		'vorbis' { ParsedMediaCodec{ kind: .vorbis, fully_specified: true } }
		'opus', 'Opus' { ParsedMediaCodec{ kind: .opus, fully_specified: true } }
		'flac', 'fLaC' { ParsedMediaCodec{ kind: .flac, fully_specified: true } }
		'pcm-u8' { ParsedMediaCodec{ kind: .pcm_u8, fully_specified: true } }
		'pcm-s16' { ParsedMediaCodec{ kind: .pcm_s16, fully_specified: true } }
		'pcm-s24' { ParsedMediaCodec{ kind: .pcm_s24, fully_specified: true } }
		'pcm-s32' { ParsedMediaCodec{ kind: .pcm_s32, fully_specified: true } }
		'pcm-f32' { ParsedMediaCodec{ kind: .pcm_f32, fully_specified: true } }
		'alaw' { ParsedMediaCodec{ kind: .alaw, fully_specified: true } }
		'ulaw' { ParsedMediaCodec{ kind: .mulaw, fully_specified: true } }
		else {
			parts := value.split('.')
			if parts.len == 1 {
				if value in ['avc1', 'avc3'] {
					return ParsedMediaCodec{ kind: .h264, fully_specified: false }
				}
				return none
			}
			match parts[0] {
				'avc1', 'avc3' {
					if parts.len == 2 && parts[1].len == 6 && is_hex_string(parts[1]) {
						return ParsedMediaCodec{ kind: .h264, fully_specified: true }
					}
				}
				'hev1', 'hvc1' {
					if parts[1..].all(is_decimal_string) {
						return ParsedMediaCodec{ kind: .h265, fully_specified: true }
					}
				}
				'vp09' {
					if parts.len >= 4 && parts[1..].all(is_decimal_string) {
						return ParsedMediaCodec{ kind: .vp9, fully_specified: true }
					}
				}
				'av01' {
					if parts.len >= 4 {
						return ParsedMediaCodec{ kind: .av1, fully_specified: true }
					}
				}
				'mp4a' {
					if parts[1..].all(fn (part string) bool {
						return is_decimal_string(part) || is_hex_string(part)
					}) {
						kind := if parts[1].to_lower() in ['69', '6b'] {
							MediaCodec.mp3
						} else {
							MediaCodec.aac
						}
						return ParsedMediaCodec{ kind: kind, fully_specified: parts.len >= 3 }
					}
				}
				else {}
			}
			none
		}
	}
}

fn check_mime_type_validity(mime_type mimesniff.MimeType, media MediaTrackType) bool {
	media_name := if media == .audio { 'audio' } else { 'video' }
	if mime_type.type_() != media_name && mime_type.type_() != 'application' {
		return false
	}
	container := container_from_mime_type(mime_type.type_(), mime_type.subtype()) or {
		return true
	}
	parameters := mime_type.parameters()
	if container in [.adts, .flac] {
		return parameters.len == 0
	}
	if parameters.len != 1 || 'codecs' !in parameters {
		return false
	}
	codec_strings := parameters['codecs'].split(',')
	if codec_strings.len != 1 {
		return false
	}
	codec := parse_media_codec(codec_strings[0].trim_space()) or { return false }
	return codec_track_type(codec.kind) == media
}

pub fn is_valid_audio_mime_type(value string) bool {
	mime_type := mimesniff.MimeType.parse(value) or { return false }
	return check_mime_type_validity(mime_type, .audio)
}

pub fn is_valid_video_mime_type(value string) bool {
	mime_type := mimesniff.MimeType.parse(value) or { return false }
	return check_mime_type_validity(mime_type, .video)
}

fn codec_supported_in_container(container MediaContainer, codec MediaCodec) bool {
	return match container {
		.webm { codec in [.vp8, .vp9, .av1, .vorbis, .opus] }
		.matroska {
			codec !in [.alaw, .mulaw]
		}
		.isobmff { codec in [.vp8, .vp9, .h264, .h265, .mp3, .aac, .av1, .opus, .flac] }
		.ogg { codec in [.theora, .vorbis, .opus, .flac] }
		.mpeg_audio { codec == .mp3 }
		.adts { codec == .aac }
		.flac { codec == .flac }
		.wav { codec in [.pcm_u8, .pcm_s16, .pcm_s24, .pcm_s32, .pcm_f32, .alaw, .mulaw] }
	}
}

fn file_decoding_capabilities(content_type string) ?DecoderCapabilities {
	mime_type := mimesniff.MimeType.parse(content_type) or { return none }
	container := container_from_mime_type(mime_type.type_(), mime_type.subtype()) or { return none }
	if mime_type.type_() == 'application' && container == .isobmff {
		return none
	}
	parameters := mime_type.parameters()
	if 'codecs' !in parameters {
		if container !in [.adts, .flac] {
			return none
		}
		return DecoderCapabilities{ smooth: true, power_efficient: false }
	}
	codec_strings := parameters['codecs'].split(',')
	if codec_strings.len == 0 {
		return none
	}
	for codec_string in codec_strings {
		codec := parse_media_codec(codec_string.trim_space()) or { return none }
		if !codec.fully_specified || !codec_supported_in_container(container, codec.kind) {
			return none
		}
		if mime_type.type_() == 'audio' && codec_track_type(codec.kind) != .audio {
			return none
		}
	}
	return DecoderCapabilities{ smooth: true, power_efficient: false }
}

fn media_source_decoding_capabilities(content_type string) ?DecoderCapabilities {
	capabilities := mediasourceextensions.MediaSource.decoder_capabilities_for_type(content_type) or {
		return none
	}
	return DecoderCapabilities{
		smooth: capabilities.smooth
		power_efficient: capabilities.power_efficient
	}
}

fn check_mime_type_support(content_type string, decoding_type MediaDecodingType) ?DecoderCapabilities {
	if decoding_type == .webrtc {
		return none
	}
	if decoding_type == .media_source {
		return media_source_decoding_capabilities(content_type)
	}
	return file_decoding_capabilities(content_type)
}

pub fn media_decoding_capabilities(configuration MediaDecodingConfiguration) ?DecoderCapabilities {
	mut result := DecoderCapabilities{ smooth: true, power_efficient: true }
	if video := configuration.video {
		capabilities := check_mime_type_support(video.content_type, configuration.type_) or { return none }
		result = DecoderCapabilities{
			smooth: result.smooth && capabilities.smooth
			power_efficient: result.power_efficient && capabilities.power_efficient
		}
	}
	if audio := configuration.audio {
		capabilities := check_mime_type_support(audio.content_type, configuration.type_) or { return none }
		result = DecoderCapabilities{
			smooth: result.smooth && capabilities.smooth
			power_efficient: result.power_efficient && capabilities.power_efficient
		}
	}
	return result
}

pub fn is_able_to_decode_media(configuration MediaDecodingConfiguration) bool {
	return media_decoding_capabilities(configuration) != none
}

pub fn create_a_media_capabilities_decoding_info(configuration MediaDecodingConfiguration) MediaCapabilitiesDecodingInfo {
	cloned := configuration.clone()
	capabilities := media_decoding_capabilities(cloned)
	return MediaCapabilitiesDecodingInfo{
		MediaCapabilitiesInfo: MediaCapabilitiesInfo{
			supported: capabilities != none
			smooth: if value := capabilities { value.smooth } else { false }
			power_efficient: if value := capabilities { value.power_efficient } else { false }
		}
		configuration: cloned
	}
}

@[heap]
pub struct MediaCapabilitiesDecodingInfoPromise {
mut:
	state_  dom.PromiseState
	value_  ?MediaCapabilitiesDecodingInfoObject
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

pub fn (promise &MediaCapabilitiesDecodingInfoPromise) value() ?MediaCapabilitiesDecodingInfoObject {
	return promise.value_
}

pub fn (promise &MediaCapabilitiesDecodingInfoPromise) reason() string {
	return promise.reason_
}

fn (mut promise MediaCapabilitiesDecodingInfoPromise) resolve(value MediaCapabilitiesDecodingInfoObject) {
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

pub type MediaCapabilitiesTaskSteps = fn ()

// https://w3c.github.io/media-capabilities/#queue-a-media-capabilities-task
pub fn queue_a_media_capabilities_task(event_loop ?&html.EventLoop, steps MediaCapabilitiesTaskSteps) {
	html.queue_a_task(.media_capabilities, event_loop, none, steps)
}

// https://w3c.github.io/media-capabilities/#dom-mediacapabilities-decodinginfo
pub fn (capabilities &MediaCapabilities) decoding_info(configuration MediaDecodingConfiguration) &MediaCapabilitiesDecodingInfoPromise {
	mut promise := MediaCapabilitiesDecodingInfoPromise.pending()
	if !configuration.is_valid_media_decoding_configuration() {
		promise.reject('TypeError: The given configuration is not a valid MediaDecodingConfiguration')
		return promise
	}
	cloned := configuration.clone()
	queue_a_media_capabilities_task(capabilities.event_loop, fn [cloned, promise] () {
		result := create_a_media_capabilities_decoding_info(cloned).to_object()
		mut mutable_promise := unsafe { &MediaCapabilitiesDecodingInfoPromise(promise) }
		mutable_promise.resolve(result)
	})
	return promise
}
