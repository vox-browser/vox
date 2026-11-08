module main

import dom
import os
import time

// The FFmpeg playback adapter currently has a video sink. Reject declared
// audio codecs rather than selecting a resource whose audio cannot be played.
fn browser_webm_video_codecs_supported(type_ string) bool {
	for parameter in type_.split(';')[1..] {
		if parameter.all_before('=').trim_space().to_lower() != 'codecs' { continue }
		codecs := parameter.all_after('=').trim_space().trim('"').to_lower().split(',')
		for codec in codecs {
			name := codec.trim_space()
			if name !in ['vp8', 'vp8.0', 'vp9', 'vp9.0'] && !name.starts_with('vp09.') {
				return false
			}
		}
	}
	return true
}

fn browser_media_source_is_webm(source dom.URL, element &dom.Element) bool {
	if source.serialize().all_before('#').all_before('?').to_lower().ends_with('.webm') {
		return true
	}
	parent := unsafe { &dom.ParentNode(element) }
	children := parent.query_selector_all('source') or { return false }
	for index in 0 .. children.length() {
		node := children.item(index) or { continue }
		child := node.as_element() or { continue }
		address := child.get_attribute('src') or { continue }
		resolved := dom.dom_url_parse(address, element.document().base_url(), 'UTF-8') or { continue }
		if resolved.serialize() == source.serialize() {
			type_ := child.get_attribute('type') or { '' }
			return type_.all_before(';').trim_space().to_lower() == 'video/webm'
		}
	}
	return false
}

fn browser_open_webm_resource(source dom.URL, document_url string) !voidptr {
	bytes := browser_resource_bytes_for_document(source, document_url, 'media')!
	directory := os.join_path(os.temp_dir(), 'vox-webm-${os.getpid()}-${time.sys_mono_now()}')
	os.mkdir(directory)!
	defer { os.rmdir_all(directory) or {} }
	path := os.join_path(directory, 'resource.webm')
	os.write_file_array(path, bytes)!
	// FFmpeg holds the opened file descriptor, including across seeks. Unlink
	// the temporary file now; closing the decoder releases its final ownership.
	return C.native_media_open_webm(path.str)
}
