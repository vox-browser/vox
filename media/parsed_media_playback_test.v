module main

import browserjs
import dom
import html
import os
import page
import platform
import time

fn parsed_media_document(address string, markup string) &dom.Document {
	owner := page.Page.create(1) or { panic(err) }
	return parse_browser_navigation_document_for_page_with_response_time(markup, dom.URL{
		value: address
	}, none, none, unsafe { &dom.Page(owner) }, time.sys_mono_now())
}

// Run queued tasks (and native callbacks) until `done` holds or time runs out.
fn parsed_media_pump(mut app BrowserApp, seconds int, done fn () bool) {
	settings := unsafe { &html.EnvironmentSettingsObject(app.document.relevant_settings_object()) }
	mut event_loop := settings.responsible_event_loop()
	deadline := time.sys_mono_now() + u64(seconds) * time.second
	for !done() && time.sys_mono_now() < deadline {
		platform.pump_native_events(0.01)
		app.poll_media_playback()
		event_loop.process()
	}
}

fn parsed_media_player(app &BrowserApp, id string) &BrowserMediaPlayback {
	element := app.document.get_element_by_id(id) or { panic('missing ${id}') }
	for player in app.media_players {
		if voidptr(player.element) == voidptr(element) {
			return player
		}
	}
	panic('no native player for ${id}')
}

// Parsed media get their model only after the document is built, so the src
// change and insertion steps never invoked resource selection: a plain
// `<video autoplay src>` page stayed NETWORK_EMPTY and never played.
fn test_parsed_media_with_src_or_source_children_select_their_resource() {
	$if !macos {
		return
	}
	mut app := &BrowserApp{
		document: parsed_media_document('https://parsed-media.example.test/',
			'<video id="src" src="missing.m3u8"></video><video id="source"><source src="first.mp4"></video><video id="none"></video><audio id="audio" src="missing.mp3"></audio>')
	}
	defer { app.close_media_playback() }
	app.install_document_media_playback()
	assert app.media_players.len == 4
	// Selection is queued: listeners added by the page's scripts see loadstart.
	assert parsed_media_player(app, 'src').media.network_state() == .empty
	parsed_media_pump(mut app, 5, fn [app] () bool {
		return parsed_media_player(app, 'src').media.current_src() != ''
			&& parsed_media_player(app, 'source').media.current_src() != ''
			&& parsed_media_player(app, 'audio').media.current_src() != ''
	})
	src := parsed_media_player(app, 'src')
	assert src.media.current_src() == 'https://parsed-media.example.test/missing.m3u8'
	assert src.handle != unsafe { nil } && src.media.event_count('loadstart') == 1
	source := parsed_media_player(app, 'source')
	assert source.media.current_src() == 'https://parsed-media.example.test/first.mp4'
	assert source.handle != unsafe { nil }
	assert parsed_media_player(app, 'audio').media.current_src() == 'https://parsed-media.example.test/missing.mp3'
	none_ := parsed_media_player(app, 'none')
	assert none_.media.network_state() == .empty && none_.handle == unsafe { nil }
	assert none_.media.event_count('loadstart') == 0
}

// Media inserted after load through innerHTML may never get a script wrapper;
// its insertion steps install the native player and select the resource.
fn test_media_inserted_by_markup_after_load_gets_native_playback() {
	$if !macos {
		return
	}
	mut app := &BrowserApp{
		document: parsed_media_document('https://parsed-media.example.test/', '<div id="root"></div>')
	}
	defer {
		app.close_media_playback()
		app.js_runtime.close()
	}
	app.install_document_media_playback()
	assert app.media_players.len == 0
	mut runtime := browserjs.Runtime.create()
	app.js_runtime = runtime
	mut messages := []string{}
	run_document_script_sources_with_media_loader(app.document, app.document.url.serialize(), [
		browserjs.ScriptSource{
			code: 'document.getElementById("root").innerHTML="<video id=\\"late\\" src=\\"late.mp4\\" muted></video>";'
			url:  app.document.url.serialize()
		},
	], runtime, browser_fetch_image_request, none, none, fn [app] (element &dom.Element) {
		mut browser := unsafe { &BrowserApp(app) }
		browser.install_media_playback(element)
	}, mut messages)
	assert messages == []
	late := app.document.get_element_by_id('late') or { panic('missing inserted video') }
	assert late.as_node().is_connected()
	parsed_media_pump(mut app, 5, fn [app] () bool {
		return app.media_players.len == 1 && app.media_players[0].media.current_src() != ''
	})
	assert app.media_players.len == 1
	player := app.media_players[0]
	assert voidptr(player.element) == voidptr(late)
	assert player.media.current_src() == 'https://parsed-media.example.test/late.mp4'
	assert player.handle != unsafe { nil }
}

// End to end: a parsed muted autoplay video decodes frames without any script.
fn test_parsed_autoplay_video_decodes_native_frames() {
	$if !macos {
		return
	}
	ffmpeg := os.find_abs_path_of_executable('ffmpeg') or { return }
	directory := os.join_path(os.temp_dir(), 'vox-parsed-media-${os.getpid()}-${time.sys_mono_now()}')
	os.mkdir_all(directory) or { panic(err) }
	defer { os.rmdir_all(directory) or {} }
	movie := os.join_path(directory, 'movie.mp4')
	generated := os.execute('${os.quoted_path(ffmpeg)} -v error -y -f lavfi -i testsrc2=size=64x36:rate=24:duration=2 -c:v libx264 -pix_fmt yuv420p -movflags +faststart ${os.quoted_path(movie)}')
	assert generated.exit_code == 0, generated.output
	mut app := &BrowserApp{
		document: parsed_media_document('file://${directory}/page.html', '<video id="v" autoplay muted src="movie.mp4"></video>')
	}
	defer { app.close_media_playback() }
	app.install_document_media_playback()
	parsed_media_pump(mut app, 10, fn [app] () bool {
		player := parsed_media_player(app, 'v')
		return player.frame != none && player.media.current_time() > 0.1
	})
	player := parsed_media_player(app, 'v')
	assert player.media.error() == none
	frame := player.frame or { panic('no decoded video frame') }
	assert frame.width == 64 && frame.height == 36
	assert !player.media.paused()
}
