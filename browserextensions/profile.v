module browserextensions

import browsersettings
import json2
import os
import platform
import processlock
import url

const max_registry_bytes = 16 * 1024 * 1024

pub fn profile_path() string {
	return os.join_path(os.dir(browsersettings.default_path()), 'extensions.json')
}

pub fn installed(path string) ![]Extension {
	if !os.exists(path) {
		return []Extension{}
	}
	return json2.decode[[]Extension](read_utf8_file(path, max_registry_bytes)!, strict: true)
}

fn save(path string, extensions []Extension) ! {
	source := json2.encode(extensions)
	if source.len > max_registry_bytes {
		return error('The extensions in this profile exceed the storage limit.')
	}
	temporary := '${path}.tmp'
	mut file := os.open_file(temporary, 'w', 0o600)!
	defer { os.rm(temporary) or {} }
	file.write_string(source) or {
		file.close()
		return err
	}
	file.close()
	platform.atomic_replace_file(temporary, path)!
}

pub fn install(path string, directory string) !Extension {
	extension := load_unpacked(directory)!
	guard := processlock.acquire(path)!
	defer { guard.release() }
	mut extensions := installed(path)!
	for index, previous in extensions {
		if previous.id == extension.id {
			reloaded := Extension{ ...extension, enabled: previous.enabled }
			extensions[index] = reloaded
			save(path, extensions)!
			return reloaded
		}
	}
	extensions << extension
	save(path, extensions)!
	return extension
}

pub fn set_enabled(path string, id string, enabled bool) ! {
	guard := processlock.acquire(path)!
	defer { guard.release() }
	mut extensions := installed(path)!
	for index, extension in extensions {
		if extension.id == id {
			extensions[index].enabled = enabled
			save(path, extensions)!
			return
		}
	}
	return error('This extension has already been removed.')
}

pub fn remove(path string, id string) ! {
	guard := processlock.acquire(path)!
	defer { guard.release() }
	mut extensions := installed(path)!
	for index, extension in extensions {
		if extension.id == id {
			extensions.delete(index)
			save(path, extensions)!
			return
		}
	}
}

pub struct Injection {
pub:
	url    string
	text   string
	run_at RunAt
}

pub struct Injections {
pub mut:
	css []Injection
	js  []Injection
}

pub fn injections(path string, page string) !Injections {
	if !page.starts_with('http://') && !page.starts_with('https://') {
		return Injections{}
	}
	extensions := installed(path)!
	if extensions.len == 0 {
		return Injections{}
	}
	address := url.parse(page) or { return Injections{} }
	host := address.host or { return Injections{} }
	hostname := host.serialize()
	pathname := address.serialize_path()
	path_with_query := if query := address.query { pathname + '?' + query } else { pathname }
	full_address := address.serialize(false)
	mut result := Injections{}
	for extension in extensions {
		if !extension.enabled {
			continue
		}
		mut css_files := map[string]bool{}
		mut js_files := map[string]bool{}
		for script in extension.scripts {
			if !any_match(script.matches, address, hostname, path_with_query)
				|| any_match(script.exclude_matches, address, hostname, path_with_query)
				|| (script.include_globs.len > 0 && !script.include_globs.any(matches_glob(it, full_address, true)))
				|| script.exclude_globs.any(matches_glob(it, full_address, true)) {
				continue
			}
			for resource in script.css {
				if resource.path in css_files {
					continue
				}
				css_files[resource.path] = true
				result.css << Injection{ url: extension.resource_url(resource), text: resource.text, run_at: .document_start }
			}
			for resource in script.js {
				key := '${script.run_at}/${resource.path}'
				if key in js_files {
					continue
				}
				js_files[key] = true
				result.js << Injection{ url: extension.resource_url(resource), text: resource.text, run_at: script.run_at }
			}
		}
	}
	return result
}

fn any_match(patterns []string, address &url.URL, host string, path string) bool {
	for source in patterns {
		pattern := parse_match_pattern(source) or { continue }
		if pattern.matches(address, host, path) {
			return true
		}
	}
	return false
}
