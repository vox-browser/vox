module css

import dom

fn test_repeated_workspace_input_keeps_independent_cssom_and_contexts() {
	mut first_document := dom.Document.create(dom.URL{value: 'https://repeat-one.test/base/'})
	mut second_document := dom.Document.create(dom.URL{value: 'https://repeat-two.test/base/'})
	defer { first_document.finalize(); second_document.finalize() }
	text := '/*' + 'padding'.repeat(3000) + '*/@media(width>1px){.card{color:red;background:url(../image.png);--x:calc(1px + var(--y))}}'
	for deferred in [false, true] {
		mut first := parse_css_stylesheet_in_workspace(ParsingParams{document:first_document}, text, 'https://repeat-one.test/a.css', none, deferred)
		second := parse_css_stylesheet_in_workspace(ParsingParams{document:second_document}, text, 'https://repeat-two.test/b.css', none, deferred)
		third := parse_css_stylesheet_in_workspace(ParsingParams{document:second_document}, text, 'https://repeat-two.test/c.css', none, deferred)
		assert first.rules.rules[0].css_text() == second.rules.rules[0].css_text()
		assert second.rules.rules[0].css_text() == third.rules.rules[0].css_text()
		assert voidptr(first.rules.rules[0]) != voidptr(second.rules.rules[0])
		first.delete_rule(0)!
		release_unused_stylesheet_syntax()
		gc_collect()
		assert second.rules.rules[0].css_text() == third.rules.rules[0].css_text()
		assert second.rules.length() == 1
	}
}

fn test_repeat_admission_is_bounded_and_only_the_full_source_can_supply_tokens() {
	mut cache := &StylesheetSyntaxCache{max_entries:2, max_source_bytes:10000}
	text := '/*' + 'p'.repeat(4200) + '*/a{color:red}'
	assert !cache.admit_conversion_input(text)
	assert cache.admit_conversion_input(text)
	other := '/*' + 'p'.repeat(4200) + '*/a{color:tan}'
	assert !cache.admit_conversion_input(other)
	cache.admit_conversion_input('/*' + 'q'.repeat(4200) + '*/b{}')
	assert cache.conversion_seen_.len <= 2
	assert cache.conversion_seen_bytes_ <= 10000
	cache.release_unused()
	assert cache.conversion_seen_.len == 0 && cache.conversion_seen_bytes_ == 0
}
