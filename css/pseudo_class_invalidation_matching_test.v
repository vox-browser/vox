module css

import dom

fn invalidation_test_selector(text string) Selector {
	list := parse_selector_with_parser(text, map[string]bool{}) or {
		panic('selector did not parse: ${text}')
	}
	return list.selectors[0]
}

fn test_pseudo_class_invalidation_matches_only_the_selector_target() {
	document := dom.Document.create(dom.url_about_blank())
	element := document.create_element_ns('http://www.w3.org/1999/xhtml', 'div') or {
		panic(err)
	}

	assert selector_matches_pseudo_class_invalidation_candidate(invalidation_test_selector('div'), element)
	assert selector_matches_pseudo_class_invalidation_candidate(invalidation_test_selector('div::before'), element)
	assert selector_matches_pseudo_class_invalidation_candidate(invalidation_test_selector('div::after'), element)
	assert !selector_matches_pseudo_class_invalidation_candidate(invalidation_test_selector('div::first-line'), element)
	assert !selector_matches_pseudo_class_invalidation_candidate(invalidation_test_selector('span::before'), element)
}
