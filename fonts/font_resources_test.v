module main

import adblock
import css
import dom
import fetch
import html
import os
import requestserver
import time

fn test_font_response_cache_requires_actual_status_headers_and_redirect_provenance() {
	previous := os.getenv_opt('LADYBIRD_CACHE_DIR')
	cache := os.join_path(os.temp_dir(), 'vox-font-provenance-${os.getpid()}-${time.sys_mono_now()}')
	os.setenv('LADYBIRD_CACHE_DIR', cache, true)
	defer {
		if value := previous { os.setenv('LADYBIRD_CACHE_DIR', value, true) } else { os.unsetenv('LADYBIRD_CACHE_DIR') }
		os.rmdir_all(cache) or {}
	}
	address := 'https://fonts-cache.example/font.ttf'
	mut request := fetch.Request.create()
	request.url_list = [dom.URL{value:address}]
	request.destination = .font
	headers := [adblock.ResponseHeader{name:'Content-Type',value:'font/ttf'},
		adblock.ResponseHeader{name:'Access-Control-Allow-Origin',value:'https://owner.example'},
		adblock.ResponseHeader{name:'Cache-Control',value:'public, max-age=60'},
		adblock.ResponseHeader{name:'Date',value:time.utc().http_header_string()}]
	cache_resource_response_headers(address, address, 'font bytes', headers)
	assert browser_cached_font_response(request) == none
	cache_resource_response_headers_with_status(address, address, 'font bytes', headers, 200)
	response := browser_cached_font_response(request) or { panic('missing cached font') }
	assert response.status == 200
	assert response.body?.bytes().bytestr() == 'font bytes'
	assert response.header_list.get('Access-Control-Allow-Origin')? == 'https://owner.example'
	assert response.url_list == request.url_list
	request.destination = .image
	assert browser_cached_font_response(request) == none
	request.destination = .font
	request.method = 'POST'
	assert browser_cached_font_response(request) == none
	request.method = 'GET'
	for status in [0, 199, 302, 404] {
		cache_resource_response_headers_with_status(address, address, 'font bytes', headers, status)
		assert browser_cached_font_response(request) == none
	}
	cache_resource_response_headers_with_status(address, 'https://elsewhere.example/font.ttf', 'font bytes', headers, 200)
	assert browser_cached_font_response(request) == none
	cache_resource_response_headers_with_status(address, address, 'font bytes', headers, 200)
	path := browser_cache_entry_path(cache, 'resources', address)
	os.rm(path + '.headers.json')!
	assert browser_cached_font_response(request) == none
	cache_resource_response_headers_with_status(address, address, 'font bytes', headers, 200)
	cache_resource_response_headers(address, address, 'unknown-status replacement', headers)
	assert !os.exists(path + '.status')
	assert browser_cached_font_response(request) == none
	cache_resource_response_headers_with_status(address, address, '', headers, 200)
	assert !os.exists(path + '.status')
}

fn test_cached_font_fetch_stays_asynchronous_and_enforces_cors_and_adblock() {
	$if !darwin { return }
	previous := os.getenv_opt('LADYBIRD_CACHE_DIR')
	cache := os.join_path(os.temp_dir(), 'vox-font-fetch-cache-${os.getpid()}-${time.sys_mono_now()}')
	os.setenv('LADYBIRD_CACHE_DIR', cache, true)
	install_browser_font_resource_cache()
	defer {
		requestserver.install_native_font_response_cache_provider(none)
		if value := previous { os.setenv('LADYBIRD_CACHE_DIR', value, true) } else { os.unsetenv('LADYBIRD_CACHE_DIR') }
		os.rmdir_all(cache) or {}
	}
	bytes := os.read_file('/System/Library/Fonts/Supplemental/Arial.ttf')!
	for index, address in ['https://fonts-cache.example/allowed.ttf',
		'https://fonts-cache.example/denied.ttf', 'https://www.google-analytics.com/analytics.js'] {
		mut document := html.parse_document_with_url('<!doctype html><body>font</body>', dom.URL{value:'https://owner-font-cache.example/'})
		document.set_origin(document.url.origin())
		_ = html.WindowModel.create_top_level(document, none, 'cached-font')!
		settings := unsafe { &html.EnvironmentSettingsObject(document.relevant_settings_object()) }
		mut owner := settings.responsible_event_loop()
		mut computer := css.FontComputer.create_for_document(document)
		mut set := css.FontFaceSet.create_for_font_computer(computer)
		mut transport := requestserver.NativeFontFetchTransport.create()!
		computer.set_fetch_host(transport.fetch_host())
		mut headers := [adblock.ResponseHeader{name:'Content-Type',value:'font/ttf'},
			adblock.ResponseHeader{name:'Cache-Control',value:'public, max-age=60'},
			adblock.ResponseHeader{name:'Date',value:time.utc().http_header_string()}]
		if index != 1 { headers << adblock.ResponseHeader{name:'Access-Control-Allow-Origin',value:'*'} }
		cache_resource_response_headers_with_status(address, address, bytes, headers, 200)
		mut face := css.FontFaceObject.construct_impl('Cached native font',
			css.FontFaceSource.from_string('url("${address}")'), css.FontFaceDescriptors{})
		set.add(face)!
		promise := face.load()
		assert face.status() == .loading
		assert promise.state == .pending
		deadline := time.sys_mono_now() + 4 * time.second
		owner.spin_until(fn [promise, deadline] () bool { return promise.state != .pending || time.sys_mono_now() >= deadline })
		if index == 0 {
			assert promise.state == .fulfilled
			assert face.status() == .loaded
			assert face.parsed_font != unsafe { nil }
			assert os.is_file(face.parsed_font.source_path)
		} else {
			assert promise.state == .rejected
			assert face.status() == .error
			assert face.parsed_font == unsafe { nil }
		}
		transport.close()
		document.finalize()
	}
}

