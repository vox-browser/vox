module main

import browsernet
import dom
import net.urllib
import os
import platform
import time

struct BrowserMediaLocalResource {
	directory string
	url       string
}

fn browser_media_requires_browser_transport(source dom.URL) bool {
	return source.scheme() in ['http', 'https'] && browsernet.has_proxy_policy()
}

// AVFoundation's URL loader does not consult the browser's proxy settings.
// Fetch proxied progressive resources through the ordinary browser transport,
// then retain their local file until the asynchronous native player closes.
fn browser_stage_native_media_resource(source dom.URL, document_url string) !BrowserMediaLocalResource {
	mut scratch := platform.begin_thread_scratch('Proxied native media response')
	defer { scratch.finish() }
	return browser_stage_native_media_response(source, document_url) or {
		// Failure callbacks inspect this interface after the response workspace
		// has retired, just as playback retains the successful local URL.
		persistent := platform.enter_persistent()
		defer { platform.leave_persistent(persistent) }
		return error_with_code(err.msg().clone(), err.code())
	}
}

fn browser_stage_native_media_response(source dom.URL, document_url string) !BrowserMediaLocalResource {
	response := fetch_browser_resource(source.serialize(), '', document_url, 'media')!
	mime := browser_response_mime_essence(response.response_headers)
	if mime in ['application/vnd.apple.mpegurl', 'application/x-mpegurl', 'audio/mpegurl',
		'audio/x-mpegurl']
		|| response.body.trim_space().starts_with('#EXTM3U') {
		return error('Proxied media playlists require a streaming resource loader')
	}
	if response.body.len == 0 { return error('Empty media response') }
	mut extension := match mime {
		'video/mp4', 'audio/mp4' { '.mp4' }
		'video/quicktime' { '.mov' }
		'audio/x-m4a' { '.m4a' }
		'audio/aac' { '.aac' }
		'audio/mpeg', 'audio/mp3' { '.mp3' }
		'audio/wav', 'audio/x-wav' { '.wav' }
		'audio/flac' { '.flac' }
		else { os.file_ext(response.final_url.all_before('#').all_before('?')) }
	}
	if extension.len > 16 || extension.bytes().any(it != `.` && !it.is_alnum()) {
		extension = ''
	}
	directory := os.join_path(os.temp_dir(), 'vox-media-${os.getpid()}-${time.sys_mono_now()}')
	os.mkdir(directory)!
	mut retained := false
	defer { if !retained { os.rmdir_all(directory) or {} } }
	path := os.join_path(directory, 'resource${extension}')
	os.write_file_array(path, response.body.bytes())!
	local_url := urllib.URL{ scheme: 'file', path: path }.str()
	persistent := platform.enter_persistent()
	defer { platform.leave_persistent(persistent) }
	result := BrowserMediaLocalResource{ directory: directory.clone(), url: local_url.clone() }
	retained = true
	return result
}
