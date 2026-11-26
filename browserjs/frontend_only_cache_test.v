module browserjs

import html
import libjs
import os
import rand

fn test_frontend_only_control_reuses_syntax_without_enabling_native_execution() {
	native_choice := os.getenv_opt('VOX_LIBJS_NATIVE_CACHE')
	frontend_choice := os.getenv_opt('VOX_LIBJS_FRONTEND_CACHE')
	defer {
		if value := native_choice {
			os.setenv('VOX_LIBJS_NATIVE_CACHE', value, true)
		} else {
			os.unsetenv('VOX_LIBJS_NATIVE_CACHE')
		}
		if value := frontend_choice {
			os.setenv('VOX_LIBJS_FRONTEND_CACHE', value, true)
		} else {
			os.unsetenv('VOX_LIBJS_FRONTEND_CACHE')
		}
	}
	os.setenv('VOX_LIBJS_NATIVE_CACHE', '0', true)
	os.setenv('VOX_LIBJS_FRONTEND_CACHE', '1', true)
	mut runtime := Runtime.create_with_engine(.libjs)
	defer { runtime.close() }
	runtime.install_libjs_document(html.parse_document('<body></body>'))!
	code := 'var unique_' + rand.uuid_v4().replace('-', '') + '=42'
	first := runtime.prepare_libjs_frontend(code, .script, libjs.ParseOptions{ max_recursion_depth: 256 })
	second := runtime.prepare_libjs_frontend(code, .script, libjs.ParseOptions{ max_recursion_depth: 256 })
	assert !first.has_errors() && voidptr(first) == voidptr(second)
	assert runtime.frontend_code_cache_stats().misses == 1 && runtime.frontend_code_cache_stats().hits == 1
	assert !runtime.libjs_native_cache_enabled_
	assert runtime.native_code_cache_stats().abi == '' && runtime.native_code_cache_stats().compiler_invocations == 0

	options := libjs.ParseOptions{ max_recursion_depth: 256 }
	collision := 'var collision_' + rand.uuid_v4().replace('-', '') + '=13'
	key := libjs_frontend_key(runtime.libjs_native_cache_partition_, collision, .script, options)
	mut cache := libjs_frontend_cache
	cache.lock.lock()
	cache.entries[key] = LibJSFrontendEntry{ parsed: first }
	defer {
		cache.lock.lock()
		cache.entries.delete(key)
		cache.lock.unlock()
	}
	cache.lock.unlock()
	third := runtime.prepare_libjs_frontend(collision, .script, options)
	assert !third.has_errors() && third.source_text == collision && voidptr(third) != voidptr(first)
	assert runtime.frontend_code_cache_stats().misses == 2 && runtime.frontend_code_cache_stats().hits == 1

	os.setenv('VOX_LIBJS_FRONTEND_CACHE', '0', true)
	fourth := runtime.prepare_libjs_frontend(code, .script, options)
	assert voidptr(fourth) != voidptr(first) && runtime.frontend_code_cache_stats().misses == 3
	uncached := runtime.prepare_libjs_script(ScriptSource{code: code, url: 'https://example.test/script.js'})!
	assert uncached.source.code == code && uncached.source.url == 'https://example.test/script.js'
	assert voidptr(uncached.source.code.str) == voidptr(uncached.frontend.source_text.str)
	assert voidptr(uncached.source.code.str) != voidptr(code.str)

	os.setenv('VOX_LIBJS_FRONTEND_CACHE', '1', true)
	cached := runtime.prepare_libjs_script(ScriptSource{code: code})!
	assert voidptr(cached.frontend) == voidptr(first)
	assert voidptr(cached.source.code.str) == voidptr(first.source_text.str)

	// Three sources of this size exceed the aggregate budget. Two fit.
	padding := ' '.repeat(2 * 1024 * 1024)
	large_first := '${code}; 1;\n//${padding}'
	large_second := '${code}; 2;\n//${padding}'
	large_third := '${code}; 3;\n//${padding}'
	first_large := runtime.prepare_libjs_frontend(large_first, .script, options)
	second_large := runtime.prepare_libjs_frontend(large_second, .script, options)
	assert !first_large.has_errors() && !second_large.has_errors()
	revisited_first := runtime.prepare_libjs_frontend(large_first, .script, options)
	assert voidptr(revisited_first) == voidptr(first_large)
	assert !runtime.prepare_libjs_frontend(large_third, .script, options).has_errors()
	assert voidptr(runtime.prepare_libjs_frontend(large_first, .script, options)) == voidptr(first_large)
	assert voidptr(runtime.prepare_libjs_frontend(large_second, .script, options)) != voidptr(second_large)
}
