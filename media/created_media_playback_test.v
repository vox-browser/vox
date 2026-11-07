module main

import browserjs
import dom
import html
import page
import os
import platform
import time

fn created_media_playback_document(markup string) &dom.Document {
	owner := page.Page.create(1) or { panic(err) }
	return parse_browser_navigation_document_for_page_with_response_time(markup,
		dom.URL{ value: 'https://created-media.example.test/' }, none, none,
		unsafe { &dom.Page(owner) }, time.sys_mono_now())
}

fn created_media_playback_run(mut app BrowserApp, source string) {
	mut runtime := browserjs.Runtime.create()
	app.js_runtime = runtime
	mut messages := []string{}
	run_document_script_sources_with_media_loader(app.document, app.document.url.serialize(), [
		browserjs.ScriptSource{
			code: source
			url:  app.document.url.serialize()
		},
	], runtime, browser_fetch_image_request, none, none, fn [app] (element &dom.Element) {
		mut browser := unsafe { &BrowserApp(app) }
		browser.install_media_playback(element)
	}, mut messages)
	assert messages == []
}

// Old Reddit's RedditVideoPlayer builds its <video> with jQuery, appends it,
// then assigns the HLS src and calls load(). Document.createElement() makes
// the owner in the native document factory; it still needs the native decoder
// hooks, or load() fails with "No media fetch hook" and nothing plays.
fn test_document_created_video_appended_before_src_and_load_gets_native_playback() {
	$if !macos {
		return
	}
	mut app := &BrowserApp{
		document: created_media_playback_document('<div id="root"></div>')
	}
	defer {
		app.close_media_playback()
		app.js_runtime.close()
	}
	created_media_playback_run(mut app, 'var v=document.createElement("video");v.setAttribute("autoplay","autoplay");v.setAttribute("playsinline","playsinline");document.getElementById("root").appendChild(v);v.setAttribute("src","https://created-media.example.test/missing.m3u8");v.load();globalThis.createdVideo=v;')
	assert app.media_players.len == 1
	player := app.media_players[0]
	root := app.document.get_element_by_id('root') or { panic('missing root') }
	assert voidptr(player.element.as_node().parent() or { panic('detached player') }) == voidptr(root.as_node())
	assert player.media.error() == none
	assert player.media.current_src() == 'https://created-media.example.test/missing.m3u8'
	assert player.handle != unsafe { nil }
	// Further bindings of the same owner do not install a second player.
	assert (app.js_runtime.evaluate_host('createdVideo.paused&&document.querySelector("video")===createdVideo') or { panic(err) }) == 'true'
	assert app.media_players.len == 1
}

// jQuery builds tags with attributes, such as Reddit's seek preview
// `<video muted preload>`, through fragment parsing instead.
fn test_fragment_parsed_video_gets_native_playback_once() {
	$if !macos {
		return
	}
	mut app := &BrowserApp{
		document: created_media_playback_document('<video id="parsed"></video><div id="root"></div>')
	}
	app.install_document_media_playback()
	defer {
		app.close_media_playback()
		app.js_runtime.close()
	}
	assert app.media_players.len == 1
	created_media_playback_run(mut app, 'var holder=document.createElement("div");holder.innerHTML="<video muted preload></video>";var v=holder.firstChild;v.setAttribute("src","https://created-media.example.test/preview.mp4");document.getElementById("root").appendChild(v);v.load();void document.getElementById("parsed").paused;')
	assert app.media_players.len == 2
	player := app.media_players[1]
	assert player.element.local_name() == 'video' && player.element.has_attribute('muted')
	assert player.media.error() == none
	assert player.handle != unsafe { nil }
}

// End to end on macOS: a script-created muted autoplay video decodes real
// frames from a local file through the native AVFoundation player.
fn test_document_created_autoplay_video_decodes_native_frames() {
	$if !macos {
		return
	}
	ffmpeg := os.find_abs_path_of_executable('ffmpeg') or { return }
	directory := os.join_path(os.temp_dir(), 'vox-created-media-${os.getpid()}-${time.sys_mono_now()}')
	os.mkdir_all(directory) or { panic(err) }
	defer { os.rmdir_all(directory) or {} }
	movie := os.join_path(directory, 'movie.mp4')
	generated := os.execute('${os.quoted_path(ffmpeg)} -v error -y -f lavfi -i testsrc2=size=64x36:rate=24:duration=2 -c:v libx264 -pix_fmt yuv420p -movflags +faststart ${os.quoted_path(movie)}')
	assert generated.exit_code == 0, generated.output
	owner := page.Page.create(1) or { panic(err) }
	mut app := &BrowserApp{
		document: parse_browser_navigation_document_for_page_with_response_time('<div id="root"></div>',
			dom.URL{ value: 'file://${directory}/page.html' }, none, none, unsafe { &dom.Page(owner) },
			time.sys_mono_now())
	}
	defer {
		app.close_media_playback()
		app.js_runtime.close()
	}
	created_media_playback_run(mut app, 'var v=document.createElement("video");v.setAttribute("autoplay","autoplay");document.getElementById("root").appendChild(v);v.muted=true;v.setAttribute("src","movie.mp4");v.load();')
	assert app.media_players.len == 1
	player := app.media_players[0]
	settings := unsafe { &html.EnvironmentSettingsObject(app.document.relevant_settings_object()) }
	mut event_loop := settings.responsible_event_loop()
	deadline := time.sys_mono_now() + 10 * time.second
	for time.sys_mono_now() < deadline {
		platform.pump_native_events(0.01)
		app.poll_media_playback()
		event_loop.process()
		if player.frame != none && player.media.current_time() > 0.1 { break }
	}
	assert player.media.error() == none
	frame := player.frame or { panic('no decoded video frame') }
	assert frame.width == 64 && frame.height == 36
	assert !player.media.paused()
	assert player.media.current_time() > 0.1
}
