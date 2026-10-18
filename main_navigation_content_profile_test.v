module main

import crypto.sha256
import dom

fn test_navigation_content_profile_observes_live_classes_and_hashes_the_document_url() {
	address := 'https://profile.test/search?q=private-term'
	mut document := parse_browser_navigation_document('<!doctype html><div id="one" class="result other result"></div><span class="result"></span><p class="Result"></p>', dom.URL{value: address}, none)
	defer { document.finalize() }
	first := navigation_content_profile(document, 'result')
	assert first.class_matches == 2
	assert first.elements == 6
	assert first.url_sha256 == sha256.hexhash(document.url.serialize())
	mut one := document.get_element_by_id('one')?
	one.set_attribute_value('class', 'changed')
	assert navigation_content_profile(document, 'result').class_matches == 1
}
