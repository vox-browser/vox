module main

import dom
import html
import os
import page
import platform
import time

fn test_webm_capabilities_reject_audio_and_unknown_codecs() {
	assert browser_webm_video_codecs_supported('video/webm')
	assert browser_webm_video_codecs_supported('video/webm; codecs="vp8"')
	assert browser_webm_video_codecs_supported('video/webm; CODECS="vp09.00.10.08"')
	assert !browser_webm_video_codecs_supported('video/webm; codecs="vp9,opus"')
	assert !browser_webm_video_codecs_supported('video/webm; codecs="vorbis"')
	assert !browser_webm_video_codecs_supported('video/webm; codecs="av01.0.04M.08"')
	assert !browser_webm_video_codecs_supported('video/webm; codecs=""')
}

fn test_typed_webm_source_without_extension_uses_browser_resource_loader_and_transparent_preview() {
	$if !macos {
		return
	}
	assert C.native_media_supports_webm() != 0, 'Test requires the production FFmpeg backend'
	assert browser_native_media_type('video/webm; codecs="vp9"') == .maybe
	assert browser_native_media_type('video/webm; codecs="vp9,opus"') == .empty
	ffmpeg := os.find_abs_path_of_executable('ffmpeg') or { panic(err) }
	directory := os.join_path(os.temp_dir(), 'vox-webm-preview-test-${os.getpid()}-${time.sys_mono_now()}')
	os.mkdir(directory)!
	defer { os.rmdir_all(directory) or {} }
	mut pixels := []u8{len: 16 * 16 * 4}
	for index in 0 .. 16 * 16 {
		pixels[index * 4] = 32
		pixels[index * 4 + 1] = 64
		pixels[index * 4 + 2] = 128
		pixels[index * 4 + 3] = [u8(0), 64, 128, 255][index % 4]
	}
	raw := os.join_path(directory, 'input.rgba')
	os.write_file_array(raw, pixels)!
	for codec in ['libvpx', 'libvpx-vp9'] {
		movie := os.join_path(directory, codec)
		result := os.exec([ffmpeg, '-v', 'error', '-y', '-f', 'rawvideo', '-pix_fmt', 'rgba', '-s',
			'16x16', '-r', '1', '-i', raw, '-c:v', codec, '-pix_fmt', 'yuva420p', '-auto-alt-ref',
			'0', '-f', 'webm', movie])
		assert result.exit_code == 0, result.output
		owner := page.Page.create(1)!
		mut app := &BrowserApp{
			document: parse_browser_navigation_document_for_page_with_response_time('<video id="logo" muted preload="metadata"><source src="${codec}" type="video/webm"><source src="missing.mp4" type="video/mp4"></video>',
				dom.URL{ value: 'file://${directory}/index.html' }, none, none,
				unsafe { &dom.Page(owner) }, time.sys_mono_now())
		}
		defer { app.close_media_playback() }
		app.install_document_media_playback()
		deadline := time.sys_mono_now() + 5 * time.second
		mut event_loop := html.main_thread_event_loop()
		for time.sys_mono_now() < deadline {
			platform.pump_native_events(0.01)
			app.poll_media_playback()
			event_loop.process()
			if app.media_players[0].frame != none { break }
		}
		player := app.media_players[0]
		assert player.media.current_src() == 'file://${movie}'
		assert player.media.error() == none && player.media.paused()
		assert player.mime_type == 'video/webm'
		frame := player.frame or { panic('Missing WebM preview') }
		bitmap := frame.rgba_bitmap or { panic('Missing RGBA preview') }
		assert bitmap.width == 16 && bitmap.height == 16
		mut transparent := false
		mut translucent := false
		for index in 0 .. 16 * 16 {
			alpha := bitmap.data[index * 4 + 3]
			transparent = transparent || alpha == 0
			translucent = translucent || (alpha > 0 && alpha < 255)
		}
		assert transparent && translucent
		generation := frame.generation
		app.poll_media_playback()
		assert frame.generation == generation
	}
}
