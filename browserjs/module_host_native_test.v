module browserjs

import browsersettings
import dom
import html
import net
import os
import time

fn serve_parallel_module_requests(mut listener net.TcpListener) []string {
	mut paths := []string{}
	for _ in 0 .. 2 {
		mut socket := listener.accept() or { return paths }
		socket.set_read_timeout(3 * time.second)
		mut input := []u8{len: 4096}
		length := socket.read(mut input) or {
			socket.close() or {}
			return paths
		}
		path := input[..length].bytestr().split(' ')[1]
		paths << path
		body := if path == '/a.js' { 'export const value=41;' } else { 'export const value=1;' }
		socket.write_string('HTTP/1.1 200 OK\r\nContent-Type: text/javascript\r\nContent-Length: ${body.len}\r\nConnection: close\r\n\r\n${body}') or {
			socket.close() or {}
			return paths
		}
		socket.close() or {}
	}
	return paths
}

fn test_native_module_transport_completes_concurrent_classic_and_module_imports() {
	$if !darwin {
		return
	}
	directory := os.join_path(os.temp_dir(), 'vox-module-network-${os.getpid()}-${time.sys_mono_now()}')
	browsersettings.initialize(os.join_path(directory, 'settings.json'))!
	browsersettings.save(browsersettings.Proxy{ enabled: false })!
	defer {
		browsersettings.initialize(os.join_path(directory, 'absent.json')) or { panic(err) }
		os.rmdir_all(directory) or {}
	}
	mut listener := net.listen_tcp(.ip, '127.0.0.1:0')!
	defer { listener.close() or {} }
	listener.set_accept_timeout(3 * time.second)
	server := spawn serve_parallel_module_requests(mut listener)
	address := dom.URL{ value: 'http://${listener.addr()!}/owner' }
	mut document := html.create_navigation_document(address, address.origin(), none)!
	mut runtime := Runtime.create()
	defer {
		runtime.close()
		document.finalize()
	}
	settings := unsafe { &html.EnvironmentSettingsObject(document.relevant_settings_object()) }
	runtime.bind_scripting_environment(settings)!
	mut host := ModuleHost.create_native(settings)!
	host.install(mut runtime)!
	assert runtime.run_document_scripts_collect_errors([
		ScriptSource{ url: address.serialize(), code: 'import("./a.js").then(ns=>globalThis.firstValue=ns.value);' },
		ScriptSource{ url: address.serialize(), source_type: .module, code: 'globalThis.secondValue=(await import("./b.js")).value;' },
	]) == []
	deadline := time.sys_mono_now() + 5 * time.second
	mut loop := settings.responsible_event_loop()
	loop.spin_until(fn [runtime, deadline] () bool {
		return (runtime.evaluate_host('globalThis.firstValue===41&&globalThis.secondValue===1') or { 'false' }) == 'true' || time.sys_mono_now() >= deadline
	})
	assert runtime.evaluate_host('globalThis.firstValue===41&&globalThis.secondValue===1')! == 'true'
	assert host.errors() == []string{}
	assert server.wait().len == 2
}
