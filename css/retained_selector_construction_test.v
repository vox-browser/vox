module css

import dom
import platform

fn test_short_selector_graph_survives_its_source_in_document_storage() {
	mut document := dom.Document.create(dom.url_about_blank())
	document.enable_native_storage()
	mut owner := document.enter_native_storage()
	for source in [':is(.one, #two) > [data-label="owned"]:not(:has(.missing))::before',
		':nth-child(2n+1 of .row, #last)', ':lang(en, "fr"):dir(rtl)',
		'.host::part(first second)::before'] {
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
