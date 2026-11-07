module browsercookies

import httpcookie
import os
import time
import url

fn test_imported_cookie_jar_scopes_http_only_session_and_persistent_cookies() {
	jar := '# Netscape HTTP Cookie File\n'
		+ '#HttpOnly_.reddit.com\tTRUE\t/\tTRUE\t200\tsession\tsecret\n'
		+ 'old.reddit.com\tFALSE\t/r\tFALSE\t0\tview\tcompact\n'
		+ '.reddit.com\tTRUE\t/\tFALSE\t99\texpired\tno\n'
		+ '.reddit.com\tTRUE\t/\tFALSE\t100\tboundary\tno\n'
		+ '.reddit.com\tTRUE\t/\tFALSE\t0\tempty\t\n'
	assert imported_cookie_header(jar, 'https://old.reddit.com/r/worldnews/',
		'https://old.reddit.com/', 100) == 'view=compact; session=secret; empty='
	assert imported_cookie_header(jar, 'http://old.reddit.com/r/worldnews/',
		'http://old.reddit.com/', 100) == 'view=compact; empty='
	assert imported_cookie_header(jar, 'https://www.reddit.com/r/worldnews/',
		'https://old.reddit.com/', 100) == 'session=secret; empty='
	assert imported_cookie_header(jar, 'https://old.reddit.com/rubbish',
		'https://old.reddit.com/', 100) == 'session=secret; empty='
	assert imported_cookie_header(jar, 'https://old.reddit.com/r',
		'https://old.reddit.com/', 100) == 'view=compact; session=secret; empty='
}

fn test_imported_cookies_do_not_cross_site_scheme_or_domain_boundaries() {
	jar := '.reddit.com\tTRUE\t/\tFALSE\t0\tsession\tsecret\n'
	for address in ['https://notreddit.com/', 'https://reddit.com.evil.test/',
		'https://evilreddit.com/', 'file:///reddit.com/'] {
		assert imported_cookie_header(jar, address, address, 100) == ''
	}
	assert imported_cookie_header(jar, 'https://old.reddit.com/', 'https://evil.test/', 100) == ''
	assert imported_cookie_header(jar, 'https://old.reddit.com/', 'http://old.reddit.com/', 100) == ''
	assert imported_cookie_header(jar, 'https://old.reddit.com/', '', 100) == ''
	assert imported_cookie_header(jar, 'https://old.reddit.com/', 'https://old.reddit.com/', 100) == 'session=secret'
}

fn test_imported_cookie_parser_rejects_malformed_fields_and_header_injection() {
	mut jar := '# ignored\nnot a cookie\n'
	for domain in ['.com', 'reddit.com:443', 'user@reddit.com', 'reddit.com/path',
		'reddit.com?query', 'reddit.com#fragment'] {
		jar += '${domain}\tTRUE\t/\tFALSE\t0\tsession\tbad\n'
	}
	for name in ['bad name', 'bad=name', 'bad;name', 'bad\rname', ''] {
		jar += '.reddit.com\tTRUE\t/\tFALSE\t0\t${name}\tbad\n'
	}
	for value in ['bad;injected=1', 'bad\rX-Header:yes', 'bad value', 'bad\tvalue'] {
		jar += '.reddit.com\tTRUE\t/\tFALSE\t0\tsession\t${value}\n'
	}
	for expiry in ['invalid', '-1', '99999999999999999999999999999'] {
		jar += '.reddit.com\tTRUE\t/\tFALSE\t${expiry}\tsession\tbad\n'
	}
	jar += '.reddit.com\tTRUE\t/\tFALSE\t0\tvalid\ta=b%20c\r\n'
	assert imported_cookie_header(jar, 'https://old.reddit.com/', 'https://old.reddit.com/', 100) == 'valid=a=b%20c'
}

fn with_imported_cookie_file(contents string, check fn ()) {
	previous := os.getenv_opt('VOX_COOKIE_FILE')
	path := os.join_path(os.temp_dir(), 'vox-imported-jar-${os.getpid()}-${time.sys_mono_now()}.txt')
	os.write_file(path, contents) or { panic(err) }
	os.setenv('VOX_COOKIE_FILE', path, true)
	defer {
		if value := previous { os.setenv('VOX_COOKIE_FILE', value, true) }
		else { os.unsetenv('VOX_COOKIE_FILE') }
		os.rm(path) or {}
	}
	check()
}

// Fetch and XMLHttpRequest send the request header of the shared jar. Imported
// sessions must reach them too: old Reddit answers a cookieless
// /api/morechildren POST with a login redirect.
fn test_request_header_merges_session_and_same_site_imported_cookies() {
	with_imported_cookie_file('#HttpOnly_.cookies-merge.test\tTRUE\t/\tTRUE\t0\tsession\timported\n',
		fn () {
		record := url.parse('https://www.cookies-merge.test/') or { panic('url') }
		parsed := httpcookie.parse_cookie(&record, 'stored=jar; Path=/; Secure; SameSite=None') or { panic('cookie') }
		set_cookie(&record, parsed, .http, Context{})
		assert request_header('https://www.cookies-merge.test/api/morechildren',
			'https://www.cookies-merge.test', false, 'POST') == 'stored=jar; session=imported'
		assert request_header('https://other.cookies-merge.test/', 'https://www.cookies-merge.test/',
			false, 'GET') == 'session=imported'
		// Imported cookies have no SameSite attribute: never send them cross-site.
		assert request_header('https://www.cookies-merge.test/api', 'https://elsewhere.test', false,
			'POST') == 'stored=jar'
		assert request_header('https://www.cookies-merge.test/api', 'null', false, 'POST') == 'stored=jar'
		// Document access still sees neither the imported jar nor HttpOnly cookies.
		assert cookie_string(&record, .non_http, Context{}) == 'stored=jar'
	})
}
