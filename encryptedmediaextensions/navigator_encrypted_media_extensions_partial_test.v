module encryptedmediaextensions

import dom
import html

fn navigator_test_capability(content_type string) MediaKeySystemMediaCapability {
	return MediaKeySystemMediaCapability{
		content_type:      content_type
		encryption_scheme: 'cenc'
	}
}

fn navigator_test_context(event_loop &html.EventLoop) NavigatorEncryptedMediaExtensionsContext {
	return NavigatorEncryptedMediaExtensionsContext{
		origin:     dom.Origin{
			value: 'https://example.test'
		}
		event_loop: event_loop
	}
}

fn drain_eme_event_loop(mut event_loop html.EventLoop) {
	mut iterations := 0
	for event_loop.task_queue().has_runnable_tasks() {
		event_loop.process()
		iterations++
		assert iterations < 20
	}
}

fn test_request_rejects_argument_errors_before_queueing_work() {
	mut event_loop := html.EventLoop.create(.window)
	navigator := NavigatorEncryptedMediaExtensionsPartial.create(navigator_test_context(event_loop))
	empty_key := navigator.request_media_key_system_access('', [
		MediaKeySystemConfiguration{},
	]) or { panic(err) }
	assert empty_key.state() == .rejected
	assert empty_key.reason() == 'TypeError: keySystem must not be empty'
	empty_configurations := navigator.request_media_key_system_access('org.w3.clearkey', []) or {
		panic(err)
	}
	assert empty_configurations.state() == .rejected
	assert empty_configurations.reason() == 'TypeError: supportedConfigurations must not be empty'
	assert !event_loop.task_queue().has_runnable_tasks()
}

fn test_request_throws_security_error_synchronously() {
	event_loop := html.EventLoop.create(.window)
	navigator := NavigatorEncryptedMediaExtensionsPartial.create(NavigatorEncryptedMediaExtensionsContext{
		encrypted_media_allowed: false
		origin:                  dom.Origin{
			value: 'https://example.test'
		}
		event_loop:              event_loop
	})
	if _ := navigator.request_media_key_system_access('org.w3.clearkey', [
		MediaKeySystemConfiguration{},
	])
	{
		assert false
	} else {
		assert err.msg().starts_with('SecurityError:')
	}
}

fn test_request_rejects_unsupported_key_system_asynchronously() {
	mut event_loop := html.EventLoop.create(.window)
	navigator := NavigatorEncryptedMediaExtensionsPartial.create(navigator_test_context(event_loop))
	promise := navigator.request_media_key_system_access('com.example.unsupported', [
		MediaKeySystemConfiguration{
			video_capabilities: [
				navigator_test_capability('video/webm; codecs="vp9"'),
			]
		},
	]) or { panic(err) }
	assert promise.state() == .pending
	drain_eme_event_loop(mut event_loop)
	assert promise.state() == .rejected
	assert promise.reason() == 'NotSupportedError: Unsupported key system'
}

fn test_request_selects_first_supported_configuration_asynchronously() {
	mut event_loop := html.EventLoop.create(.window)
	navigator := NavigatorEncryptedMediaExtensionsPartial.create(navigator_test_context(event_loop))
	promise := navigator.request_media_key_system_access('org.w3.clearkey', [
		MediaKeySystemConfiguration{
			label: 'missing capabilities'
		},
		MediaKeySystemConfiguration{
			label:              'accepted'
			init_data_types:    ['keyids']
			video_capabilities: [navigator_test_capability('video/mp4; codecs="avc1.4d401e"')]
		},
	]) or { panic(err) }
	assert promise.state() == .pending
	drain_eme_event_loop(mut event_loop)
	assert promise.state() == .fulfilled
	access := promise.value() or { panic('access object should be present') }
	assert access.key_system() == 'org.w3.clearkey'
	assert access.get_configuration().label == 'accepted'
}

fn test_deferred_request_captures_webidl_values_and_is_not_document_gated() {
	mut event_loop := html.EventLoop.create(.window)
	document := dom.Document.create(dom.url_about_blank())
	navigator := NavigatorEncryptedMediaExtensionsPartial.create(NavigatorEncryptedMediaExtensionsContext{
		origin:     dom.Origin{
			value: 'https://example.test'
		}
		document:   document
		event_loop: event_loop
	})
	mut configurations := [
		MediaKeySystemConfiguration{
			label:              'captured'
			init_data_types:    ['keyids']
			video_capabilities: [navigator_test_capability('video/webm; codecs="vp9"')]
		},
	]
	promise := navigator.request_media_key_system_access('org.w3.clearkey', configurations) or {
		panic(err)
	}
	task := event_loop.task_queue().last_added_task() or { panic('expected deferred EME task') }
	assert task.source == .media_capabilities
	assert task.document() == none
	configurations[0] = MediaKeySystemConfiguration{
		label: 'caller mutation'
	}
	drain_eme_event_loop(mut event_loop)
	assert promise.state() == .fulfilled
	access := promise.value() or { panic('access object should be present') }
	assert access.get_configuration().label == 'captured'
}

fn test_request_rejects_when_no_candidate_configuration_is_supported() {
	mut event_loop := html.EventLoop.create(.window)
	navigator := NavigatorEncryptedMediaExtensionsPartial.create(navigator_test_context(event_loop))
	promise := navigator.request_media_key_system_access('org.w3.clearkey', [
		MediaKeySystemConfiguration{
			init_data_types:    ['unsupported']
			audio_capabilities: [navigator_test_capability('audio/webm; codecs="opus"')]
		},
	]) or { panic(err) }
	drain_eme_event_loop(mut event_loop)
	assert promise.state() == .rejected
	assert promise.reason().contains('No supported configurations')
}
