module mediacapabilitiesapi

import dom
import html
import math

fn video(content_type string, framerate f64) VideoConfiguration {
	return VideoConfiguration{
		content_type: content_type
		width: 1920
		height: 1080
		bitrate: 4_000_000
		framerate: framerate
	}
}

fn test_webidl_enum_names() {
	assert MediaDecodingType.media_source.webidl_name() == 'media-source'
	assert media_decoding_type_from_webidl('webrtc')! == .webrtc
	assert MediaEncodingType.record.webidl_name() == 'record'
	assert media_encoding_type_from_webidl('record')! == .record
	assert HdrMetadataType.smpte_st2094_10.webidl_name() == 'smpteSt2094-10'
	assert hdr_metadata_type_from_webidl('smpteSt2086')! == .smpte_st2086
	assert ColorGamut.rec2020.webidl_name() == 'rec2020'
	assert color_gamut_from_webidl('p3')! == .p3
	assert TransferFunction.hlg.webidl_name() == 'hlg'
	assert transfer_function_from_webidl('pq')! == .pq
}

fn test_mime_and_configuration_validation() {
	assert is_valid_audio_mime_type('audio/ogg; codecs=opus')
	assert is_valid_audio_mime_type('audio/aac')
	assert !is_valid_audio_mime_type('application/ogg')
	assert !is_valid_audio_mime_type('video/mp4')
	assert is_valid_video_mime_type('video/mp4; codecs="avc1.42E01E"')
	assert !is_valid_video_mime_type('audio/mp4')
	assert !is_valid_video_mime_type('video/webm')
	assert !is_valid_video_mime_type('video/webm; codecs="vp09.00.10.08, vp8"')
	assert !is_valid_video_mime_type('video/webm; codecs=opus')
	assert !is_valid_audio_mime_type('application/ogg; codecs=theora')
	assert !MediaConfiguration{}.is_valid_media_configuration()
	assert !video('video/mp4', 0).is_valid_video_configuration()
	assert !video('video/mp4', math.nan()).is_valid_video_configuration()
	assert video('video/mp4; codecs="avc1.42E01E"', 60).is_valid_video_configuration()
}

fn test_decode_support_matches_html_media_subtype_registry() {
	base := MediaConfiguration{
		video: video('video/webm; codecs="vp09.00.10.08"', 24)
		audio: AudioConfiguration{
			content_type: 'audio/webm; codecs=opus'
		}
	}
	assert is_able_to_decode_media(MediaDecodingConfiguration{
		MediaConfiguration: base
		type_: .media_source
	})
	assert is_able_to_decode_media(MediaDecodingConfiguration{
		MediaConfiguration: base
		type_: .file
	})
	assert !is_able_to_decode_media(MediaDecodingConfiguration{
		MediaConfiguration: MediaConfiguration{
			video: video('video/unsupported', 24)
		}
		type_: .media_source
	})
	assert media_decoding_capabilities(MediaDecodingConfiguration{
		MediaConfiguration: base
		type_: .media_source
	})? == DecoderCapabilities{
		smooth: true
		power_efficient: false
	}
	assert media_decoding_capabilities(MediaDecodingConfiguration{
		MediaConfiguration: base
		type_: .webrtc
	}) == none
}

fn test_decoding_info_rejects_invalid_and_resolves_on_media_task() {
	mut event_loop := html.EventLoop.create(.window)
	capabilities := MediaCapabilities.create(event_loop)
	rejected := capabilities.decoding_info(MediaDecodingConfiguration{
		type_: .media_source
	})
	assert rejected.state() == dom.PromiseState.rejected
	assert rejected.reason().starts_with('TypeError:')

	mut sessions := ['temporary']
	valid := MediaDecodingConfiguration{
		MediaConfiguration: MediaConfiguration{
			video: video('video/mp4; codecs="avc1.42E01E"', 30)
		}
		type_: .media_source
		key_system_configuration: MediaCapabilitiesKeySystemConfiguration{
			key_system: 'org.w3.clearkey'
			session_types: sessions
		}
	}
	internal_info := create_a_media_capabilities_decoding_info(valid)
	promise := capabilities.decoding_info(valid)
	sessions[0] = 'mutated-after-call'
	assert promise.state() == dom.PromiseState.pending
	event_loop.process()
	assert promise.state() == dom.PromiseState.fulfilled
	info := promise.value() or { panic('missing decoding info') }
	assert info.supported
	assert info.smooth
	assert !info.power_efficient

	key_system := internal_info.configuration.key_system_configuration or {
		panic('missing key system configuration')
	}
	assert (key_system.session_types or { []string{} }) == ['temporary']
	assert internal_info.to_object() == info
}
