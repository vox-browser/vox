module main

import browserjs
import dom
import html

fn test_compact_loader_preserves_deferred_script_order_after_inline_bootstrap() {
	mut document := html.parse_document_with_url('<script defer src="react.js"></script><script defer src="app.js"></script><script>globalThis.bootstrap = 42;</script><script defer>globalThis.inlineDefer = true;</script><script type="module">export default bootstrap;</script><script src="blocking.js"></script><script type="application/json">{}</script>', dom.URL{ value: 'https://example.test/maps/' })
	defer { document.finalize() }
	mut messages := []string{}
	sources := script_sources(document, document.url.serialize(), {
		'https://example.test/maps/react.js':    PreloadedResource{ body: 'globalThis.React = {};' }
		'https://example.test/maps/app.js':      PreloadedResource{ body: 'globalThis.started = bootstrap;' }
		'https://example.test/maps/blocking.js': PreloadedResource{ body: 'globalThis.blocking = true;' }
	}, mut messages)
	assert messages == []
	assert sources.map(it.code) == [
		'globalThis.bootstrap = 42;',
		'globalThis.inlineDefer = true;',
		'globalThis.blocking = true;',
		'globalThis.React = {};',
		'globalThis.started = bootstrap;',
		'export default bootstrap;',
	]
	assert sources[5].source_type == .module
}

fn test_async_scripts_do_not_join_the_deferred_queue() {
	mut document := html.parse_document_with_url('<script defer src="deferred.js"></script><script async defer src="async.js"></script><script type="module" async>export default 1;</script><script>globalThis.bootstrap = true;</script>', dom.URL{ value: 'https://example.test/' })
	defer { document.finalize() }
	mut messages := []string{}
	sources := script_sources(document, document.url.serialize(), {
		'https://example.test/deferred.js': PreloadedResource{ body: 'deferred();' }
		'https://example.test/async.js':    PreloadedResource{ body: 'asynchronous();' }
	}, mut messages)
	assert messages == []
	assert sources.map(it.code) == ['asynchronous();', 'export default 1;',
		'globalThis.bootstrap = true;', 'deferred();']
}

fn test_deferred_application_observes_bootstrap_before_document_ready() {
	$if !darwin {
		return
	}
	mut document := html.parse_document_with_url('<div id="result">pending</div><script defer src="app.js"></script><script>globalThis.bootstrap = "ready"; document.addEventListener("DOMContentLoaded", () => result.textContent += ":dom-ready");</script>', dom.URL{ value: 'https://example.test/maps/' })
	defer { document.finalize() }
	mut messages := []string{}
	sources := script_sources(document, document.url.serialize(), {
		'https://example.test/maps/app.js': PreloadedResource{
			body: 'result.textContent = bootstrap;'
		}
	}, mut messages)
	mut runtime := browserjs.Runtime.create()
	defer { runtime.close() }
	run_document_script_sources(document, document.url.serialize(), sources, runtime, mut messages)
	assert messages == []
	assert document.get_element_by_id('result')?.as_node().text_content()? == 'ready:dom-ready'
}
