module main

import dom
import platform

fn test_github_cosmetic_token_stamp_ignores_only_unread_attributes() {
	mut document := parse_browser_navigation_document('<!doctype html><div id="first" class="one"></div>', dom.URL{value:'https://github.com/vlang/v'}, none)
	defer { document.finalize() }
	mut cache := BrowserAdblockTokenCache{}
	defer { cache.release() }
	assert cache.survey(document) == ['#first', '.one']
	before := site_cosmetic_token_attribute_stamp(document)
	mut element := document.get_element_by_id('first')?
	element.set_attribute_value('data-twiddle', '123')
	element.set_attribute_value('aria-hidden', 'true')
	after := site_cosmetic_token_attribute_stamp(document)
	assert (before.version == after.version) == !disable_github_cosmetic_token_reuse
	assert cache.survey(document) == ['#first', '.one']
	mut text_parent := element.as_node()
	text_parent.set_text_content('relative time changed')!
	text_stamp := site_cosmetic_token_attribute_stamp(document)
	assert (text_stamp.tree_version == after.tree_version) == !disable_github_cosmetic_token_reuse
	assert cache.survey(document) == ['#first', '.one']
	element.set_attribute_value('class', 'two three')
	assert cache.survey(document) == ['#first', '.three', '.two']
	element.remove_attribute('id')
	assert cache.survey(document) == ['.three', '.two']
}

fn test_github_cosmetic_tokens_keep_tree_changes_and_rollback_scope() {
	mut document := parse_browser_navigation_document('<!doctype html><main id="root"></main>', dom.URL{value:'https://github.com/vlang/v'}, none)
	defer { document.finalize() }
	mut cache := BrowserAdblockTokenCache{}
	defer { cache.release() }
	assert cache.survey(document) == ['#root']
	mut child := document.create_element_ns(dom.namespace_html_uri, 'span')!
	child.set_attribute_value('class', 'new')
	mut parent := document.get_element_by_id('root')?
	mut node := parent.as_node()
	node.append_child(child.as_node())!
	assert cache.survey(document) == ['#root', '.new']
	child.as_node().remove(false)
	assert cache.survey(document) == ['#root']
	document.url = dom.URL{value:'https://example.test/'}
	assert !site_cosmetic_token_attribute_stamp(document).id_class_only
	before := site_cosmetic_token_attribute_stamp(document).version
	parent.set_attribute_value('aria-label', 'changed')
	assert site_cosmetic_token_attribute_stamp(document).version > before
	assert cache.survey(document) == ['#root']
}

fn test_cosmetic_token_epoch_kinds_cannot_alias_when_document_url_changes() {
	mut document := parse_browser_navigation_document('<!doctype html><div id="item" class="original"></div>', dom.URL{value:'https://example.test/'}, none)
	defer { document.finalize() }
	mut element := document.get_element_by_id('item')?
	element.set_attribute_value('data-unrelated', 'value')
	mut cache := BrowserAdblockTokenCache{}
	defer { cache.release() }
	assert cache.survey(document) == ['#item', '.original']
	saved := document.attribute_version()
	mut last_class := ''
	for document.light_dom_id_class_attribute_version() < saved {
		last_class = 'updated-${document.light_dom_id_class_attribute_version()}'
		element.set_attribute_value('class', last_class)
	}
	assert last_class != ''
	document.url = dom.URL{value:'https://github.com/vlang/v'}
	if !disable_github_cosmetic_token_reuse {
		assert site_cosmetic_token_attribute_stamp(document).version == cache.attribute_version
	}
	assert cache.survey(document) == ['#item', '.${last_class}']
}

fn test_cosmetic_token_scope_keeps_chatgpt_url_boundaries() {
	mut document := parse_browser_navigation_document('<!doctype html><div></div>',
		dom.URL{value: 'https://chatgpt.com/'}, none)
	defer { document.finalize() }
	for address in ['https://chatgpt.com', 'HTTPS://CHATGPT.COM:443/chat'] {
		document.url = dom.URL{value: address}
		assert site_cosmetic_token_attribute_stamp(document).id_class_only == !disable_chatgpt_cosmetic_token_reuse
	}
	for address in ['http://chatgpt.com/', 'https://chatgpt.com.:443/',
		'https://chatgpt.com:8443/', 'https://user@chatgpt.com/', 'https://chatgpt.com.example/'] {
		document.url = dom.URL{value: address}
		assert !site_cosmetic_token_attribute_stamp(document).id_class_only
	}
}

fn test_cosmetic_token_stamp_reuses_the_current_document_url_without_allocating() {
	$if prealloc {
		mut document := parse_browser_navigation_document('<!doctype html><div></div>',
			dom.URL{value: 'https://www.dota2.com/patches/7.42a'}, none)
		defer { document.finalize() }
		expected := site_cosmetic_token_attribute_stamp(document)
		assert !expected.id_class_only
		before := platform.thread_arena_usage().used
		for _ in 0 .. 1024 {
			assert site_cosmetic_token_attribute_stamp(document) == expected
		}
		assert platform.thread_arena_usage().used == before
	}
}
