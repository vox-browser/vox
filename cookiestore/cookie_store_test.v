module cookiestore

import html
import url

fn cookie_test_url(path string) url.URL {
	return url.URL{
		scheme: 'https'
		host:   url.Host.from_string('www.example.com')
		paths:  path.trim_left('/').split('/')
	}
}

fn cookie_test_store(mut event_loop html.EventLoop, backend &CookieStoreBackend, path string) &CookieStore {
	creation := cookie_test_url(path)
	return CookieStore.create(backend, CookieStoreEnvironment{
		creation_url: creation
		api_base_url: creation
		is_window:    true
	}, event_loop)
}

fn drain_cookie_test_event_loop(mut event_loop html.EventLoop) {
	mut iterations := 0
	for event_loop.task_queue().has_runnable_tasks() {
		event_loop.process()
		iterations++
		assert iterations < 100
	}
}

fn test_cookie_url_parser_resolves_and_compares_hierarchical_urls() {
	base := cookie_test_url('/account/page')
	absolute := parse_cookie_store_url('HTTPS://WWW.EXAMPLE.COM:443/account/page#x', &base) or {
		panic('absolute URL should parse')
	}
	assert absolute.serialize(false) == 'https://www.example.com/account/page#x'
	assert absolute.equals(&base, true)
	relative := parse_cookie_store_url('../settings?tab=cookies', &base) or {
		panic('relative URL should parse')
	}
	assert relative.serialize(false) == 'https://www.example.com/settings?tab=cookies'
	assert parse_cookie_store_url('https://:bad/', &base) == none
	assert parse_cookie_store_url('data:text/plain,no', &base) == none
	assert serialized_cookie_default_path(&base) == '/account'
	root := cookie_test_url('/')
	assert serialized_cookie_default_path(&root) == '/'
}

fn test_set_a_cookie_normalizes_validates_and_caps_expiration() {
	mut backend := CookieStoreBackend.create()
	backend.set_now_override(f64(1_000_000))
	record := cookie_test_url('/dir/page')
	assert set_a_cookie(mut backend, &record, CookieInit{
		name:      '  session\t'
		value:     '\tvalue  '
		expires:   f64(100_000_000_000)
		domain:    'example.com'
		path:      ''
		same_site: .lax
	})
	cookies := backend.cookies()
	assert cookies.len == 1
	assert cookies[0].name == 'session'
	assert cookies[0].value == 'value'
	assert cookies[0].domain == 'example.com'
	assert !cookies[0].host_only
	assert cookies[0].path == '/dir'
	assert cookies[0].secure
	assert cookies[0].same_site == .lax
	assert cookies[0].expires or { 0 } == 1_000_000 + maximum_cookie_age_ms

	invalid := [
		CookieInit{
			name:  'a;b'
			value: 'x'
		},
		CookieInit{
			name:  'a=b'
			value: 'x'
		},
		CookieInit{
			name:  ''
			value: ''
		},
		CookieInit{
			name:  ''
			value: '__Secure-token'
		},
		CookieInit{
			name:  '__Http-token'
			value: 'x'
		},
		CookieInit{
			name:   '__Host-token'
			value:  'x'
			domain: 'example.com'
		},
		CookieInit{
			name:  '__Host-token'
			value: 'x'
			path:  '/dir'
		},
		CookieInit{
			name:   'x'
			value:  'y'
			domain: '.example.com'
		},
		CookieInit{
			name:   'x'
			value:  'y'
			domain: 'attacker.test'
		},
		CookieInit{
			name:  'x'
			value: 'y'
			path:  'relative'
		},
		CookieInit{
			name:  'bad\x00name'
			value: 'y'
		},
	]
	for candidate in invalid {
		assert !set_a_cookie(mut backend, &record, candidate)
	}
	assert !set_a_cookie(mut backend, &record, CookieInit{
		name:  'n'.repeat(4097)
		value: ''
	})
}

fn test_backend_query_applies_non_http_cookie_retrieval_rules_and_order() {
	mut backend := CookieStoreBackend.create()
	backend.set_now_override(f64(10_000))
	backend.seed(Cookie{
		name:   'root'
		value:  '1'
		domain: 'www.example.com'
		path:   '/'
		secure: true
	})
	backend.seed(Cookie{
		name:      'specific'
		value:     '2'
		domain:    'example.com'
		path:      '/account'
		secure:    true
		host_only: false
	})
	backend.seed(Cookie{ name: 'http', value: 'hidden', domain: 'www.example.com', http_only: true })
	backend.seed(Cookie{
		name:    'expired'
		value:   'hidden'
		domain:  'www.example.com'
		expires: f64(9999)
	})
	backend.seed(Cookie{ name: 'other', value: 'hidden', domain: 'other.test' })
	backend.seed(Cookie{
		name:   'wrong-path'
		value:  'hidden'
		domain: 'www.example.com'
		path:   '/accounts'
	})
	record := cookie_test_url('/account/page')
	matches := backend.query(&record)
	assert matches.len == 2
	assert matches[0].name == 'specific'
	assert matches[1].name == 'root'
	mut insecure := cookie_test_url('/account/page')
	insecure.scheme = 'http'
	assert backend.query(&insecure).len == 0
}

