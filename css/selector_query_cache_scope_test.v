module css

import dom
import platform

const scoped_query_html_namespace = 'http://www.w3.org/1999/xhtml'

fn scoped_query_expected(selector string) int {
	return if selector == 'option' { 3 } else { 0 }
}

// 2ch.su's catalog: Chromium select sizing ran the document's first 'option'
// query inside a flex item's intrinsic layout probe. The parsed-selector cache
// grew inside that scratch scope and later queries read released memory.
fn test_document_selector_cache_outlives_a_first_query_in_a_scratch_scope() {
	mut document := dom.Document.create(dom.url_about_blank())
	mut list := document.create_element_ns(scoped_query_html_namespace, 'select') or { panic(err) }
	document.as_node().append_child(list.as_node()) or { panic(err) }
	for value in ['standart', 'timestamp', 'posts_count'] {
		mut option := document.create_element_ns(scoped_query_html_namespace, 'option') or {
			panic(err)
		}
		option.set_attribute_value('value', value)
		list.as_node().append_child(option.as_node()) or { panic(err) }
	}
	root := document.as_node()
	mut selectors := ['option']
	for index in 0 .. 48 {
		selectors << 'option.c${index}, [value="v${index}"]'
	}
	scratch := platform.begin_thread_scratch('intrinsic layout probe')
	for selector in selectors {
		assert query_selector_all(root, selector).len == scoped_query_expected(selector)
	}
	scratch.finish()
	// Reuse and overwrite the released scratch memory.
	for _ in 0 .. 4 {
		reuse := platform.begin_thread_scratch('intrinsic layout probe')
		junk := []u8{len: 1 << 20, init: 0xa5}
		assert junk[0] == 0xa5 && junk[junk.len - 1] == 0xa5
		reuse.finish()
	}
	for selector in selectors {
		assert query_selector_all(root, selector).len == scoped_query_expected(selector)
	}
	assert query_selector_all(root, 'option[value="timestamp"]').len == 1
}
