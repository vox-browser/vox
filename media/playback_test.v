module main

import browserjs
import dom
import html
import page
import platform
import time

fn test_native_decoder_exposes_hls_for_parser_and_script_created_media_without_mse() {
	$if !macos {
		return
	}
	owner := page.Page.create(1)!
	document := parse_browser_navigation_document_for_page_with_response_time('<video id="player"></video>',
		dom.URL{ value: 'https://native-hls.example.test/' }, none, none,
		unsafe { &dom.Page(owner) }, time.sys_mono_now())
	mut app := &BrowserApp{ document: document }
	app.install_document_media_playback()
	defer { app.close_media_playback() }
	mut runtime := browserjs.Runtime.create()
	defer { runtime.close() }
	mut messages := []string{}
	run_document_script_sources_with_media_loader(document, document.url.serialize(), [browserjs.ScriptSource{
		code: 'globalThis.nativeHlsOK = typeof MediaSource === "undefined" && typeof WebKitMediaSource === "undefined" && document.getElementById("player").canPlayType("application/vnd.apple.mpegurl") === "maybe"; globalThis.createdVideo = document.createElement("video"); globalThis.createdAudio = new Audio(); nativeHlsOK = nativeHlsOK && createdVideo.canPlayType("application/x-mpegURL") === "maybe" && createdAudio.canPlayType("audio/mp4") === "maybe" && createdVideo.canPlayType("application/dash+xml") === "";'
		url:  document.url.serialize()
	}], runtime, browser_fetch_image_request, none, none, fn [app] (element &dom.Element) {
		mut browser := unsafe { &BrowserApp(app) }
		browser.install_media_playback(element)
	}, mut messages)
	assert messages == []
	assert runtime.evaluate_host('nativeHlsOK')! == 'true'
	assert app.media_players.len == 3
	for player in app.media_players {
		assert player.handle == unsafe { nil }
		assert player.media.network_state() == html.MediaNetworkState.empty
	}
}

fn test_native_decoder_failure_rejects_play_and_releases_the_player() {
	$if !macos {
		return
	}
	owner := page.Page.create(1)!
	document := parse_browser_navigation_document_for_page_with_response_time('<video></video>',
		dom.URL{ value: 'https://native-hls.example.test/' }, none, none,
		unsafe { &dom.Page(owner) }, time.sys_mono_now())
	mut app := &BrowserApp{ document: document }
	app.install_document_media_playback()
	defer { app.close_media_playback() }
	mut media := app.media_players[0].media
	media.set_muted(true)
	media.set_source('file:///nonexistent/vox-native-media-failure.mp4')
	promise := media.play()
	assert promise.state() == .pending
	assert app.media_players[0].handle != unsafe { nil }
	deadline := time.sys_mono_now() + 10 * time.second
	for promise.state() == .pending && time.sys_mono_now() < deadline {
		platform.pump_native_events(0.01)
		app.poll_media_playback()
	}
	assert promise.state() == .rejected
	assert media.network_state() == .no_source
	assert media.event_count('error') == 1
	assert app.media_players[0].handle == unsafe { nil }
	app.poll_media_playback()
	assert media.event_count('error') == 1
}
