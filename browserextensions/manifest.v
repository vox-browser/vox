module browserextensions

import crypto.sha256
import encoding.utf8
import json2
import os
import url

pub enum RunAt {
	document_start
	document_end
	document_idle
}

pub struct Resource {
pub:
	path string
	text string
}

pub struct ContentScript {
pub:
	run_at          RunAt = .document_idle
	css             []Resource
	js              []Resource
	matches         []string
	exclude_matches []string
	include_globs   []string
	exclude_globs   []string
}

pub struct Extension {
pub:
	id      string
	root    string
	name    string
	version string
	scripts []ContentScript
pub mut:
	enabled bool = true
}

struct Manifest {
	name             string
	version          string
	manifest_version int
	content_scripts  []ManifestScript
}

struct ManifestScript {
	matches                  []string
	exclude_matches          []string
	include_globs            []string
	exclude_globs            []string
	css                      []string
	js                       []string
	run_at                   string = 'document_idle'
	world                    string = 'ISOLATED'
	all_frames               bool
	match_about_blank        bool
	match_origin_as_fallback bool
}

const max_manifest_bytes = 256 * 1024
const max_extension_source_bytes = 2 * 1024 * 1024

fn read_utf8_file(path string, limit int) !string {
	info := os.stat(path)!
	if info.get_filetype() != .regular || info.size > u64(limit) {
		return error('Expected a regular file within the size limit at ${path}.')
	}
	mut file := os.open(path)!
	defer { file.close() }
	source := file.read_bytes(int(info.size) + 1).bytestr()
	if source.len > int(info.size) || source.contains_u8(0) || !utf8.validate_str(source) {
		return error('Expected UTF-8 text within the size limit at ${path}.')
	}
	return source.trim_string_left('\xef\xbb\xbf')
}

fn extension_root_file(root string, path string, limit int) !string {
	if path == '' || path.contains_any('\\:') || path.contains_u8(0)
		|| path.split('/').any(it in ['', '.', '..'] || it.trim_right(' .') != it) {
		return error('Invalid extension file path "${path}".')
	}
	canonical := os.real_path(os.join_path(root, path))
	if !canonical.starts_with(root.trim_right(os.path_separator) + os.path_separator) {
		return error('Extension file "${path}" is outside its folder.')
	}
	return read_utf8_file(canonical, limit) or {
		return error('Cannot read extension file "${path}". ${err.msg()}')
	}
}

fn load_resources(root string, files []string, limit int) !([]Resource, int) {
	mut remaining := limit
	mut resources := []Resource{cap: files.len}
	for file in files {
		path := file.trim_left('/')
		text := extension_root_file(root, path, remaining)!
		remaining -= text.len
		resources << Resource{ path: path, text: text }
	}
	return resources, remaining
}

fn load_unpacked(directory string) !Extension {
	if directory == '' || !os.is_dir(directory) {
		return error('Choose the folder containing manifest.json.')
	}
	root := os.real_path(directory)
	source := extension_root_file(root, 'manifest.json', max_manifest_bytes)!
	manifest := json2.decode[Manifest](source, strict: true) or {
		return error('Invalid manifest.json. ${err.msg()}')
	}
	if manifest.manifest_version != 3 {
		return error('Vox supports Manifest V3 extensions.')
	}
	if manifest.name.trim_space() == '' || manifest.version.trim_space() == '' {
		return error('manifest.json needs a name and version.')
	}
	fields := json2.decode[map[string]json2.Any](source)!
	for key in ['background', 'action', 'options_page', 'options_ui', 'devtools_page', 'side_panel',
		'chrome_url_overrides', 'chrome_settings_overrides', 'declarative_net_request',
		'web_accessible_resources', 'externally_connectable', 'content_security_policy', 'sandbox',
		'managed_storage', 'oauth2', 'permissions', 'optional_permissions', 'host_permissions',
		'optional_host_permissions'] {
		if field := fields[key] {
			if field is []json2.Any && field.len == 0 {
				continue
			}
			return error('Vox does not support the manifest field "${key}".')
		}
	}
	if manifest.content_scripts.len == 0 {
		return error('manifest.json needs at least one declarative content script.')
	}
	mut scripts := []ContentScript{cap: manifest.content_scripts.len}
	mut remaining := max_extension_source_bytes
	for script in manifest.content_scripts {
		if script.all_frames || script.match_about_blank || script.match_origin_as_fallback {
			return error('Vox supports declarative content scripts in the top-level document.')
		}
		if script.matches.len == 0 || (script.css.len == 0 && script.js.len == 0) {
			return error('Each content script needs matches and at least one CSS or JavaScript file.')
		}
		if script.world !in ['MAIN', 'ISOLATED'] || (script.js.len > 0 && script.world != 'MAIN') {
			return error('JavaScript content scripts must explicitly declare "world": "MAIN". Vox does not have isolated extension worlds.')
		}
		run_at := match script.run_at {
			'document_start' { RunAt.document_start }
			'document_end' { RunAt.document_end }
			'document_idle' { RunAt.document_idle }
			else { return error('Unknown run_at value "${script.run_at}".') }
		}
		for pattern in script.matches {
			parse_match_pattern(pattern)!
		}
		for pattern in script.exclude_matches {
			parse_match_pattern(pattern)!
		}
		css, remaining_after_css := load_resources(root, script.css, remaining)!
		js, remaining_after_js := load_resources(root, script.js, remaining_after_css)!
		remaining = remaining_after_js
		scripts << ContentScript{
			run_at:          run_at
			css:             css
			js:              js
			matches:         script.matches
			exclude_matches: script.exclude_matches
			include_globs:   script.include_globs
			exclude_globs:   script.exclude_globs
		}
	}
	return Extension{
		id:      sha256.hexhash(root)
		root:    root
		name:    manifest.name
		version: manifest.version
		scripts: scripts
	}
}

pub fn (extension Extension) resource_url(resource Resource) string {
	path := resource.path.split('/').map(url.percent_encode(it, .component, false)).join('/')
	return 'chrome-extension://${extension.id}/${path}'
}
