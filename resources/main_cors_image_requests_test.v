module main

import encoding.base64
import html
import net
import page
import platform
import requestserver
import time

fn serve_cors_image(mut listener net.TcpListener, allow_origin string, allow_credentials bool, redirect string, requests chan string) {
	mut socket := listener.accept() or {
		requests <- ''
		return
	}
	defer { socket.close() or {} }
	socket.set_read_timeout(5 * time.second)
	mut headers := ''
	for !headers.contains('\r\n\r\n') {
		mut buffer := []u8{len: 4096}
		count := socket.read(mut buffer) or { break }
		if count == 0 { break }
		headers += buffer[..count].bytestr()
	}
	requests <- headers
	if redirect != '' {
		socket.write_string('HTTP/1.1 302 Found\r\nAccess-Control-Allow-Origin: ${allow_origin}\r\nLocation: ${redirect}\r\nContent-Length: 0\r\nConnection: close\r\n\r\n') or { panic(err) }
		return
	}
	body := base64.decode('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=').bytestr()
	origin_header := if allow_origin == '' {
		''
	} else {
		'Access-Control-Allow-Origin: ${allow_origin}\r\n'
	}
	credentials_header := if allow_credentials {
		'Access-Control-Allow-Credentials: true\r\n'
	} else {
		''
	}
	socket.write_string('HTTP/1.1 200 OK\r\nContent-Type: image/png\r\n${origin_header}${credentials_header}Content-Length: ${body.len}\r\nConnection: close\r\n\r\n${body}') or { panic(err) }
}

fn cors_image_app(mode string, address string) !&BrowserApp {
	owner := page.Page.create(1)!
	mut app := &BrowserApp{ page_model: owner, script_policy: .enabled, viewport_width: 100, viewport_height: 100 }
	source := if address == '' { '' } else { 'image.src="${address}/image.png";' }
	app.install_loaded_page(LoadedPage{
		url:          'http://image-owner.test/page'
		markup:       '<!doctype html><canvas id="drawing" width="1" height="1"></canvas><script>
globalThis.result="pending";globalThis.pixel=null;globalThis.readbackError=null;
globalThis.image=new Image();image.crossOrigin="${mode}";
image.onload=function(){result="loaded";const ctx=drawing.getContext("2d");ctx.drawImage(image,0,0);try{pixel=Array.from(ctx.getImageData(0,0,1,1).data)}catch(error){readbackError=error.name}};
image.onerror=()=>{result="error"};${source}</script>'
		content_type: 'text/html'
	}, false)
	return app
}

fn close_cors_image_app(mut app BrowserApp) {
	if mut loader := app.image_request_loader { loader.cancel() }
	app.js_runtime.close()
	app.document.finalize()
}

fn cors_image_result(app &BrowserApp) !string {
	mut loop := html.main_thread_event_loop()
	deadline := time.sys_mono_now() + 5 * time.second
	loop.spin_until(fn [app, deadline] () bool {
		platform.pump_native_events(0.001)
		mut plugin := platform.EventLoopPlugin.the()
		for _ in 0 .. 8 { if !plugin.run_one_deferred() { break } }
		mut current := unsafe { &BrowserApp(app) }
		current.poll_browser_image_requests()
		return (app.js_runtime.evaluate_host('result') or { 'pending' }) != 'pending' || time.sys_mono_now() >= deadline
	})
	return app.js_runtime.evaluate_host('result')!
}

fn wait_for_cors_image(app &BrowserApp, expected string) ! {
	actual := cors_image_result(app)!
	loader := app.image_request_loader or { panic('missing image loader') }
	assert actual == expected, 'actual=${actual} pending=${loader.cors_requests.len} messages=${app.js_messages.join('\n')}'
	assert loader.cors_requests.len == 0 && loader.cors_queued.len == 0 && loader.active_fetches == 0
	if expected == 'loaded' {
		assert app.js_runtime.evaluate_host('image.naturalWidth===1&&readbackError===null')! == 'true'
		assert app.js_runtime.evaluate_host('JSON.stringify(pixel)')! == '[0,0,0,255]'
	}
}

fn check_browser_cors_image(mode string, allow_origin string, allow_credentials bool, expected string) ! {
	requestserver.install_native_font_fetch_host()!
	defer { requestserver.close_native_font_fetch_host() }
	mut listener := net.listen_tcp(.ip, '127.0.0.1:0')!
	listener.set_accept_timeout(2 * time.second)
	defer { listener.close() or {} }
	address := 'http://${listener.addr()!}'
	requests := chan string{cap: 1}
	spawn serve_cors_image(mut listener, allow_origin, allow_credentials, '', requests)
	mut app := cors_image_app(mode, address)!
	defer { close_cors_image_app(mut app) }
	wait_for_cors_image(app, expected)!
	mut headers := ''
	select {
		value := <-requests {
			headers = value
		}
		3 * time.second {
		}
	}
	assert headers.to_lower().contains('origin: http://image-owner.test')
	listener.set_accept_timeout(20 * time.millisecond)
	if mut extra := listener.accept() {
		extra.close() or {}
		assert false, 'DOM replay started a duplicate image request'
	}
}

fn test_browser_anonymous_cors_image_accepts_wildcard_and_keeps_canvas_origin_clean() {
	$if !darwin {
		return
	}
	check_browser_cors_image('anonymous', '*', false, 'loaded')!
}

fn test_browser_anonymous_cors_image_rejects_missing_or_wrong_allow_origin() {
	$if !darwin {
		return
	}
	check_browser_cors_image('anonymous', '', false, 'error')!
	check_browser_cors_image('anonymous', 'http://other-owner.test', false, 'error')!
}

