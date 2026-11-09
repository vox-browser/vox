module main

import adblock
import browsernet

fn resource_response_varies_on_accept(headers []adblock.ResponseHeader) bool {
	for header in headers {
		if header.name.to_lower() != 'vary' { continue }
		for name in header.value.split(',') {
			if name.trim_space().to_lower() == 'accept' { return true }
		}
	}
	return false
}

fn resource_accept_cache_key(address string, request_type string) string {
	return resource_accept_cache_key_for_header(address, browsernet.request_accept_header(request_type))
}

fn resource_accept_cache_key_for_header(address string, accept string) string {
	return address + '\nAccept: ' + accept
}
