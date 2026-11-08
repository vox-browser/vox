module main

import css
import dom
import html
import layout
import time

@[heap]
struct ChildAdblockMessages {
mut:
	values []string
}

fn child_adblock_fixture(scripting bool) &BrowserHostedDocument {
	mut document := parse_browser_navigation_document('<!doctype html><style>' +
		'a{display:block!important}#news{color:green}</style>' +
		'<a id="paid" href="https://example.com/?erid=fixture">Paid</a>' +
		'<p id="news">News</p>', dom.URL{ value: 'https://sponsor.cybersport.ru/web/header-desktop' }, none)
	document.set_scripting_enabled_by_embedder(scripting)
	mut service := &BrowserHostedDocument{ document: document }
	mut messages := []string{}
	service.initialize(.javascriptcore, mut messages)
	assert service.initialized
	assert messages.len == 0, messages.join('\n')
	return service
}

fn close_child_adblock_fixture(mut service BrowserHostedDocument) {
	service.close()
	mut document := unsafe { &dom.Document(service.document) }
	document.finalize()
	document.release_native_storage()
}

fn test_hosted_document_applies_its_own_cosmetic_filters_without_author_scripts() {
	$if !darwin {
		return
	}
	mut service := child_adblock_fixture(false)
	defer { close_child_adblock_fixture(mut service) }
	_ = layout.layout_document_typed_in_viewport(service.document, 320, 200)
	paid := service.document.get_element_by_id('paid')?
	assert css.up_to_date_computed_properties_for_element(paid).display().is_none()
	assert paid.bounding_client_rect_assuming_layout_clean().width == 0
	news := service.document.get_element_by_id('news')?
	assert news.bounding_client_rect_assuming_layout_clean().height > 0
	assert service.runtime == unsafe { nil }
	assert service.adblock_tokens.document == voidptr(service.document)

	// Native mutations must refresh generic selectors as well as domain rules.
	mut node := service.document.create_element('div')!
	node.set_attribute_value('class', 'ad-banner-300')
	service.document.body()?.as_node().append_child(node.as_node())!
	mut messages := []string{}
	assert service.poll(mut messages)
	assert messages.len == 0, messages.join('\n')
	_ = layout.layout_document_typed_in_viewport(service.document, 320, 200)
	assert css.up_to_date_computed_properties_for_element(node).display().is_none()
	assert !service.poll(mut messages)
}

fn test_hosted_document_refreshes_cosmetic_filters_after_scripted_mutations() {
	$if !darwin {
		return
	}
	mut service := child_adblock_fixture(true)
	defer { close_child_adblock_fixture(mut service) }
	assert service.runtime != unsafe { nil }
	service.runtime.evaluate_host('setTimeout(()=>{document.getElementById("news").className="ad-banner-300";},0);0')!
	trace := &ChildAdblockMessages{}
	deadline := time.sys_mono_now() + 5 * time.second
	mut loop := html.main_thread_event_loop()
	loop.spin_until(fn [service, trace, deadline] () bool {
		mut owner := unsafe { &BrowserHostedDocument(service) }
		mut messages := unsafe { &ChildAdblockMessages(trace) }
		owner.poll(mut messages.values)
		news := service.document.get_element_by_id('news') or { return false }
		return news.get_attribute_value('class') == 'ad-banner-300' || time.sys_mono_now() >= deadline
	})
	assert trace.values.len == 0, trace.values.join('\n')
	_ = layout.layout_document_typed_in_viewport(service.document, 320, 200)
	news := service.document.get_element_by_id('news')?
	assert css.up_to_date_computed_properties_for_element(news).display().is_none()
	service.close()
	assert !service.adblock_tokens.valid
	assert service.adblock_tokens.storage == unsafe { nil }
}
