// SPDX-License-Identifier: BSD-2-Clause
module browserjs

import dom
import fetch
import html
import http
import libjs
import os
import rand
import time

fn test_first_dynamic_import_compiles_uncalled_nested_bodies_for_the_next_visit() {
	directory := os.join_path(os.temp_dir(), 'vox-dynamic-native-templates-' + rand.uuid_v4())
	previous := os.getenv_opt('VOX_LIBJS_NATIVE_CACHE')
	compiler := os.getenv_opt('VOX_LIBJS_NATIVE_COMPILER')
	defer {
		if value := previous {
			os.setenv('VOX_LIBJS_NATIVE_CACHE', value, true)
		} else {
			os.unsetenv('VOX_LIBJS_NATIVE_CACHE')
		}
		if value := compiler {
			os.setenv('VOX_LIBJS_NATIVE_COMPILER', value, true)
		} else {
			os.unsetenv('VOX_LIBJS_NATIVE_COMPILER')
		}
		os.rmdir_all(directory) or {}
	}
	for visit in 0 .. 2 {
		os.setenv('VOX_LIBJS_NATIVE_CACHE', directory, true)
		os.setenv('VOX_LIBJS_NATIVE_COMPILER', if visit == 0 {
			'/usr/bin/clang'
		} else {
			'/usr/bin/false'
		}, true)
		address := dom.URL{ value: 'https://native-module.test/' }
		document := html.parse_navigation_document('<body></body>', address, address.origin(), none)!
		settings := unsafe { &html.EnvironmentSettingsObject(document.relevant_settings_object()) }
		mut runtime := Runtime.create_with_engine(.libjs)
		runtime.bind_scripting_environment(settings)!
		runtime.install_libjs_document(document)!
		transport := &fetch.FetchHost{
			perform: fn (request &fetch.Request) !&fetch.Response {
				assert request.current_url().serialize() == 'https://native-module.test/lazy.mjs'
				mut response := fetch.Response.create()
				response.status = 200
				response.url_list = request.url_list.clone()
				response.header_list.append(http.Header{ name: 'Content-Type', value: 'text/javascript' })
				response.set_body_bytes('globalThis.effects=0;export function factory(){effects++;return ()=>42}'.bytes())
				return response
			}
		}
		mut host := ModuleHost.create(settings, transport)
		host.install(mut runtime)!
		mut global := runtime.realm.global_object_record()
		global.define_direct_property(libjs.PropertyName.from_str('exercise'), libjs.Value.from_bool(visit > 0), libjs.attribute_writable)
		assert runtime.run_document_scripts_collect_errors([ScriptSource{ url: 'https://native-module.test/page.js', code: 'import("./lazy.mjs").then(m=>{globalThis.lazyReady=true;if(exercise)globalThis.answer=m.factory()()})' }]).len == 0
		deadline := time.sys_mono_now() + 10 * time.second
		mut loop := settings.responsible_event_loop()
		loop.spin_until(fn [runtime, deadline] () bool {
			ready := runtime.realm.global_object_record().get_without_side_effects(libjs.PropertyName.from_str('lazyReady')).to_boolean()
			return time.sys_mono_now() >= deadline || (ready && !runtime.libjs_native_cache_pending_)
		})
		assert time.sys_mono_now() < deadline && host.errors().len == 0
		assert global.get_without_side_effects(libjs.PropertyName.from_str('effects')).number == if visit == 0 {
			0
		} else {
			1
		}
		if visit == 0 {
			assert runtime.libjs_native_template_audit_.completed_modules == 1 && runtime.libjs_native_template_audit_.prepared_functions == 2
			assert runtime.libjs_native_template_audit_.unsupported_functions == 0
		} else {
			assert global.get_without_side_effects(libjs.PropertyName.from_str('answer')).number == 42
			stats := runtime.native_code_cache_stats()
			assert stats.cache_hits > 0 && stats.cache_misses == 0 && stats.compiler_invocations == 0 && stats.last_error == ''
		}
		runtime.close()
	}
}
