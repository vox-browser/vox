module browserextensions

import os
import rand

fn extension_fixture() !string {
	path := os.join_path(os.temp_dir(), 'vox-extensions-' + rand.ulid())
	os.mkdir(path)!
	return path
}

fn test_profile_installs_updates_disables_and_removes_unpacked_extension() {
	root := extension_fixture() or { panic(err) }
	defer { os.rmdir_all(root) or {} }
	directory := os.join_path(root, 'extension')
	os.mkdir(directory) or { panic(err) }
	profile := os.join_path(root, 'profile', 'extensions.json')
	manifest := '{"manifest_version":3,"name":"Display","version":"1.0","content_scripts":[{"matches":["https://*.example.com:443/news*"],"exclude_matches":["https://*.example.com/news/archive*"],"include_globs":["*edition=?*"],"exclude_globs":["*#private"],"css":["page.css"],"js":["one.js","two.js"],"world":"MAIN","run_at":"document_end"}]}'
	os.write_file(os.join_path(directory, 'manifest.json'), manifest) or { panic(err) }
	os.write_file(os.join_path(directory, 'page.css'), 'p { color: green }') or { panic(err) }
	os.write_file(os.join_path(directory, 'one.js'), 'var flag = true;') or { panic(err) }
	os.write_file(os.join_path(directory, 'two.js'), 'globalThis.flag = false;') or { panic(err) }

	extension := install(profile, directory) or { panic(err) }
	assert extension.enabled
	assert (installed(profile) or { panic(err) }).len == 1
	page := 'https://sub.example.com/news?edition=1'
	matched := injections(profile, page) or { panic(err) }
	assert matched.css.len == 1
	assert matched.css[0].run_at == .document_start
	assert matched.js.map(it.text) == ['var flag = true;', 'globalThis.flag = false;']
	assert matched.js[0].run_at == .document_end
	assert matched.js[0].url.ends_with('/one.js')
	for blocked in ['http://sub.example.com/news?edition=1', 'https://notexample.com/news?edition=1',
		'https://example.com:444/news?edition=1', 'https://example.com/news/archive?edition=1',
		'https://example.com/news#edition=', 'https://example.com/news?edition=1#private',
		'file:///example.com/news?edition=1', 'about:blank'] {
		assert (injections(profile, blocked) or { panic(err) }).js.len == 0, blocked
	}

	set_enabled(profile, extension.id, false) or { panic(err) }
	os.write_file(os.join_path(directory, 'one.js'), 'var flag = "updated";') or { panic(err) }
	assert (injections(profile, page) or { panic(err) }).css.len == 0
	reloaded := install(profile, directory) or { panic(err) }
	assert reloaded.id == extension.id
	assert !reloaded.enabled
	set_enabled(profile, extension.id, true) or { panic(err) }
	assert (injections(profile, page) or { panic(err) }).js[0].text == 'var flag = "updated";'
	os.write_file(os.join_path(directory, 'one.js'), 'throw new Error("not installed");') or { panic(err) }
	assert (injections(profile, page) or { panic(err) }).js[0].text == 'var flag = "updated";'
	remove(profile, extension.id) or { panic(err) }
	assert (installed(profile) or { panic(err) }).len == 0
}

fn test_manifest_rejects_unsupported_features_and_escaping_files() {
	root := extension_fixture() or { panic(err) }
	defer { os.rmdir_all(root) or {} }
	directory := os.join_path(root, 'extension')
	os.mkdir(directory) or { panic(err) }
	manifest := os.join_path(directory, 'manifest.json')
	external := os.join_path(root, 'outside.css')
	os.write_file(external, 'p {}') or { panic(err) }
	for script in [
		'{"matches":["<all_urls>"],"js":["main.js"]}',
		'{"matches":["<all_urls>"],"css":["../outside.css"]}',
		'{"matches":["file:///*"],"css":["local.css"]}',
		'{"matches":["<all_urls>"],"css":["local.css"],"all_frames":true}',
		'{"matches":"<all_urls>","css":["local.css"]}',
		'{"matches":["<all_urls>"],"css":["local.css"],"run_at":"never"}',
	] {
		os.write_file(manifest, '{"manifest_version":3,"name":"Invalid","version":"1","content_scripts":[${script}]}') or { panic(err) }
		if _ := load_unpacked(directory) {
			assert false, script
		}
	}
	$if !windows {
		os.symlink(external, os.join_path(directory, 'local.css')) or { panic(err) }
		os.write_file(manifest, '{"manifest_version":3,"name":"Invalid","version":"1","content_scripts":[{"matches":["<all_urls>"],"css":["local.css"]}]}') or { panic(err) }
		if _ := load_unpacked(directory) {
			assert false, 'symlink outside extension directory'
		}
	}
}

fn test_css_only_extensions_use_the_default_world_without_running_javascript() {
	root := extension_fixture() or { panic(err) }
	defer { os.rmdir_all(root) or {} }
	os.write_file(os.join_path(root, 'manifest.json'), '{"manifest_version":3,"name":"CSS","version":"1","content_scripts":[{"matches":["<all_urls>"],"css":["style.css"]}]}') or { panic(err) }
	os.write_file(os.join_path(root, 'style.css'), 'p {}') or { panic(err) }
	profile := os.join_path(root, 'extensions.json')
	install(profile, root) or { panic(err) }
	result := injections(profile, 'http://127.0.0.1:8000/') or { panic(err) }
	assert result.css.len == 1
	assert result.js.len == 0
}