fn test_cookie_store_get_and_get_all_are_asynchronous_and_validate_options() {
	mut event_loop := html.EventLoop.create(.window)
	mut backend := CookieStoreBackend.create()
	backend.seed(Cookie{ name: 'session', value: 'root', domain: 'www.example.com', path: '/' })
	backend.seed(Cookie{
		name:   'session'
		value:  'specific'
		domain: 'www.example.com'
		path:   '/account'
	})
	backend.seed(Cookie{ name: 'other', value: 'present', domain: 'www.example.com', path: '/' })
	store := cookie_test_store(mut event_loop, backend, '/account/page')

	first := store.get(' session ')
	all := store.get_all('session')
	missing := store.get('missing')
	assert first.state() == .pending
	drain_cookie_test_event_loop(mut event_loop)
	assert first.state() == .fulfilled
	first_item := first.item() or { panic('missing cookie') }
	assert first_item.value or { panic('missing value') } == 'specific'
	assert all.items().len == 2
	assert missing.state() == .fulfilled
	assert missing.item() == none

	empty := store.get_with_options(CookieStoreGetOptions{})
	invalid := store.get_with_options(CookieStoreGetOptions{ url: 'not a URL' })
	cross_origin := store.get_all_with_options(CookieStoreGetOptions{
		url: 'https://other.test/account/page'
	})
	wrong_window_url := store.get_all_with_options(CookieStoreGetOptions{ url: '/other' })
	assert empty.state() == .rejected
	assert empty.reason().contains('empty')
	assert invalid.state() == .rejected
	assert cross_origin.state() == .rejected
	assert wrong_window_url.state() == .rejected

	creation := cookie_test_url('/account/page')
	worker_store := CookieStore.create(backend, CookieStoreEnvironment{
		creation_url: creation
		api_base_url: creation
		is_window:    false
	}, event_loop)
	worker_query := worker_store.get_all_with_options(CookieStoreGetOptions{ url: '/other' })
	drain_cookie_test_event_loop(mut event_loop)
	assert worker_query.state() == .fulfilled
	assert worker_query.items().len == 2
}

fn test_cookie_store_set_and_delete_cross_backend_boundary_asynchronously() {
	mut event_loop := html.EventLoop.create(.window)
	mut backend := CookieStoreBackend.create()
	backend.set_now_override(f64(50_000))
	store := cookie_test_store(mut event_loop, backend, '/dir/page')
	set_result := store.set(' token ', ' abc ')
	set_options := store.set_with_options(CookieInit{
		name:      'scoped'
		value:     'yes'
		domain:    'example.com'
		path:      '/dir'
		same_site: .none
	})
	assert set_result.state() == .pending
	assert backend.cookies().len == 0
	drain_cookie_test_event_loop(mut event_loop)
	assert set_result.state() == .fulfilled
	assert set_options.state() == .fulfilled
	assert backend.cookies().len == 2
	assert backend.cookies()[0].name == 'token'
	assert backend.cookies()[0].value == 'abc'

	delete_result := store.delete_(' token ')
	assert delete_result.state() == .pending
	drain_cookie_test_event_loop(mut event_loop)
	assert delete_result.state() == .fulfilled
	assert backend.cookies().len == 1
	assert backend.cookies()[0].name == 'scoped'
	assert backend.mutations().last().deleted
	assert backend.mutations().last().cookie.expires or { 1 } < 50_000
}

fn test_cookie_store_rejects_malformed_writes_and_opaque_origins() {
	mut event_loop := html.EventLoop.create(.window)
	backend := CookieStoreBackend.create()
	creation := cookie_test_url('/')
	opaque := CookieStore.create(backend, CookieStoreEnvironment{
		creation_url:     creation
		api_base_url:     creation
		origin_is_opaque: true
	}, event_loop)
	assert opaque.get('x').reason().starts_with('SecurityError:')
	assert opaque.get_all('x').state() == .rejected
	assert opaque.set('x', 'y').state() == .rejected
	assert opaque.delete_('x').state() == .rejected

	store := cookie_test_store(mut event_loop, backend, '/')
	malformed := store.set('bad;name', 'value')
	bad_delete := store.delete_with_options(CookieStoreDeleteOptions{
		name: 'x'
		path: 'relative'
	})
	drain_cookie_test_event_loop(mut event_loop)
	assert malformed.state() == .rejected
	assert malformed.reason().contains('Name or value')
	assert bad_delete.state() == .rejected
	assert bad_delete.reason().contains('Name is malformed')
}
