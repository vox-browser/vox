module browserjs

import dom
import net
import os
import time

// Each accepted socket serves its requests with keep-alive. A host that opened
// a connection the fixture does not expect is never served.
fn serve_curl_connection_pool(mut listener net.TcpListener, per_connection []int) [][]string {
	mut connections := [][]string{}
	for count in per_connection {
		mut socket := listener.accept() or { panic(err) }
		socket.set_read_timeout(5 * time.second)
		mut requests := []string{}
		for _ in 0 .. count {
			mut header := ''
			for !header.contains('\r\n\r\n') {
				mut bytes := []u8{len: 4096}
				length := socket.read(mut bytes) or { panic(err) }
				assert length > 0
				header += bytes[..length].bytestr()
			}
			requests << header.all_before('\r\n')
			socket.write_string('HTTP/1.1 200 OK\r\nContent-Type: text/plain\r\nContent-Length: 2\r\nConnection: keep-alive\r\nCache-Control: no-store\r\n\r\nok') or { panic(err) }
		}
		connections << requests
		socket.close() or {}
	}
	return connections
}

fn curl_connection_pool_without_proxies() map[string]string {
	// Ambient proxies can route loopback elsewhere or replace keep-alive with
	// separate upstream connections. This fixture measures the direct socket.
	mut previous := map[string]string{}
	for name in ['ALL_PROXY', 'HTTP_PROXY', 'HTTPS_PROXY', 'all_proxy', 'http_proxy', 'https_proxy', 'VOX_PROXY'] {
		if value := os.getenv_opt(name) { previous[name] = value }
		os.unsetenv(name)
	}
	return previous
}

fn curl_connection_pool_restore(previous map[string]string) {
	for name in ['ALL_PROXY', 'HTTP_PROXY', 'HTTPS_PROXY', 'all_proxy', 'http_proxy', 'https_proxy', 'VOX_PROXY'] {
		if value := previous[name] { os.setenv(name, value, true) } else { os.unsetenv(name) }
	}
}

fn curl_connection_pool_runtime(document &dom.Document) (&Runtime, &FetchHost) {
	mut runtime := Runtime.create_with_engine(.javascriptcore)
	mut readable := ReadableStreamHost.create(document) or { panic(err) }
	readable.install(mut runtime) or { panic(err) }
	mut blobs := BlobHost.create(document) or { panic(err) }
	blobs.install(mut runtime) or { panic(err) }
	blobs.install_constructor() or { panic(err) }
	mut params := URLSearchParamsHost.create(document) or { panic(err) }
	params.install(mut runtime) or { panic(err) }
	mut abort := AbortSignalHost.create(document) or { panic(err) }
	abort.install(mut runtime) or { panic(err) }
	mut fetcher := FetchHost.create_native(document) or { panic(err) }
	fetcher.install(mut runtime) or { panic(err) }
	return runtime, fetcher
}

fn curl_connection_pool_await(runtime &Runtime, fetcher &FetchHost, script string) string {
	mut mutable_runtime := unsafe { &Runtime(runtime) }
	mutable_runtime.evaluate_host('globalThis.poolResult="";${script}.then(t=>poolResult="ok:"+t,e=>poolResult="error:"+e)') or { panic(err) }
	deadline := time.sys_mono_now() + 5 * time.second
	mut loop := fetcher.settings.responsible_event_loop()
	loop.spin_until(fn [runtime, deadline] () bool {
		return (runtime.evaluate_host('poolResult!==""') or { 'false' }) == 'true'
			|| time.sys_mono_now() >= deadline
	})
	return mutable_runtime.evaluate_host('poolResult') or { panic(err) }
}

const curl_connection_pool_xhr = 'new Promise((resolve,reject)=>{const r=new XMLHttpRequest();r.onload=()=>resolve(r.responseText);r.onerror=()=>reject("xhr");r.open("GET","./xhr");r.send();})'

fn test_xhr_fetch_and_same_partition_documents_share_one_connection() {
	$if !darwin { return }
	previous := curl_connection_pool_without_proxies()
	defer { curl_connection_pool_restore(previous) }
	mut listener := net.listen_tcp(.ip, '127.0.0.1:0')!
	defer { listener.close() or {} }
	server := spawn serve_curl_connection_pool(mut listener, [4])
	address := 'http://${listener.addr()!}'
	mut document := dom.Document.create(dom.URL{ value: '${address}/owner' })
	document.set_origin(document.url.origin())
	mut runtime, fetcher := curl_connection_pool_runtime(document)
	mut xhr := XMLHttpRequestHost.create_native(document)!
	xhr.install(mut runtime)!
	runtime.evaluate_host(xhr_bootstrap())!
	// A second document of the same top-level origin, like a same-site iframe,
	// has its own Fetch host.
	mut sibling := dom.Document.create(dom.URL{ value: '${address}/sibling' })
	sibling.set_origin(sibling.url.origin())
	mut sibling_runtime, sibling_fetcher := curl_connection_pool_runtime(sibling)
	defer {
		sibling_runtime.close()
		runtime.close()
		sibling.finalize()
		document.finalize()
	}
	assert curl_connection_pool_await(runtime, fetcher, 'fetch("./warm").then(r=>r.text())') == 'ok:ok'
	assert curl_connection_pool_await(runtime, fetcher, curl_connection_pool_xhr) == 'ok:ok'
	assert curl_connection_pool_await(sibling_runtime, sibling_fetcher, 'fetch("./sibling").then(r=>r.text())') == 'ok:ok'
	// Closing one host stops only its own transfers; the shared connection stays.
	xhr.close()
	assert curl_connection_pool_await(runtime, fetcher, 'fetch("./after-close").then(r=>r.text())') == 'ok:ok'
	assert server.wait() == [['GET /warm HTTP/1.1', 'GET /xhr HTTP/1.1', 'GET /sibling HTTP/1.1',
		'GET /after-close HTTP/1.1']]
}

fn test_uncredentialed_requests_use_a_separate_connection() {
	$if !darwin { return }
	previous := curl_connection_pool_without_proxies()
	defer { curl_connection_pool_restore(previous) }
	mut listener := net.listen_tcp(.ip, '127.0.0.1:0')!
	defer { listener.close() or {} }
	server := spawn serve_curl_connection_pool(mut listener, [2, 1])
	mut document := dom.Document.create(dom.URL{ value: 'http://${listener.addr()!}/owner' })
	document.set_origin(document.url.origin())
	mut runtime, fetcher := curl_connection_pool_runtime(document)
	defer {
		runtime.close()
		document.finalize()
	}
	assert curl_connection_pool_await(runtime, fetcher, 'fetch("./first").then(r=>r.text())') == 'ok:ok'
	assert curl_connection_pool_await(runtime, fetcher, 'fetch("./second").then(r=>r.text())') == 'ok:ok'
	assert curl_connection_pool_await(runtime, fetcher, 'fetch("./omit",{credentials:"omit"}).then(r=>r.text())') == 'ok:ok'
	assert server.wait() == [['GET /first HTTP/1.1', 'GET /second HTTP/1.1'], ['GET /omit HTTP/1.1']]
}
