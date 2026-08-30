module html

import dom

fn test_storage_order_quota_named_properties_and_broadcast() {
	mut hub := StorageHub.create()
	mut bottle := StorageBottle.create(64)
	origin := dom.Origin{
		value: 'https://example.test'
	}
	mut first := Storage.create(.local, bottle, mut hub, origin, 'top-a', dom.URL{
		value: 'https://example.test/one'
	})
	mut second := Storage.create(.local, bottle, mut hub, origin, 'top-b', dom.URL{
		value: 'https://example.test/two'
	})
	first.set_item('alpha', '1')!
	first.set_item('beta', '2')!
	assert first.length() == 2
	assert first.key(0)? == 'alpha'
	assert first.supported_property_names() == ['alpha', 'beta']
	first.reorder()
	first.dump()
	assert second.get_item('alpha')? == '1'
	assert second.events().len == 2
	assert second.events()[0].url == 'https://example.test/one'
	assert first.named_item_value('alpha').string_data == '1'
	first.remove_item('alpha')
	assert first.key(0)? == 'beta'
	first.clear()
	assert first.length() == 0
	if _ := first.set_item('large', 'x'.repeat(80)) {
		assert false
	} else {
		assert err.msg().starts_with('QuotaExceededError:')
	}
}

fn test_session_storage_broadcast_is_limited_to_traversable() {
	mut hub := StorageHub.create()
	mut bottle := StorageBottle.create(none)
	origin := dom.Origin{
		value: 'https://example.test'
	}
	mut first := Storage.create(.session, bottle, mut hub, origin, 'top-a', dom.URL{
		value: 'https://example.test/'
	})
	mut same_top := Storage.create(.session, bottle, mut hub, origin, 'top-a', dom.URL{
		value: 'https://example.test/frame'
	})
	mut other_top := Storage.create(.session, bottle, mut hub, origin, 'top-b', dom.URL{
		value: 'https://example.test/other'
	})
	first.set_item('key', 'value')!
	assert same_top.events().len == 1
	assert other_top.events().len == 0
}

fn test_history_push_replace_traverse_scroll_and_url_security() {
	mut history := History.create(dom.URL{ value: 'https://example.test/a' },
		dom.js_string('initial'))!
	history.push_state(dom.js_string('one'), '', '/one?x=1')!
	history.push_state(dom.js_number(2), '', '/two')!
	assert history.length()! == 3
	assert history.current_url().serialize() == 'https://example.test/two'
	history.back()!
	assert history.current_url().serialize() == 'https://example.test/one?x=1'
	assert history.state()!.string_data == 'one'
	history.replace_state(dom.js_string('replaced'), '', '#fragment')!
	assert history.length()! == 3
	assert history.current_url().serialize().ends_with('#fragment')
	history.set_scroll_restoration(.manual)!
	assert history.scroll_restoration()! == .manual
	history.go(0)!
	assert history.last_traversal().action == .reload
	history.delta_traverse(-1)!
	assert history.last_traversal().action == .traverse
	assert history.last_traversal().delta == -1
	if _ := history.push_state(dom.js_null(), '', 'https://other.test/no') {
		assert false
	} else {
		assert err.msg().starts_with('SecurityError:')
	}
	assert can_have_its_url_rewritten(dom.URL{ value: 'https://example.test/a' }, dom.URL{
		value: 'https://example.test/anything'
	})
}
