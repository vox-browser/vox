module css

import dom

fn direct_attribute_fixture_selector(text string) SelectorAttribute {
	list := parse_selector_with_parser(text, {
		'a':       true
		'b':       true
		'missing': true
	}) or { panic(text) }
	return list.selectors[0].compound_selectors()[0].simple_selectors[0].attribute()
}

fn direct_attribute_fixture_matches(text string, element &dom.Element, sheet ?&CSSStyleSheet) bool {
	return matches_attribute(direct_attribute_fixture_selector(text), sheet, element)
}

fn test_direct_attribute_matching_keeps_all_value_operators_and_empty_values() {
	mut document := dom.Document.create(dom.url_about_blank())
	defer { document.finalize() }
	document.set_document_type(.html)
	mut element := document.create_element_ns(dom.namespace_html_uri, 'div')!
	element.set_attribute_value('data-value', 'Hello two en-US')
	element.set_attribute_value('data-empty', '')
	for selector, expected in {
		'[data-value]':                     true
		'[missing]':                        false
		'[data-value="Hello two en-US"]':   true
		'[data-value="hello two en-US"]':   false
		'[data-value="hello two EN-us" i]': true
		'[data-value~=two]':                true
		'[data-value~=Hello]':              true
		'[data-value~=Hello i]':            true
		'[data-value~=missing]':            false
		'[data-value^=Hello]':              true
		'[data-value^=hello]':              false
		'[data-value$=en-US]':              true
		'[data-value*=lo\\ two]':           true
		'[data-empty]':                     true
		'[data-empty=""]':                  true
		'[data-empty|=""]':                 true
		'[data-empty~=""]':                 false
		'[data-empty^=""]':                 false
		'[data-empty$=""]':                 false
		'[data-empty*=""]':                 false
	} {
		assert direct_attribute_fixture_matches(selector, element, none) == expected, selector
	}
	element.set_attribute_value('lang', 'en-US')
	assert direct_attribute_fixture_matches('[lang|=en]', element, none)
	assert !direct_attribute_fixture_matches('[lang|=e]', element, none)
}

fn test_direct_attribute_wildcard_namespace_visits_later_matching_values() {
	mut document := dom.Document.create(dom.url_about_blank())
	defer { document.finalize() }
	document.set_document_type(.html)
	mut element := document.create_element_ns(dom.namespace_html_uri, 'div')!
	element.set_attribute_ns_for_bindings('urn:a', 'a:data-key', 'first')!
	element.set_attribute_ns_for_bindings('urn:b', 'b:data-key', 'second')!
	element.set_attribute_value('data-key', 'plain')
	sheet := parse_css_stylesheet_with_parser('@namespace a "urn:a";@namespace b "urn:b";', none)
	assert direct_attribute_fixture_matches('[*|data-key=first]', element, sheet)
	assert direct_attribute_fixture_matches('[*|data-key=second]', element, sheet)
	assert direct_attribute_fixture_matches('[*|data-key=plain]', element, sheet)
	assert !direct_attribute_fixture_matches('[*|data-key=absent]', element, sheet)
	assert direct_attribute_fixture_matches('[*|DATA-KEY=second]', element, sheet)
	assert direct_attribute_fixture_matches('[a|data-key=first]', element, sheet)
	assert !direct_attribute_fixture_matches('[a|data-key=second]', element, sheet)
	assert direct_attribute_fixture_matches('[b|data-key=second]', element, sheet)
	assert direct_attribute_fixture_matches('[|data-key=plain]', element, sheet)
	assert direct_attribute_fixture_matches('[data-key=plain]', element, sheet)
	assert !direct_attribute_fixture_matches('[a|data-key]', element, none)
	assert !direct_attribute_fixture_matches('[missing|data-key]', element, sheet)
	default_sheet := parse_css_stylesheet_with_parser('@namespace "urn:default";', none)
	assert direct_attribute_fixture_matches('[data-key=plain]', element, default_sheet)
}

fn test_direct_attribute_name_and_value_case_keep_html_svg_xml_and_unicode_distinct() {
	for html_document in [true, false] {
		mut document := dom.Document.create(dom.url_about_blank())
		defer { document.finalize() }
		document.set_document_type(if html_document { .html } else { .xml })
		for namespace in [dom.namespace_html_uri, 'http://www.w3.org/2000/svg'] {
			mut element := document.create_element_ns(namespace, 'g')!
			element.set_attribute_value('type', 'TeXt')
			element.set_attribute_value('data-upper', 'CAFÉ')
			html_case := html_document && namespace == dom.namespace_html_uri
			assert direct_attribute_fixture_matches('[type=text]', element, none) == html_case
			assert !direct_attribute_fixture_matches('[type=text s]', element, none)
			assert direct_attribute_fixture_matches('[type=text i]', element, none)
			assert direct_attribute_fixture_matches('[*|TYPE=TeXt]', element, none) == html_case
			assert direct_attribute_fixture_matches('[data-upper="cafÉ" i]', element, none)
			assert !direct_attribute_fixture_matches('[data-upper="café" i]', element, none)
		}
	}
}

fn test_direct_attribute_queries_follow_namespace_removal_and_replacement_after_gc() {
	mut document := dom.Document.create(dom.url_about_blank())
	defer { document.finalize() }
	mut element := document.create_element_ns(dom.namespace_html_uri, 'div')!
	sheet := parse_css_stylesheet_with_parser('@namespace a "urn:a";@namespace b "urn:b";', none)
	element.set_attribute_ns_for_bindings('urn:a', 'a:key', 'unchanged')!
	for index in 0 .. 3 {
		element.set_attribute_ns_for_bindings('urn:b', 'b:key', 'live')!
		assert direct_attribute_fixture_matches('[*|key=live]', element, sheet)
		assert direct_attribute_fixture_matches('[b|key=live]', element, sheet)
		element.remove_attribute_ns('urn:b', 'key')
		gc_collect()
		assert !direct_attribute_fixture_matches('[*|key=live]', element, sheet)
		assert !direct_attribute_fixture_matches('[b|key]', element, sheet)
		assert direct_attribute_fixture_matches('[a|key=unchanged]', element, sheet)
		if index == 1 {
			element.set_attribute_value('key', 'live')
			assert direct_attribute_fixture_matches('[*|key=live]', element, sheet)
			assert direct_attribute_fixture_matches('[|key=live]', element, sheet)
			element.remove_attribute('key')
		}
	}
}

fn test_direct_attribute_namespace_names_remain_case_sensitive_and_missing_lists_stay_absent() {
	mut document := dom.Document.create(dom.url_about_blank())
	defer { document.finalize() }
	mut element := document.create_element_ns('urn:elements', 'item')!
	assert element.attribute_list() == none
	for selector in ['[key]', '[*|key]', '[|key]', '[a|key]'] {
		assert !direct_attribute_fixture_matches(selector, element, none)
	}
	assert element.attribute_list() == none
	element.set_attribute_ns_for_bindings('urn:A', 'a:Key', 'value')!
	sheet := parse_css_stylesheet_with_parser('@namespace a "urn:A";@namespace b "urn:a";', none)
	assert direct_attribute_fixture_matches('[a|Key=value]', element, sheet)
	assert !direct_attribute_fixture_matches('[a|key=value]', element, sheet)
	assert !direct_attribute_fixture_matches('[b|Key=value]', element, sheet)
	assert direct_attribute_fixture_matches('[*|Key=value]', element, sheet)
	assert !direct_attribute_fixture_matches('[*|key=value]', element, sheet)
}
