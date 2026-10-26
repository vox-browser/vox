module browsersettings

import math
import os
import platform
import time

fn test_zoom_domains_use_canonical_hosts_without_sharing_subdomains() {
	mut store := open_zoom_levels('')!
	store.set_for_url('https://user:pass@EXAMPLE.com.:8443/path?q=1#part', 1.25)!
	assert store.for_url('http://example.com/other') == 1.25
	assert store.for_url('https://example.com:9443/') == 1.25
	for address in ['https://sub.example.com/', 'https://notexample.com/',
		'https://example.com.evil.test/', 'https://example.com@other.test/'] {
		assert store.for_url(address) == 1, address
	}
	store.set_for_url('https://bücher.de/', 1.5)!
	assert store.for_url('http://xn--bcher-kva.de/') == 1.5
	store.set_for_url('http://0x7f.1/', 0.9)!
	assert store.for_url('https://127.0.0.1:8080/') == 0.9
	store.set_for_url('https://[2001:0db8::1]:8443/', 2)!
	assert store.for_url('http://[2001:db8:0:0:0:0:0:1]/') == 2
	for address in ['', 'invalid', 'about:blank', 'vox://newtab', 'file:///tmp/page.html',
		'data:text/html,example.com', 'javascript:alert(1)'] {
		store.set_for_url(address, 2)!
		assert store.for_url(address) == 1, address
	}
}

fn test_zoom_levels_persist_independently_and_reset_removes_preference() {
	directory := os.join_path(os.temp_dir(), 'vox-zoom-${os.getpid()}-${time.sys_mono_now()}')
	defer { os.rmdir_all(directory) or {} }
	path := os.join_path(directory, 'zoom.json')
	mut store := open_zoom_levels(path)!
	store.set_for_url('https://first.test/', 1.25)!
	store.set_for_url('https://second.test/', 0.8)!
	mut reloaded := open_zoom_levels(path)!
	assert reloaded.for_url('http://first.test/new-path') == 1.25
	assert reloaded.for_url('https://second.test/') == 0.8
	assert reloaded.for_url('https://unvisited.test/') == 1
	reloaded.set_for_url('http://first.test/', 1)!
	assert !os.read_file(path)!.contains('first.test')
	assert open_zoom_levels(path)!.for_url('https://first.test/') == 1
	assert open_zoom_levels(path)!.for_url('https://second.test/') == 0.8
	assert os.ls(directory)!.len == 2
	assert (os.stat(path)!.mode & 0o777) == 0o600
}

fn test_invalid_zoom_levels_do_not_replace_saved_preferences() {
	mut store := open_zoom_levels('')!
	store.set_for_url('https://example.test/', 1.5)!
	for level in [f64(0), 0.24, 5.01, math.inf(1), math.nan()] {
		if _ := store.set_for_url('https://example.test/', level) { assert false }
		assert store.for_url('https://example.test/') == 1.5
	}
	store.set_for_url('https://example.test/', 0.25)!
	store.set_for_url('https://other.test/', 5)!
	assert store.for_url('https://example.test/') == 0.25
	assert store.for_url('https://other.test/') == 5
}

fn test_zoom_save_failure_keeps_existing_file_and_preference() {
	directory := os.join_path(os.temp_dir(), 'vox-zoom-failure-${os.getpid()}-${time.sys_mono_now()}')
	os.mkdir_all(directory)!
	defer { os.rmdir_all(directory) or {} }
	path := os.join_path(directory, 'zoom.json')
	mut store := open_zoom_levels(path)!
	store.set_for_url('https://example.test/', 1.25)!
	before := os.read_file(path)!
	store.path = os.join_path(directory, 'not-a-file')
	os.mkdir(store.path)!
	if _ := store.set_for_url('https://example.test/', 2) { assert false }
	assert store.for_url('https://example.test/') == 1.25
	assert os.read_file(path)! == before
	assert os.ls(directory)!.len == 4
}

fn test_zoom_profile_filters_invalid_entries_and_preserves_corrupt_json() {
	directory := os.join_path(os.temp_dir(), 'vox-zoom-invalid-${os.getpid()}-${time.sys_mono_now()}')
	os.mkdir_all(directory)!
	defer { os.rmdir_all(directory) or {} }
	path := os.join_path(directory, 'zoom.json')
	os.write_file(path, '{"levels":{"good.test":1.5,"small.test":0.1,"large.test":6,"normal.test":1,"BAD.test":2,"bad.test/path":2,"":2}}')!
	store := open_zoom_levels(path)!
	assert store.levels.len == 1
	assert store.for_url('https://good.test/') == 1.5
	os.write_file(path, '{broken')!
	if _ := open_zoom_levels(path) { assert false }
	assert os.read_file(path)! == '{broken'
}

fn test_zoom_preferences_outlive_document_scratch_allocations() {
	mut store := open_zoom_levels('')!
	for index in 0 .. 4 {
		mut scratch := platform.begin_thread_scratch('zoom test document')
		store.set_for_url('https://site${index}.test/path', 1.25 + f64(index) / 4)!
		scratch.finish()
	}
	for index in 0 .. 4 {
		assert store.for_url('https://site${index}.test/other') == 1.25 + f64(index) / 4
	}
}
