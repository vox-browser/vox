module browserjs

import browsersettings
import dom
import html
import os
import time
import x.json2

fn test_native_module_transport_completes_https_socks_responses() {
	$if !darwin {
		return
	}
	repo := os.real_path(os.join_path(os.dir(@FILE), '..'))
	directory := os.join_path(repo, 'Build/module-https-${os.getpid()}-${time.sys_mono_now()}')
	os.mkdir_all(directory)!
	os.chmod(directory, 0o700)!
	println('HTTPS proxy fixture: ${directory}')
	mut server := os.new_process('python3')
	server.set_args([os.join_path(repo, 'tools/module_https_proxy_fixture.py'), directory])
	server.set_redirect_stdio()
	server.run()
	defer {
		server.signal_kill()
		server.wait()
		server.close()
	}
	mut ready := map[string]json2.Any{}
	startup_deadline := time.sys_mono_now() + 10 * time.second
	for time.sys_mono_now() < startup_deadline && server.is_alive() {
		if input := os.read_file(os.join_path(directory, 'replay/ready.json')) {
			if parsed := json2.decode[map[string]json2.Any](input) {
				ready = parsed.clone()
				break
			}
		}
		time.sleep(10 * time.millisecond)
	}
	assert ready.len > 0, server.stderr_read()
	ca := (ready['ca'] or { panic('missing CA') }).str()
	previous_ca := os.getenv_opt('SSL_CERT_FILE')
	os.setenv('SSL_CERT_FILE', ca, true)
	defer {
		if value := previous_ca {
			os.setenv('SSL_CERT_FILE', value, true)
		} else {
			os.unsetenv('SSL_CERT_FILE')
		}
		browsersettings.initialize(os.join_path(directory, 'absent.json')) or { panic(err) }
	}
	proxy := (ready['proxy'] or { panic('missing proxy') }).str()
	browsersettings.initialize(os.join_path(directory, 'settings.json'))!
	browsersettings.save(browsersettings.Proxy{ enabled: true, host: '127.0.0.1', port: proxy.all_after_last(':') })!
	address := dom.URL{ value: 'https://module-proxy.test/owner' }
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
	deadline := time.sys_mono_now() + 10 * time.second
	mut loop := settings.responsible_event_loop()
	loop.spin_until(fn [runtime, deadline] () bool {
		return (runtime.evaluate_host('globalThis.firstValue===41&&globalThis.secondValue===1') or { 'false' }) == 'true' || time.sys_mono_now() >= deadline
	})
	assert host.errors() == []string{}
	assert runtime.evaluate_host('globalThis.firstValue===41&&globalThis.secondValue===1')! == 'true'
}
