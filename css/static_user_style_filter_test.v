module css

import dom

fn test_static_user_style_projection_requires_all_static_predicates() {
	mut document, first, _, _ := user_change_fixture()
	defer { document.finalize() }
	mut element := unsafe { &dom.Element(first) }
	projection := static_user_style_subject(selector_from_text('main > div.first[data-kind^="ad-"][title="match"]:hover::before')) or { panic('missing projection') }
	element.set_attribute_value('data-kind', 'ad-banner')
	mut context := MatchContext{}
	assert !matches(projection, element, none, mut context, none, none, .normal, none)
	element.set_attribute_value('title', 'match')
	assert matches(projection, element, none, mut context, none, none, .normal, none)
	element.set_attribute_value('class', 'other')
	assert !matches(projection, element, none, mut context, none, none, .normal, none)
	assert static_user_style_subject(selector_from_text(':is(.first,.second)')) == none
	assert static_user_style_subject(selector_from_text('.first::part(label)')) == none
	assert static_user_style_subject(selector_from_text('slot::slotted(.first)')) == none
}

fn test_static_user_style_filter_skips_value_mismatches_but_later_attribute_changes_match() {
	mut document, first, _, _ := user_change_fixture()
	defer { document.finalize() }
	previous := first.el_computed_properties() or { panic('missing style') }
	set_document_user_style_sheet(document, '[class^="advert"] {color:red!important}')
	document.update_style()
	assert user_change_color(first) == 'rgb(0, 0, 255)'
	assert (voidptr(first.el_computed_properties() or { panic('missing style') }) == voidptr(previous)) == !disable_static_user_style_filter
	mut target := unsafe { &dom.Element(first) }
	target.set_attribute_value('class', 'advert-banner')
	document.update_style()
	assert user_change_color(first) == 'rgb(255, 0, 0)'
	set_document_user_style_sheet(document, '[class^="other"] {color:lime!important}')
	document.update_style()
	assert user_change_color(first) == 'rgb(0, 0, 255)'
}

fn test_static_user_style_filter_preserves_has_dependencies_after_an_initial_rejection() {
	mut document, first, _, _ := user_change_fixture()
	defer { document.finalize() }
	set_document_user_style_sheet(document, '.first[data-kind="advert"]:has(.flag) {color:red!important}')
	document.update_style()
	mut target := unsafe { &dom.Element(first) }
	target.set_attribute_value('data-kind', 'advert')
	document.update_style()
	assert user_change_color(first) == 'rgb(0, 0, 255)'
	flag := user_change_element(document, first.as_node(), 'span', 'flag')
	document.update_style()
	assert user_change_color(first) == 'rgb(255, 0, 0)'
	mut flag_node := flag.as_node()
	flag_node.remove(true)
	document.update_style()
	assert user_change_color(first) == 'rgb(0, 0, 255)'
}

fn test_static_user_style_filter_preserves_pseudo_generation_after_attribute_changes() {
	mut document, first, _, _ := user_change_fixture()
	defer { document.finalize() }
	set_document_user_style_sheet(document, '.first[data-kind="advert"]::before {content:"advert"}')
	document.update_style()
	assert computed_properties_for_pseudo_element(first, .before) == none
	mut target := unsafe { &dom.Element(first) }
	target.set_attribute_value('data-kind', 'advert')
	document.update_style()
	assert computed_properties_for_pseudo_element(first, .before) != none
	set_document_user_style_sheet(document, '.first[data-kind="other"]::before {content:"other"}')
	document.update_style()
	assert computed_properties_for_pseudo_element(first, .before) == none
}

fn test_static_user_style_filter_preserves_fallback_anchors_and_selector_lists() {
	mut document, first, second, _ := user_change_fixture()
	defer { document.finalize() }
	child := user_change_element(document, first.as_node(), 'span', '')
	set_document_user_style_sheet(document, '.first > * {color:red!important} :is(.first,.second) {color:lime!important} [class^="absent"] {color:black!important}')
	document.update_style()
	assert user_change_color(first) == 'rgb(0, 255, 0)'
	assert user_change_color(second) == 'rgb(0, 255, 0)'
	assert user_change_color(child) == 'rgb(255, 0, 0)'
	set_document_user_style_sheet(document, '[class^="absent"] {color:black!important}')
	document.update_style()
	assert user_change_color(first) == 'rgb(0, 0, 255)'
	assert user_change_color(second) == 'rgb(0, 0, 255)'
	assert user_change_color(child) == 'rgb(0, 0, 255)'
}

fn test_static_user_style_filter_keeps_quirks_case_folding_and_attribute_flags() {
	mut document, first, _, _ := user_change_fixture()
	defer { document.finalize() }
	document.set_quirks_mode(.yes)
	mut target := unsafe { &dom.Element(first) }
	target.set_attribute_value('data-kind', 'ADVERT')
	document.set_needs_full_style_update(true)
	document.update_style()
	set_document_user_style_sheet(document, '.FIRST[data-kind="advert" i] {color:red!important}')
	document.update_style()
	assert user_change_color(first) == 'rgb(255, 0, 0)'
	set_document_user_style_sheet(document, '.FIRST[data-kind="other" i] {color:lime!important}')
	document.update_style()
	assert user_change_color(first) == 'rgb(0, 0, 255)'
}
