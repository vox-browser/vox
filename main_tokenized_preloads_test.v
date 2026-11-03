module main

import html

fn test_tokenized_navigation_preloads_match_full_discovery_with_raw_text_and_url_entities() {
	for markup in [
		'<html><head><title>&lt;img src="fake.png"></title><link rel="stylesheet" href="/x.css?a&amp;b"><script src="/x.js"></script></head><body><table><tr><td><img src="/p.png"><script src="/late.js">let s="<img src=\'hidden.png\'>";</script></td></tr></table></body></html>',
		'<html><head><style>i:before{content:"<script src=bad.js>"}</style><link rel="preload" as="style" type="text/css; charset=utf-8" href="/x.css"><link rel="stylesheet" href="/x.css"></head><body><textarea><img src="fake.png"></textarea><img src="/x.css"><script src="/x.css"></script><script src="/right.js" type="APPLICATION/JAVASCRIPT"></script><script src="/data.json" type="application/json"></script></body></html>',
	] {
		loaded := LoadedPage{url:'https://preload.test/root/page', markup:markup, content_type:'text/html;charset=utf-8'}
		found := tokenized_navigation_preloads(loaded) or { panic('eligible preload input rejected') }
		document := parse_page_preload_document(loaded, true)
		base := document.base_url().serialize()
		assert found.urls == document_preload_resource_urls(document, base)
		full_types := document_preload_resource_types(document, base)
		for address in found.urls { assert (found.types[address] or { 'image' }) == (full_types[address] or { 'image' }) }
		retire_native_preload_document(document)
	}
}

fn test_tokenized_navigation_preloads_keep_sensitive_contexts_on_the_full_parser() {
	for content in [
		'<base href="/other/">', '<template><img src="hidden.png"></template>',
		'<noscript><link rel="stylesheet" href="hidden.css"></noscript>',
		'<svg><image href="graphic.svg"/></svg>', '<math></math>',
		'<select><img src="ignored.png"></select>', '<meta http-equiv="default-style" content="Other">',
		'<link rel="stylesheet" title="Set" href="set.css">',
		'<link rel="alternate stylesheet" href="unused.css">', '<link rel="stylesheet" disabled href="unused.css">',
		'<style title="Set">b{color:red}</style>',
	] {
		assert collect_tokenized_navigation_preloads('<html><head></head><body>${content}</body></html>', 'https://preload.test/') == none
	}
	assert collect_tokenized_navigation_preloads('<link rel="stylesheet" href="fragment.css">', 'https://preload.test/') == none
}

fn test_tokenized_navigation_preloads_preserve_group_priority_and_resource_limit() {
	mut content := '<html><head></head><body><img src="shared"><script src="shared"></script><link rel="stylesheet" href="shared">'
	for index in 0 .. max_preloaded_resources + 8 { content += '<script src="${index}.js"></script>' }
	content += '</body></html>'
	found := collect_tokenized_navigation_preloads(content, 'https://preload.test/') or { panic('eligible') }
	assert found.urls.len == max_preloaded_resources
	assert found.urls[0] == 'https://preload.test/shared'
	assert found.types[found.urls[0]] == 'stylesheet'
	assert found.types[found.urls[1]] == 'script'
}
