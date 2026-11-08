module browsernet

import net.http
import browsercookies

pub fn request_accept_header(request_type string) string {
	if request_type in ['main_frame', 'sub_frame'] {
		$if macos {
			// Advertise the native image formats on navigations too. Servers can
			// choose image URLs while generating the HTML response (e.g. Pikabu).
			return 'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,image/apng,*/*;q=0.8'
		}
		// Fetch/Fetching/Fetching.h::document_accept_header_value otherwise.
		return 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8'
	}
	if request_type == 'image' {
		$if macos {
			// The native image path decodes WebP through AppKit.
			return 'image/webp,image/apng,image/svg+xml,image/*,*/*;q=0.8'
		}
		return 'image/apng,image/svg+xml,image/*,*/*;q=0.8'
	}
	return '*/*'
}

fn resource_request_headers(resource_url string, source_url string, request_type string) http.Header {
	mut headers := http.new_header()
	cookie := browsercookies.request_header(resource_url, source_url, request_type == 'main_frame', 'GET')
	if cookie != '' { headers.add(.cookie, cookie) }
	headers.add(.accept, request_accept_header(request_type))
	// The staged net.http uses vlib's pure V Brotli decoder on both HTTP/1
	// and HTTP/2. These codings need no installed native codec libraries.
	headers.add(.accept_encoding, 'gzip, deflate, br')
	return headers
}
