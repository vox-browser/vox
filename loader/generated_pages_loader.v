// Copyright (c) 2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause

// Translation of Loader/GeneratedPagesLoader.{h,cpp}.
module loader

import dom
import os
import url as liburl

const error_page_template = '<!doctype html><title>Load error</title><h1>Failed to load %failed_url%</h1><pre>%error_message%</pre>'
const directory_page_template = '<!doctype html><title>Index of %path%</title><a href="%parent_url%">Parent directory</a>%contents%'

fn escape_html_entities(value string) string {
	return value.replace('&', '&amp;').replace('<', '&lt;').replace('>', '&gt;').replace('"',
		'&quot;').replace("'", '&#39;')
}

fn substitute(template string, values map[string]string) string {
	mut result := template
	for key, value in values {
		result = result.replace('%${key}%', value)
	}
	return result
}

pub fn load_error_page(url dom.URL, error_message string) string {
	return substitute(error_page_template, {
		'failed_url':    escape_html_entities(url.to_string())
		'error_message': escape_html_entities(error_message)
	})
}

fn human_readable_size(size u64) string {
	if size < 1024 {
		return '${size} B'
	}
	if size < 1024 * 1024 {
		return '${f64(size) / 1024.0:.1f} KiB'
	}
	if size < 1024 * 1024 * 1024 {
		return '${f64(size) / f64(1024 * 1024):.1f} MiB'
	}
	return '${f64(size) / f64(1024 * 1024 * 1024):.1f} GiB'
}

fn file_path_from_url(url dom.URL) !string {
	parsed := liburl.parse(url.serialize()) or { return error('Malformed file URL') }
	return parsed.to_file_path() or { return error('Invalid local file URL') }
}

pub fn load_file_directory_page(url dom.URL) !string {
	path := file_path_from_url(url)!
	mut names := os.ls(path)!
	names.sort()
	mut contents := '<table>'
	for name in names {
		entry_path := os.join_path(path, name)
		metadata := os.stat(entry_path) or { continue }
		is_directory := os.is_dir(entry_path)
		kind := if is_directory { 'folder' } else { 'file' }
		size := if is_directory { '-' } else { human_readable_size(metadata.size) }
		href := 'file://${escape_html_entities(entry_path)}'
		contents += '<tr><td><span class="${kind}"></span></td><td><a href="${href}">${escape_html_entities(name)}</a></td><td>&nbsp;</td><td>${size:10}</td><td>&nbsp;</td><td>${metadata.mtime}</td></tr>\n'
	}
	contents += '</table>'
	parent := os.dir(path)
	return substitute(directory_page_template, {
		'path':       escape_html_entities(path)
		'parent_url': 'file://${escape_html_entities(parent)}'
		'contents':   contents
	})
}
