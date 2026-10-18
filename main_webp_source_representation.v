module main

import dom

fn chromium_webp_has_atomic_source(image_url string) bool {
	// Network requests already publish an RGBA frame through the native image
	// request bridge. Keep that representation at paint, as Blink retains RGB
	// once an incremental decoding generator has been created. Atomic sources
	// can advertise planar decoding before that first RGBA decode.
	scheme := dom.URL{
		value: image_url
	}.scheme()
	return scheme != 'http' && scheme != 'https'
}
