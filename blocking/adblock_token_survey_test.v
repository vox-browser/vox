module main

import dom

fn test_adblock_token_survey_matches_selectors_and_observes_live_light_tree_edits() {
	mut document := parse_browser_navigation_document('<!doctype html><body id="root"><div id="first" class="one two one"></div><p class="one two one"></p><div id="host"></div><template><p id="inert" class="inert"></p></template><svg><g id="svg" class="one&#9;svg"></g></svg></body>', dom.url_about_blank(), none)
	defer { document.finalize() }
	mut host := document.get_element_by_id('host')?
	shadow := host.attach_shadow(dom.ShadowRootInit{mode:.open})!
	mut shadow_node := unsafe { &dom.Node(shadow) }
	mut shadow_child := document.create_element('span')!
	shadow_child.set_attribute_value('class', 'shadow-only')
	_ = shadow_node.append_child(shadow_child.as_node())!
	assert browser_adblock_tokens(document) == selector_adblock_token_survey(document)
	assert '.inert' !in browser_adblock_tokens(document)
	assert '.shadow-only' !in browser_adblock_tokens(document)
	mut first := document.get_element_by_id('first')?
	for classes in ['two\tthree\nthree', '', 'one two one'] {
		first.set_attribute_value('id', 'changed')
		first.set_attribute_value('class', classes)
		assert browser_adblock_tokens(document) == selector_adblock_token_survey(document)
	}
	mut first_node := first.as_node()
	first_node.remove(false)
	assert browser_adblock_tokens(document) == selector_adblock_token_survey(document)
	assert '#changed' !in browser_adblock_tokens(document)
	mut svg := document.get_element_by_id('svg')?
	svg.set_attribute_value('class', 'new-svg')
	assert browser_adblock_tokens(document) == selector_adblock_token_survey(document)
	assert '.new-svg' in browser_adblock_tokens(document)
}
