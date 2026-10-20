module css

import dom

#include "computed_property_store_test.h"

$if gcboehm ? {
	fn C.vox_property_store_watch(index u32, owner voidptr)
	fn C.vox_property_store_collect(depth u32)
	fn C.vox_property_store_worker(work fn ())
	fn C.vox_property_store_alive() u32
	fn C.GC_base(pointer voidptr) voidptr
	__global idle_syntax_cache_ &StylesheetSyntaxCache
}

fn test_idle_syntax_release_preserves_borrowed_input_and_later_cache_hits() {
	mut cache := StylesheetSyntaxCache{}
	text := '/*' + 'padding'.repeat(600) + '*/a{color:red;--value:calc(1px + 2%)}'
	borrowed := cache.parse(text)
	expected := ParserTokenStream.from_values(borrowed).dump_string()
	assert cache.entries.len == 1
	cache.release_unused()
	assert cache.entries.len == 0
	assert cache.source_bytes == 0
	assert cache.nodes == 0
	gc_collect()
	assert ParserTokenStream.from_values(borrowed).dump_string() == expected
	refilled := cache.parse(text)
	assert ParserTokenStream.from_values(refilled).dump_string() == expected
	assert cache.parse(text).data == refilled.data
	cache.release_unused()
	cache.release_unused()
	assert cache.entries.len == 0
}

fn test_idle_syntax_release_keeps_deferred_cssom_and_document_url_resolution() {
	mut document := dom.Document.create(dom.URL{value:'https://idle-syntax.test/base/'})
	defer { document.finalize() }
	text := '/*' + 'padding'.repeat(600) + '*/a{color:red!important;--value:calc(1px + var(--base));background:url(image.png)}'
	mut parser := RuleSelectorParser.create_for_stylesheet(ParsingParams{document:document}, text)
	parser.defer_style_declarations = true
	sheet := parser.parse_as_css_stylesheet('https://idle-syntax.test/assets/style.css', none)
	assert sheet.rules.rules[0].declaration?.deferred_declarations_ != none
	release_unused_stylesheet_syntax()
	gc_collect()
	mut declaration := sheet.rules.rules[0].style()?
	assert declaration.get_property_value('color') == 'red'
	assert declaration.get_property_priority('color') == 'important'
	assert declaration.get_property_value('--value').contains('var(--base)')
	assert declaration.get_property(.background_image)?.value.base_url? == 'https://idle-syntax.test/assets/style.css'
	declaration.set_property('color', 'blue', '')!
	reparsed := parse_css_stylesheet_with_params(ParsingParams{document:document}, text, none)
	assert declaration.get_property_value('color') == 'blue'
	assert reparsed.rules.rules[0].style()?.get_property_value('color') == 'red'
}

fn idle_syntax_prepare_retained_cache() {
	$if gcboehm ? {
		mut cache := &StylesheetSyntaxCache{}
		values := cache.parse('/*' + 'padding'.repeat(600) + '*/a{color:red}')
		C.vox_property_store_watch(0, C.GC_base(values.data))
		idle_syntax_cache_ = cache
	}
}

fn idle_syntax_release_retained_cache() {
	$if gcboehm ? {
		idle_syntax_cache_.release_unused()
	}
}

fn test_idle_syntax_release_drops_the_cache_root_to_finished_token_trees() {
	$if gcboehm ? {
		C.vox_property_store_worker(idle_syntax_prepare_retained_cache)
		C.vox_property_store_collect(8)
		assert C.vox_property_store_alive() & 1 == 1
		C.vox_property_store_worker(idle_syntax_release_retained_cache)
		C.vox_property_store_collect(8)
		C.vox_property_store_collect(8)
		assert C.vox_property_store_alive() & 1 == 0
		assert idle_syntax_cache_.entries.len == 0
	}
}