fn test_capture_waits_for_existing_fonts_and_clean_layout_without_materializing_a_set() {
	mut document := html.parse_document('<!doctype html><body>font capture</body>')
	mut app := BrowserApp{document:document,layout_tree_only:true}
	defer { document.finalize() }
	assert document.existing_font_face_set() == none
	assert app.font_resources_ready_for_capture()
	assert document.existing_font_face_set() == none
	app.relayout(320, 240 + app.chrome_height())
	mut fonts := css.css_style_computer_for(document).font_face_set_
	assert !app.font_resources_ready_for_capture()
	assert !app.document_resources_ready_for_capture()
	document.update_readiness(.complete)
	loop := html.main_thread_event_loop()
	loop.update_font_face_sets_pending_on_the_environment([document])
	assert app.font_resources_ready_for_capture()
	assert app.document_resources_ready_for_capture()
	failed_face := css.FontFaceObject.construct_impl('Failed capture font',
		css.FontFaceSource.from_string(''), css.FontFaceDescriptors{})
	assert failed_face.status() == .error
	fonts.add(failed_face)!
	assert app.document_resources_ready_for_capture()
	fonts.switch_to_loading()
	assert !app.font_resources_ready_for_capture()
	assert !app.document_resources_ready_for_capture()
	fonts.switch_to_loaded()
	assert app.font_resources_ready_for_capture()
	assert app.document_resources_ready_for_capture()
	mut delayer := dom.DocumentLoadEventDelayer.new(mut document)
	assert !app.font_resources_ready_for_capture()
	assert !app.document_resources_ready_for_capture()
	delayer.finish()
	assert app.font_resources_ready_for_capture()
	assert app.document_resources_ready_for_capture()
	mut body := document.body()?.as_node().as_element()?
	body.set_attribute_value('style', 'width:71px')
	assert !app.font_resources_ready_for_capture()
	assert !app.document_resources_ready_for_capture()
	app.relayout(320, 240 + app.chrome_height())
	assert app.font_resources_ready_for_capture()
	assert app.document_resources_ready_for_capture()
}

fn test_capture_waits_for_completed_document_without_materializing_fonts() {
	assert !BrowserApp{}.document_resources_ready_for_capture()
	mut document := html.parse_document('<!doctype html><body>complete capture</body>')
	app := BrowserApp{document:document,layout_tree_only:true}
	defer { document.finalize() }
	assert document.existing_font_face_set() == none
	document.update_readiness(.loading)
	assert app.font_resources_ready_for_capture()
	assert !app.document_resources_ready_for_capture()
	document.update_readiness(.interactive)
	assert app.font_resources_ready_for_capture()
	assert !app.document_resources_ready_for_capture()
	document.update_readiness(.complete)
	assert app.document_resources_ready_for_capture()
	assert document.existing_font_face_set() == none
	document.update_readiness(.loading)
	assert !app.document_resources_ready_for_capture()
	assert document.existing_font_face_set() == none
}
