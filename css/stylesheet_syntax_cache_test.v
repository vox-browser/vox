module css

import dom

#include "computed_property_store_test.h"

$if gcboehm ? {
	fn C.vox_property_store_watch(index u32, owner voidptr)
	fn C.vox_property_store_collect(depth u32)
	fn C.vox_property_store_worker(work fn ())
	fn C.vox_property_store_alive() u32
	fn C.GC_base(pointer voidptr) voidptr
	__global syntax_retained_cache_ &StylesheetSyntaxCache
	__global syntax_retained_values_ []ComponentValue
}

fn syntax_cache_source(suffix string) string {
	return '/*' + 'padding'.repeat(600) + '*/' + suffix
}

fn test_shared_stylesheet_syntax_keeps_cssom_and_document_contexts_independent() {
	mut first_document := dom.Document.create(dom.URL{value:'https://syntax-one.test/base/'})
	mut second_document := dom.Document.create(dom.URL{value:'https://syntax-two.test/base/'})
	defer { first_document.finalize(); second_document.finalize() }
	text := syntax_cache_source('@import "relative.css"; .probe{color:red!important;--x:calc(1px + var(--base));background:url(../image.png)}') + '/*' + 'extra'.repeat(2600) + '*/'
	mut first_parser := RuleSelectorParser.create_for_stylesheet(ParsingParams{document:first_document}, text)
	first_parser.defer_style_declarations = true
	mut second_parser := RuleSelectorParser.create_for_stylesheet(ParsingParams{document:second_document}, text)
	second_parser.defer_style_declarations = true
	mut first := first_parser.parse_as_css_stylesheet('https://syntax-one.test/a.css', none)
	second := second_parser.parse_as_css_stylesheet('https://syntax-two.test/b.css', none)
	assert first.rules.length() == 2 && second.rules.length() == 2
	assert voidptr(first.rules.rules[1].declaration?.deferred_declarations_?.params.document) == voidptr(first_document)
	assert voidptr(second.rules.rules[1].declaration?.deferred_declarations_?.params.document) == voidptr(second_document)
	assert voidptr(first.rules.rules[1].parent_style_sheet?) == voidptr(first)
	assert voidptr(second.rules.rules[1].parent_style_sheet?) == voidptr(second)
	assert voidptr(first.rules.rules[1]) != voidptr(second.rules.rules[1])
	mut declaration := first.rules.rules[1].style()?
	declaration.set_property('color', 'blue', '')!
	assert second.rules.rules[1].style()?.get_property_value('color') == 'red'
	assert second.rules.rules[1].style()?.get_property_priority('color') == 'important'
	assert declaration.get_property(.background_image)?.value.base_url? == 'https://syntax-one.test/a.css'
	assert second.rules.rules[1].style()?.get_property(.background_image)?.value.base_url? == 'https://syntax-two.test/b.css'
	first.delete_rule(1)!
	assert second.rules.length() == 2
	third := parse_css_stylesheet_with_params(ParsingParams{document:first_document}, text, none)
	assert third.rules.rules[1].style()?.get_property_value('color') == 'red'
	assert third.rules.rules[1].style()?.get_property_priority('color') == 'important'
}

fn test_syntax_cache_keys_exact_bytes_and_bounds_all_three_resources() {
	mut cache := &StylesheetSyntaxCache{max_entries:2, max_source_bytes:10_000, max_nodes:64}
	a := syntax_cache_source('a{color:red}')
	b := syntax_cache_source('a{color:tan}')
	first := cache.parse(a)
	assert cache.parse(a).data == first.data
	assert ParserTokenStream.from_values(cache.parse(b)).dump_string().contains('color:tan')
	assert cache.parse(b).data != first.data
	// Refresh A, so C evicts B. A's original input remains reusable.
	assert cache.parse(a).data == first.data
	cache.parse(syntax_cache_source('c{color:blue}'))
	assert cache.entries.len == 2
	assert cache.parse(a).data == first.data
	cache.parse(syntax_cache_source('x{}'.repeat(100)))
	assert cache.entries.len <= cache.max_entries
	assert cache.source_bytes <= cache.max_source_bytes
	assert cache.nodes <= cache.max_nodes
	// A tree larger than the node budget is parsed without entering the cache.
	assert cache.entries.all(it.input != syntax_cache_source('x{}'.repeat(100)))
	cache.parse('/*' + 'oversize'.repeat(2000) + '*/z{}')
	assert cache.source_bytes <= cache.max_source_bytes
}

fn syntax_cache_parse_worker(mut cache StylesheetSyntaxCache, text string, expected string) bool {
	for _ in 0 .. 8 {
		values := cache.parse(text)
		if ParserTokenStream.from_values(values).dump_string() != expected { return false }
	}
	return true
}

fn test_concurrent_syntax_cache_misses_and_hits_keep_complete_immutable_input() {
	mut cache := &StylesheetSyntaxCache{}
	text := syntax_cache_source('@media (width>1px){a{content:"β😀";--x:f([tail])}}')
	expected := ParserTokenStream.from_source(text, 'utf-8').dump_string()
	mut workers := []thread bool{}
	for _ in 0 .. 8 { workers << spawn syntax_cache_parse_worker(mut cache, text, expected) }
	for worker in workers { assert worker.wait() }
	assert cache.entries.len == 1
	// Published input must survive the exit of the worker that won the miss.
	assert cache.entries[0].input == text
	assert ParserTokenStream.from_values(cache.parse(text)).dump_string() == expected
}

@[noinline]
fn syntax_cache_prepare_eviction() {
	$if gcboehm ? {
		mut cache := &StylesheetSyntaxCache{max_entries:2}
		values := cache.parse(syntax_cache_source('first{color:red}'))
		syntax_retained_values_ = unsafe { values }
		C.vox_property_store_watch(0, C.GC_base(values.data))
		cache.parse(syntax_cache_source('second{color:blue}'))
		cache.parse(syntax_cache_source('third{color:green}'))
		assert cache.entries.len == 2
		syntax_retained_cache_ = cache
	}
}

fn syntax_cache_release_borrower() {
	$if gcboehm ? {
		assert ParserTokenStream.from_values(syntax_retained_values_).dump_string().contains('first{color:red}')
		syntax_retained_values_ = []ComponentValue{}
	}
}

fn test_eviction_releases_storage_after_the_last_parser_borrower_finishes() {
	$if gcboehm ? {
		C.vox_property_store_worker(syntax_cache_prepare_eviction)
		C.vox_property_store_collect(8)
		assert C.vox_property_store_alive() == 1
		C.vox_property_store_worker(syntax_cache_release_borrower)
		C.vox_property_store_collect(8)
		C.vox_property_store_collect(8)
		assert C.vox_property_store_alive() == 0
		assert syntax_retained_cache_.entries.len == 2
	} $else {
		mut cache := &StylesheetSyntaxCache{max_entries:1}
		values := cache.parse(syntax_cache_source('first{}'))
		cache.parse(syntax_cache_source('second{}'))
		assert ParserTokenStream.from_values(values).dump_string().contains('first{}')
	}
}
