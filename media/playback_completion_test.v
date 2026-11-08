module main

import browserjs
import dom
import html
import os
import page
import platform
import time

fn completion_movie() string {
	ffmpeg := os.find_abs_path_of_executable('ffmpeg') or { panic('ffmpeg is required') }
	directory := os.join_path(os.temp_dir(), 'vox-media-completion-${os.getpid()}-${time.sys_mono_now()}')
	os.mkdir_all(directory) or { panic(err) }
	movie := os.join_path(directory, 'movie.mp4')
	generated := os.exec([ffmpeg, '-v', 'error', '-y', '-f', 'lavfi', '-i',
		'testsrc2=size=64x36:rate=24:duration=1', '-c:v', 'libx264', '-pix_fmt', 'yuv420p',
		'-movflags', '+faststart', movie])
	assert generated.exit_code == 0, generated.output
	return movie
}

fn completion_app(movie string, kind string, looping bool) &BrowserApp {
	owner := page.Page.create(1) or { panic(err) }
	mut app := &BrowserApp{
		document: parse_browser_navigation_document_for_page_with_response_time('<${kind} id="player" muted></${kind}>',
			dom.URL{ value: 'file://${os.dir(movie)}/page.html' }, none, none,
			unsafe { &dom.Page(owner) }, time.sys_mono_now())
	}
	app.install_document_media_playback()
	mut runtime := browserjs.Runtime.create()
	app.js_runtime = runtime
	mut messages := []string{}
	run_document_script_sources_with_media_loader(app.document, app.document.url.serialize(), [
		browserjs.ScriptSource{
			code: 'globalThis.completionEvents=[];globalThis.replayVisible=false;
for(var name of ["timeupdate","pause","ended"])player.addEventListener(name,function(e){completionEvents.push(e.type);if(e.type==="ended")replayVisible=player.ended&&player.paused;});
player.loop=${looping};player.src="movie.mp4";player.load();player.play();'
			url: app.document.url.serialize()
		},
	], runtime, browser_fetch_image_request, none, none, fn [app] (element &dom.Element) {
		mut browser := unsafe { &BrowserApp(app) }
		browser.install_media_playback(element)
	}, mut messages)
	assert messages == []
	assert app.media_players.len == 1
	assert app.media_players[0].handle != unsafe { nil }
	assert app.media_players[0].media.loop() == looping
	return app
}

fn completion_poll(mut app BrowserApp) {
	platform.pump_native_events(0.01)
	app.poll_media_playback()
	mut event_loop := html.main_thread_event_loop()
	for _ in 0 .. 10 { event_loop.process() }
}

fn completion_wait_for_end(mut app BrowserApp, count int) {
	media := app.media_players[0].media
	deadline := time.sys_mono_now() + 10 * time.second
	for media.event_count('ended') < count && time.sys_mono_now() < deadline {
		completion_poll(mut app)
	}
	assert media.error() == none
	assert media.event_count('ended') == count
	assert media.ended() && media.paused()
	assert app.js_runtime.evaluate_host('replayVisible&&completionEvents.slice(-3).join(",")==="timeupdate,pause,ended"') or { panic(err) } == 'true'
}

fn test_native_media_completion_replays_and_handles_paused_seeks_to_the_end() {
	$if !macos { return }
	movie := completion_movie()
	defer { os.rmdir_all(os.dir(movie)) or {} }
	for kind in ['video', 'audio'] {
		mut app := completion_app(movie, kind, false)
		defer {
			app.close_media_playback()
			app.js_runtime.close()
		}
		completion_wait_for_end(mut app, 1)
		mut media := app.media_players[0].media
		for _ in 0 .. 20 { completion_poll(mut app) }
		assert media.event_count('ended') == 1 && media.event_count('pause') == 1
		assert app.js_runtime.evaluate_host('replayVisible=false;player.play();true')! == 'true'
		deadline := time.sys_mono_now() + 5 * time.second
		for time.sys_mono_now() < deadline {
			completion_poll(mut app)
			if !media.seeking() && !media.ended() && media.current_time() > 0.1 { break }
		}
		assert !media.seeking() && !media.ended() && !media.paused(), 'seeking=${media.seeking()} ended=${media.ended()} paused=${media.paused()} time=${media.current_time()} ends=${media.event_count('ended')}'
		assert media.current_time() > 0.1 && media.current_time() < media.duration()
		completion_wait_for_end(mut app, 2)
		assert media.event_count('pause') == 2
		assert app.js_runtime.evaluate_host('player.currentTime=0.5;true')! == 'true'
		seek_deadline := time.sys_mono_now() + 5 * time.second
		for media.seeking() && time.sys_mono_now() < seek_deadline {
			completion_poll(mut app)
		}
		assert !media.seeking() && !media.ended() && media.paused()
		assert app.js_runtime.evaluate_host('player.currentTime=player.duration;true')! == 'true'
		end_deadline := time.sys_mono_now() + 5 * time.second
		for media.event_count('ended') < 3 && time.sys_mono_now() < end_deadline {
			completion_poll(mut app)
		}
		assert media.event_count('ended') == 3 && media.event_count('pause') == 2
		assert !media.seeking() && media.ended() && media.paused()
	}
}

fn test_native_video_loops_repeatedly_and_ends_after_loop_is_removed() {
	$if !macos { return }
	movie := completion_movie()
	defer { os.rmdir_all(os.dir(movie)) or {} }
	mut app := completion_app(movie, 'video', true)
	defer {
		app.close_media_playback()
		app.js_runtime.close()
	}
	mut media := app.media_players[0].media
	deadline := time.sys_mono_now() + 10 * time.second
	for time.sys_mono_now() < deadline {
		completion_poll(mut app)
		assert !media.ended() && !media.paused(), 'ended=${media.ended()} paused=${media.paused()} time=${media.current_time()} seeks=${media.event_count('seeked')}'
		assert media.event_count('ended') == 0 && media.event_count('pause') == 0
		if media.event_count('seeked') >= 2 && media.current_time() > 0.1 { break }
	}
	assert media.error() == none
	assert media.event_count('seeking') == 2 && media.event_count('seeked') == 2
	assert media.current_time() > 0.1 && media.current_time() < media.duration()
	assert app.js_runtime.evaluate_host('player.loop=false;true')! == 'true'
	completion_wait_for_end(mut app, 1)
}
