module html

import dom

fn cross_origin_test_document(url string) &dom.Document {
	parsed := dom.URL{url}
	return &dom.Document{
		url:     parsed
		origin_: parsed.origin()
	}
}

fn test_cross_origin_property_tables_fallback_and_proxy_operations() {
	assert cross_origin_properties(.location).len == 2
	assert cross_origin_properties(.window).len == 13
	assert is_cross_origin_accessible_window_property_name('postMessage')
	assert is_cross_origin_accessible_window_property_name('0')
	assert !is_cross_origin_accessible_window_property_name('secret')
	assert cross_origin_property_fallback('then')!.value.is_undefined()

	document := cross_origin_test_document('https://target.test/')
	window := WindowModel.create_top_level(document, none, 'target')!
	proxy := window.window()
	assert cross_origin_get(proxy, dom.Origin{ value: 'https://caller.test' }, 'closed')!.kind == .boolean
	if _ := cross_origin_get(proxy, dom.Origin{ value: 'https://caller.test' }, 'secret') {
		assert false
	} else {
		assert err.msg().contains('SecurityError')
	}
	assert cross_origin_own_property_keys(proxy, dom.Origin{ value: 'https://caller.test' }).contains('postMessage')
}

fn test_cross_origin_reporting_guards_and_relationship() {
	page_a := &dom.Page{}
	page_b := &dom.Page{}
	mut group_a := BrowsingContextGroup.create(page_a)
	mut group_b := BrowsingContextGroup.create(page_b)
	document_a := cross_origin_test_document('https://a.test/')
	document_b := cross_origin_test_document('https://b.test/')
	mut context_a := BrowsingContextModel.create(document_a, none, 'a')
	mut context_b := BrowsingContextModel.create(document_b, none, 'b')
	group_a.append_model(context_a)
	group_b.append_model(context_b)
	context_b.set_opener(context_a)
	report := check_if_access_between_two_browsing_contexts_should_be_reported(context_a,
		context_b, 'closed') or { panic('expected report') }
	assert report.relationship == .accessor_is_opener
	assert report.accessor_url == document_a.url
	assert check_if_access_between_two_browsing_contexts_should_be_reported(context_a, context_b,
		'secret') == none
}
