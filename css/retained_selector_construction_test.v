module css

import dom
import platform

fn test_short_selector_graph_survives_its_source_in_document_storage() {
	mut document := dom.Document.create(dom.url_about_blank())
	document.enable_native_storage()
	mut owner := document.enter_native_storage()
	for source in [':is(.one, #two) > [data-label="owned"]:not(:has(.missing))::before',
		':nth-child(2n+1 of .row, #last)', ':lang(en, "fr"):dir(rtl)',
		'.host::part(first second)::before',
		'main#patch.alpha.beta.gamma[hidden] > .panel + .before ~ aside > ul li[data-code="β"]'] {
		mut input := platform.new_arena('short selector source')
		entry := input.enter()
		text := source.clone()
		input.leave(entry)
		actual := parse_owned_selector(text)
		input.release()
		gc_collect()
		expected := selector_from_text_impl(source)
		assert actual.serialize() == expected.serialize()
		assert actual.specificity() == expected.specificity()
		assert actual.ancestor_hashes() == expected.ancestor_hashes()
		assert actual.sibling_invalidation_distance() == expected.sibling_invalidation_distance()
		assert actual.contains_the_nesting_selector() == expected.contains_the_nesting_selector()
		assert actual.has_part_pseudo_element() == expected.has_part_pseudo_element()
		assert actual.data_.contained_pseudo_classes == expected.data_.contained_pseudo_classes
	}
	assert !can_construct_selector_in_retained_owner('.long'.repeat(100))
	owner.finish()
	document.finalize()
	document.release_native_storage()
}

fn test_document_complex_selector_vector_storage() {
	$if prealloc {
		mut sources := []string{cap: 384}
		for index in 0 .. 128 {
			sources << '.patch-${index} > .title'
			sources << '.patch-${index} .item[data-active=true]:hover::before'
			sources << '.patch-${index}.featured > :is(.text, .icon) + .label'
		}
		mut document := dom.Document.create(dom.url_about_blank())
		document.enable_native_storage()
		defer {
			document.finalize()
			document.release_native_storage()
		}
		mut scope := document.enter_native_storage()
		defer { scope.finish() }
		storage := document.native_storage()
		before := storage.arena.usage().used
		mut selectors := []Selector{cap: sources.len}
		for source in sources {
			selectors << parse_owned_selector(source)
		}
		bytes := storage.arena.usage().used - before
		assert selectors[0].serialize() == '.patch-0 > .title'
		assert selectors.last().serialize() == '.patch-127.featured > :is(.text, .icon) + .label'
		for compound in selectors[0].compound_selectors() {
			assert compound.simple_selectors.cap == compound.simple_selectors.len
		}
		assert selectors[0].compound_selectors().cap == selectors[0].compound_selectors().len
		println('Document complex selector vectors retained ${bytes} bytes over ${selectors.len} selectors')
	}
}

fn test_selector_name_storage_shares_lowercase_spelling_and_keeps_unicode_folding() {
	lower := SelectorName.new('section'.clone())
	assert lower.lowercase_name == 'section'
	assert lower.lowercase_name.str == lower.name.str
	owned := own_parsed_selector_name(lower)
	assert owned.name.str != lower.name.str
	assert owned.lowercase_name.str == owned.name.str
	upper := SelectorName.new('dÁtA')
	assert upper.name == 'dÁtA'
	assert upper.lowercase_name == 'dáta'
}
