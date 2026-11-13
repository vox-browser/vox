module browsercookies

import httpcookie
import os
import platform
import time
import url

fn cookie_profile_directory() string {
	directory := os.join_path(os.temp_dir(), 'vox-cookie-profile-${os.getpid()}-${time.sys_mono_now()}')
	os.mkdir_all(directory) or { panic(err) }
	return directory
}

fn profile_read(mut jar Jar, address string, source httpcookie.Source, context Context) string {
 record := url.parse(address) or { panic('invalid test URL') }
 return jar.cookie_string_at(&record, source, context, 1000)
}

fn profile_put(mut jar Jar, name string, value string, expires ?i64) {
	record := url.parse('https://www.google.com/search') or { panic('invalid test URL') }
	jar.set_cookie_at(&record, httpcookie.ParsedCookie{
		name: name
		value: value
		domain: 'google.com'
		path: '/'
		secure_attribute_present: true
		http_only_attribute_present: true
		same_site_attribute: .lax
		expiry_time_from_expires_attribute: expires
	}, .http, Context{}, 1000)
}

fn test_persistent_verification_survives_a_new_jar_without_persisting_session_cookies() {
	directory := cookie_profile_directory()
	defer { os.rmdir_all(directory) or {} }
	path := os.join_path(directory, 'cookies.json')
	mut first := &Jar{path: path}
	profile_put(mut first, 'verification', 'saved', i64(2000))
	profile_put(mut first, 'session', 'temporary', none)
	assert profile_read(mut first, 'https://www.google.com/', .http, Context{}) == 'verification=saved; session=temporary'
	mut reopened := &Jar{path: path}
	assert profile_read(mut reopened, 'https://www.google.com/', .http, Context{}) == 'verification=saved'
	assert profile_read(mut reopened, 'https://www.google.com/', .non_http, Context{}) == ''
	assert profile_read(mut reopened, 'http://www.google.com/', .http, Context{}) == ''
	assert profile_read(mut reopened, 'https://notgoogle.com/', .http, Context{}) == ''
	assert profile_read(mut reopened, 'https://www.google.com/', .http, Context{same_site: false}) == ''
	assert !os.read_file(path)!.contains('temporary')
	$if !windows { assert os.stat(path)!.mode & 0o777 == 0o600 }
}

fn test_sibling_jars_merge_updates_and_observe_replacements_and_deletions() {
	directory := cookie_profile_directory()
	defer { os.rmdir_all(directory) or {} }
	path := os.join_path(directory, 'cookies.json')
	mut first := &Jar{path: path}
	mut sibling := &Jar{path: path}
	profile_put(mut first, 'a', 'first', i64(2000))
	assert profile_read(mut sibling, 'https://www.google.com/', .http, Context{}) == 'a=first'
	profile_put(mut sibling, 'b', 'second', i64(2000))
	profile_put(mut first, 'a', 'replacement', i64(2000))
	assert profile_read(mut sibling, 'https://www.google.com/', .http, Context{}) == 'a=replacement; b=second'
	profile_put(mut sibling, 'a', '', i64(1000))
	assert profile_read(mut first, 'https://www.google.com/', .http, Context{}) == 'b=second'
	// Removing a profile also invalidates the cached persistent snapshot.
	os.rm(path)!
	assert profile_read(mut first, 'https://www.google.com/', .http, Context{}) == ''
}

fn test_expired_profile_cookies_are_not_restored_and_profiles_are_isolated() {
	directory := cookie_profile_directory()
	defer { os.rmdir_all(directory) or {} }
	path := os.join_path(directory, 'cookies.json')
	mut first := &Jar{path: path}
	profile_put(mut first, 'verification', 'saved', i64(2000))
	mut reopened := &Jar{path: path}
	record := url.parse('https://www.google.com/') or { panic('invalid test URL') }
	assert reopened.cookie_string_at(&record, .http, Context{}, 2000) == ''
	mut private_profile := &Jar{path: os.join_path(directory, 'private.json')}
	assert profile_read(mut private_profile, record.serialize(false), .http, Context{}) == ''
}

fn test_corrupt_profile_is_not_overwritten_by_a_stale_writer() {
	directory := cookie_profile_directory()
	defer { os.rmdir_all(directory) or {} }
	path := os.join_path(directory, 'cookies.json')
	mut first := &Jar{path: path}
	profile_put(mut first, 'verification', 'saved', i64(2000))
	temporary := '${path}.replacement'
	os.write_file(temporary, '{invalid')!
	os.rename_dir(temporary, path)!
	profile_put(mut first, 'b', 'second', i64(2000))
	assert os.read_file(path)! == '{invalid'
}

fn profile_update_worker(path string, name string) {
	mut jar := &Jar{path: path}
	for i in 0 .. 8 {
		profile_put(mut jar, '${name}${i}', 'saved', i64(2000))
	}
}

fn test_concurrent_tab_writers_do_not_lose_cookies() {
	directory := cookie_profile_directory()
	defer { os.rmdir_all(directory) or {} }
	path := os.join_path(directory, 'cookies.json')
	first := spawn profile_update_worker(path, 'a')
	second := spawn profile_update_worker(path, 'b')
	first.wait()
	second.wait()
	mut reopened := &Jar{path: path}
	header := profile_read(mut reopened, 'https://www.google.com/', .http, Context{})
	assert header.split('; ').len == 16
	for i in 0 .. 8 {
		assert 'a${i}=saved' in header.split('; ')
		assert 'b${i}=saved' in header.split('; ')
	}
}

fn test_profile_refresh_retains_cookies_outside_document_scratch() {
	directory := cookie_profile_directory()
	defer { os.rmdir_all(directory) or {} }
	path := os.join_path(directory, 'cookies.json')
	mut first := &Jar{path: path}
	profile_put(mut first, 'verification', 'saved', i64(2000))
	mut reopened := &Jar{path: path}
	mut scratch := platform.begin_thread_scratch('cookie profile refresh')
	assert profile_read(mut reopened, 'https://www.google.com/', .http, Context{}) == 'verification=saved'
	scratch.finish()
	assert profile_read(mut reopened, 'https://www.google.com/', .http, Context{}) == 'verification=saved'
}

fn test_browser_cookie_api_uses_the_initialized_profile() {
	directory := cookie_profile_directory()
	defer {
		initialize('') or { panic(err) }
		os.rmdir_all(directory) or {}
	}
	path := os.join_path(directory, 'cookies.json')
	initialize(path)!
	store_response_cookies('https://www.google.com/search', 'https://www.google.com/',
		true, 'GET', ['verification=saved; Domain=google.com; Path=/; Max-Age=600; Secure; HttpOnly'])
	initialize(path)!
	assert request_header('https://www.google.com/search?q=next', 'https://www.google.com/', true, 'GET') == 'verification=saved'
}
