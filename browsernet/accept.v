module browsernet

import net.http
import browsercookies

pub fn request_accept_header(request_type string) string {
	if request_type in ['main_frame', 'sub_frame'] {
		// Fetch/Fetching/Fetching.h::document_accept_header_value.
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
	mut headers := imported_cookie_headers(resource_url, source_url)
	cookie := browsercookies.request_header(resource_url, source_url, request_type == 'main_frame', 'GET')
	if cookie != '' {
		imported := headers.get(.cookie) or { '' }
		headers.set(.cookie, if imported == '' { cookie } else { cookie + '; ' + imported })
	}
	headers.add(.accept, request_accept_header(request_type))
	// net.http decodes these content codings on both its HTTP/1 and HTTP/2
	// paths. Without negotiation, scripts and HTML arrive uncompressed.
	headers.add(.accept_encoding, 'gzip, deflate, br')
	return headers
}
