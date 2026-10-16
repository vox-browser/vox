module browsernet

import net.http

pub fn request_accept_header(request_type string) string {
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
	headers.add(.accept, request_accept_header(request_type))
	return headers
}