fn test_browser_credentialed_cors_image_requires_exact_origin_and_allow_credentials() {
	$if !darwin {
		return
	}
	check_browser_cors_image('use-credentials', '*', true, 'error')!
	check_browser_cors_image('use-credentials', 'http://image-owner.test', false, 'error')!
	check_browser_cors_image('use-credentials', 'http://image-owner.test', true, 'loaded')!
}

fn test_browser_cors_image_checks_the_final_cross_origin_redirect_response() {
	$if !darwin {
		return
	}
	requestserver.install_native_font_fetch_host()!
	defer { requestserver.close_native_font_fetch_host() }
	for allowed in [true, false] {
		mut source := net.listen_tcp(.ip, '127.0.0.1:0')!
		mut target := net.listen_tcp(.ip, '127.0.0.1:0')!
		source.set_accept_timeout(2 * time.second)
		target.set_accept_timeout(2 * time.second)
		defer {
			source.close() or {}
			target.close() or {}
		}
		requests := chan string{cap: 2}
		spawn serve_cors_image(mut source, '*', false, 'http://${target.addr()!}/image.png', requests)
		spawn serve_cors_image(mut target, if allowed { '*' } else { '' }, false, '', requests)
		mut app := cors_image_app('anonymous', 'http://${source.addr()!}')!
		defer { close_cors_image_app(mut app) }
		wait_for_cors_image(app, if allowed { 'loaded' } else { 'error' })!
		assert requests.len == 2
	}
}

fn test_browser_cors_image_uses_the_owning_documents_image_csp() {
	$if !darwin {
		return
	}
	requestserver.install_native_font_fetch_host()!
	defer { requestserver.close_native_font_fetch_host() }
	mut listener := net.listen_tcp(.ip, '127.0.0.1:0')!
	defer { listener.close() or {} }
	mut app := cors_image_app('anonymous', '')!
	defer { close_cors_image_app(mut app) }
	mut settings := unsafe { &html.EnvironmentSettingsObject(app.document.relevant_settings_object()) }
	settings.set_policy_container(&html.PolicyContainer{ csp_list: [html.parse_response_csp_policy("img-src 'none'", .enforce, app.document.origin())] })
	app.js_runtime.evaluate_host('image.src="http://${listener.addr()!}/image.png"')!
	wait_for_cors_image(app, 'error')!
	listener.set_accept_timeout(20 * time.millisecond)
	if mut unexpected := listener.accept() {
		unexpected.close() or {}
		assert false, 'CSP-blocked image reached the network'
	}
}

fn test_browser_cors_image_deduplication_does_not_reuse_an_earlier_csp_policy() {
	$if !darwin {
		return
	}
	requestserver.install_native_font_fetch_host()!
	defer { requestserver.close_native_font_fetch_host() }
	mut listener := net.listen_tcp(.ip, '127.0.0.1:0')!
	defer { listener.close() or {} }
	mut app := cors_image_app('anonymous', 'http://${listener.addr()!}')!
	defer { close_cors_image_app(mut app) }
	mut loader := app.image_request_loader or { panic('missing image loader') }
	assert loader.cors_requests.len == 1
	mut settings := unsafe { &html.EnvironmentSettingsObject(app.document.relevant_settings_object()) }
	// Appending a meta policy preserves the PolicyContainer's identity.
	mut policy := settings.policy_container()
	policy.csp_list << html.parse_response_csp_policy("img-src 'none'", .enforce, app.document.origin())
	app.js_runtime.evaluate_host('globalThis.denied=new Image();denied.crossOrigin="anonymous";denied.onload=()=>{result="unexpected"};denied.onerror=()=>{result="error"};denied.src=image.src')!
	assert cors_image_result(app)! == 'error'
	assert app.js_runtime.evaluate_host('denied.complete&&denied.naturalWidth===0&&!image.complete')! == 'true'
	assert loader.cors_requests.len == 1 && loader.active_fetches == 1
}

fn test_browser_cors_image_queue_is_bounded_and_cancellation_retires_active_and_queued_requests() {
	$if !darwin {
		return
	}
	requestserver.install_native_font_fetch_host()!
	defer { requestserver.close_native_font_fetch_host() }
	mut listener := net.listen_tcp(.ip, '127.0.0.1:0')!
	defer { listener.close() or {} }
	mut app := cors_image_app('anonymous', '')!
	defer { close_cors_image_app(mut app) }
	app.js_runtime.evaluate_host('globalThis.queuedImages=[];for(let i=0;i<12;i++){const image=new Image();image.crossOrigin="anonymous";image.onload=image.onerror=()=>{result="unexpected"};image.src="http://${listener.addr()!}/image.png?id="+i;queuedImages.push(image)}drawing.getContext("2d").fillRect(0,0,1,1)')!
	mut loader := app.image_request_loader or { panic('missing image loader') }
	assert loader.active_fetches == max_browser_image_fetches
	assert loader.cors_requests.len == 12 && loader.cors_queued.len == 12 - max_browser_image_fetches
	mut pending := []&BrowserCORSImageRequest{}
	for _, request in loader.cors_requests { pending << request }
	loader.cancel()
	assert loader.active_fetches == 0 && loader.cors_requests.len == 0 && loader.cors_queued.len == 0
	for request in pending {
		assert request.finished && request.controller == none && request.completions.len == 0
	}
	app.js_runtime.close()
	platform.pump_native_events(0.05)
}
