module browserjs

import dom
import html
import net
import os
import time

fn serve_module_fetch_pool(mut listener net.TcpListener) []string {
	mut socket := listener.accept() or { panic(err) }
	defer { socket.close() or {} }
	socket.set_read_timeout(5 * time.second)
	mut requests := []string{}
	for index in 0 .. 4 {
		mut header := ''
		for !header.contains('\r\n\r\n') {
			mut bytes := []u8{len:4096}
			length := socket.read(mut bytes) or { panic(err) }
			assert length > 0
			header += bytes[..length].bytestr()
		}
		requests << header.all_before('\r\n')
		body := if index == 1 { 'export const value=40;' } else { '2' }
		socket.write_string('HTTP/1.1 200 OK\r\nContent-Type: text/javascript\r\nContent-Length: ${body.len}\r\nConnection: keep-alive\r\nCache-Control: no-store\r\n\r\n${body}') or { panic(err) }
	}
	return requests
}

fn test_module_and_fetch_reuse_connection_and_closing_module_leaves_fetch_live() {
	$if !darwin { return }
	// Ambient proxies can route loopback elsewhere or replace keep-alive with
	// separate upstream connections. This fixture measures the direct socket.
	proxy_names := ['ALL_PROXY','HTTP_PROXY','HTTPS_PROXY','all_proxy','http_proxy','https_proxy','VOX_PROXY']
	mut previous := map[string]string{}
	for name in proxy_names {
		if value := os.getenv_opt(name) { previous[name] = value }
		os.unsetenv(name)
	}
	defer {
		for name in proxy_names {
			if value := previous[name] { os.setenv(name,value,true) }
			else { os.unsetenv(name) }
		}
	}
	mut listener := net.listen_tcp(.ip, '127.0.0.1:0')!
	defer { listener.close() or {} }
	server := spawn serve_module_fetch_pool(mut listener)
	mut document := dom.Document.create(dom.URL{value:'http://${listener.addr()!}/owner'})
	document.set_origin(document.url.origin())
	mut fetcher := FetchHost.create_native(document)!
	mut runtime := Runtime.create()
	defer { runtime.close(); document.finalize() }
	assert runtime.installed_fetch_transport() == none
	mut readable := ReadableStreamHost.create(document)!
	readable.install(mut runtime)!
	mut blobs := BlobHost.create(document)!
	blobs.install(mut runtime)!
	blobs.install_constructor()!
	mut params := URLSearchParamsHost.create(document)!
	params.install(mut runtime)!
	mut abort := AbortSignalHost.create(document)!
	abort.install(mut runtime)!
	fetcher.install(mut runtime)!
	transport := runtime.installed_fetch_transport()?
	settings := unsafe { &html.EnvironmentSettingsObject(document.relevant_settings_object()) }
	mut modules := ModuleHost.create(settings, transport)
	modules.install(mut runtime)!
	assert modules.connection == none
	mut loop := settings.responsible_event_loop()
	deadline := time.sys_mono_now() + 5 * time.second
	runtime.evaluate_host('globalThis.poolWarmed=false;globalThis.poolFailure="";fetch("./warm").then(r=>r.text()).then(()=>poolWarmed=true,e=>{poolFailure=String(e);poolWarmed=true})')!
	loop.spin_until(fn [runtime,deadline] () bool {
		return (runtime.evaluate_host('poolWarmed') or { 'false' }) == 'true'
			|| time.sys_mono_now() >= deadline
	})
	assert runtime.evaluate_host('poolFailure')! == ''
	assert runtime.evaluate_host('poolWarmed')! == 'true'
	assert runtime.run_document_scripts_collect_errors([ScriptSource{
		source_type:.module
		url:'http://${listener.addr()!}/root.js'
		code:'import {value} from "./dep.js";globalThis.poolDone=false;fetch("./value").then(r=>r.text()).then(text=>{globalThis.poolAnswer=value+Number(text);poolDone=true});'
	}]) == []string{}
	loop.spin_until(fn [runtime,deadline] () bool {
		return (runtime.evaluate_host('globalThis.poolDone===true') or { 'false' }) == 'true'
			|| time.sys_mono_now() >= deadline
	})
	assert modules.errors() == []string{}
	assert runtime.evaluate_host('globalThis.poolDone&&poolAnswer===42')! == 'true'
	modules.close()
	runtime.evaluate_host('globalThis.poolAfterClose=false;fetch("./still-live").then(r=>r.text()).then(t=>globalThis.poolAfterClose=t==="2")')!
	loop.spin_until(fn [runtime,deadline] () bool {
		return (runtime.evaluate_host('poolAfterClose') or { 'false' }) == 'true'
			|| time.sys_mono_now() >= deadline
	})
	assert runtime.evaluate_host('poolAfterClose')! == 'true'
	assert server.wait() == ['GET /warm HTTP/1.1','GET /dep.js HTTP/1.1','GET /value HTTP/1.1','GET /still-live HTTP/1.1']
	runtime.close()
	assert runtime.installed_fetch_transport() == none
}
