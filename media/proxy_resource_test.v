// vtest build: macos
module main

import browsersettings
import dom
import html
import json2
import os
import page
import platform
import time

struct NativeMediaProxyPorts {
	origin_port int
	proxy_port  int
}

struct NativeMediaProxyStats {
	requests    []string
	proxy_hosts []string
}

fn proxy_media_owner(source string) &BrowserMediaOwner {
	page_owner := page.Page.create(1) or { panic(err) }
	document := parse_browser_navigation_document_for_page_with_response_time('<video muted preload="metadata" src="${source}"></video>',
		dom.URL{ value: 'http://media-fixture.invalid/index.html' }, none, none,
		unsafe { &dom.Page(page_owner) }, time.sys_mono_now())
	mut owner := new_browser_media_owner(document)
	owner.install_document_media_playback()
	return owner
}

fn proxy_media_poll(mut owner BrowserMediaOwner) {
	platform.pump_native_events(0.01)
	mut loop := html.main_thread_event_loop()
	loop.process()
	owner.poll_media_playback(0)
}

fn test_proxied_native_media_uses_browser_fetch_and_retains_its_local_file() {
	$if !macos {
		return
	}
	directory := os.join_path(os.temp_dir(), 'vox-proxied-media-test-${os.getpid()}-${time.sys_mono_now()}')
	os.mkdir_all(directory)!
	defer { os.rmdir_all(directory) or {} }
	keys := ['VOX_PROXY', 'NO_PROXY', 'no_proxy', 'LADYBIRD_CACHE_DIR', 'TMPDIR']
	mut previous := map[string]string{}
	for key in keys { if value := os.getenv_opt(key) { previous[key] = value } }
	defer {
		for key in keys {
			if value := previous[key] {
				os.setenv(key, value, true)
			} else {
				os.unsetenv(key)
			}
		}
		browsersettings.initialize(os.join_path(directory, 'absent.json')) or { panic(err) }
	}
	browsersettings.initialize(os.join_path(directory, 'settings.json'))!
	os.setenv('LADYBIRD_CACHE_DIR', os.join_path(directory, 'cache'), true)
	staging := os.join_path(directory, 'staged media')
	os.mkdir(staging)!
	os.setenv('TMPDIR', staging, true)
	ffmpeg := os.find_abs_path_of_executable('ffmpeg')!
	generated := os.exec([ffmpeg, '-v', 'error', '-y', '-f', 'lavfi', '-i',
		'testsrc2=size=64x36:rate=24:duration=1', '-c:v', 'libx264', '-pix_fmt', 'yuv420p', '-movflags',
		'+faststart', os.join_path(directory, 'movie.mp4')])
	assert generated.exit_code == 0, generated.output
	python := os.find_abs_path_of_executable('python3')!
	mut server := os.new_process(python)
	server.set_args([os.join_path(@VMODROOT, 'media/fixtures/native_proxy.py'), directory])
	server.set_redirect_stdio()
	server.run()
	defer {
		server.signal_kill()
		server.wait()
		server.close()
	}
	ready := os.join_path(directory, 'ready.json')
	deadline := time.sys_mono_now() + 5 * time.second
	for !os.exists(ready) && time.sys_mono_now() < deadline { time.sleep(10 * time.millisecond) }
	assert os.exists(ready), 'Media proxy fixture did not start'
	ports := json2.decode[NativeMediaProxyPorts](os.read_file(ready)!)!
	os.setenv('VOX_PROXY', 'socks5h://127.0.0.1:${ports.proxy_port}', true)
	os.setenv('NO_PROXY', '127.0.0.1', true)
	os.setenv('no_proxy', '127.0.0.1', true)
	// The first hop bypasses the proxy. Its redirect has an unresolvable host
	// that only the local SOCKS fixture can serve.
	address := 'http://127.0.0.1:${ports.origin_port}/redirect.mp4'
	assert browser_media_requires_browser_transport(dom.URL{ value: address })
	mut owner := proxy_media_owner(address)
	defer { owner.close() }
	loaded_by := time.sys_mono_now() + 10 * time.second
	for time.sys_mono_now() < loaded_by {
		proxy_media_poll(mut owner)
		if owner.media_players.len == 1 && owner.media_players[0].metadata_loaded { break }
	}
	assert owner.media_players.len == 1
	mut player := owner.media_players[0]
	assert player.metadata_loaded, 'Native player could not decode the fetched MP4'
	assert player.handle != unsafe { nil }
	assert C.native_media_width(player.handle) == 64 && C.native_media_height(player.handle) == 36
	assert player.media.current_src() == address
	retained := player.resource_directory
	assert retained != '' && os.is_dir(retained)
	assert os.read_bytes(os.join_path(retained, 'resource.mp4'))! == os.read_bytes(os.join_path(directory, 'movie.mp4'))!
	stats_path := os.join_path(directory, 'stats.json')
	stats := json2.decode[NativeMediaProxyStats](os.read_file(stats_path)!)!
	assert '/redirect.mp4' in stats.requests && '/movie.mp4' in stats.requests
	assert 'proxied-media.invalid' in stats.proxy_hosts
	player.close()
	assert !os.exists(retained)
	assert player.resource_directory == ''
	// A missing archived resource must fail without creating a native player.
	missing := 'http://proxied-media.invalid:${ports.origin_port}/missing.mp4'
	mut failed := proxy_media_owner(missing)
	defer { failed.close() }
	for _ in 0 .. 8 { proxy_media_poll(mut failed) }
	assert failed.media_players.len == 1
	assert failed.media_players[0].handle == unsafe { nil }
	assert failed.media_players[0].resource_directory == ''
	if unexpected := browser_stage_native_media_resource(dom.URL{ value: missing + '?error-lifetime=1' }, address) {
		os.rmdir_all(unexpected.directory) or {}
		assert false, 'Missing media must fail'
	} else {
		assert err.msg() == 'HTTP 404'
	}
	if unexpected := browser_stage_native_media_resource(dom.URL{ value: 'http://proxied-media.invalid:${ports.origin_port}/playlist.m3u8' }, address) {
		os.rmdir_all(unexpected.directory) or {}
		assert false, 'Playlist must not escape through a native URL loader'
	} else {
		assert err.msg().contains('streaming resource loader')
	}
	// A reachable local origin cannot become a direct fallback for a refused proxy.
	os.setenv('VOX_PROXY', 'socks5h://127.0.0.1:1', true)
	os.setenv('NO_PROXY', '', true)
	os.setenv('no_proxy', '', true)
	before := json2.decode[NativeMediaProxyStats](os.read_file(stats_path)!)!.requests.len
	if unexpected := browser_stage_native_media_resource(dom.URL{ value: 'http://127.0.0.1:${ports.origin_port}/movie.mp4?uncached=1' }, address) {
		os.rmdir_all(unexpected.directory) or {}
		assert false, 'A failed proxy was bypassed'
	}
	after := json2.decode[NativeMediaProxyStats](os.read_file(stats_path)!)!.requests.len
	assert before == after
	assert !browser_media_requires_browser_transport(dom.URL{ value: 'file:///tmp/local.mp4' })
}
