// SPDX-License-Identifier: BSD-2-Clause

module fetch

import cachepolicy
import http

fn cache_policy_headers(headers &http.HeaderList) []cachepolicy.Header {
	return headers.headers().map(cachepolicy.Header{ name: it.name, value: it.value })
}

// Both the native disk adapter and translated memory cache describe the same
// Fetch request to the shared policy. Do not rely on enum representation casts.
pub fn (request &Request) cache_policy_request() cachepolicy.Request {
	return cachepolicy.Request{
		method:  request.method
		mode:    match request.cache_mode {
			.default { cachepolicy.Mode.default }
			.no_store { .no_store }
			.reload { .reload }
			.no_cache { .no_cache }
			.force_cache { .force_cache }
			.only_if_cached { .only_if_cached }
		}
		headers: cache_policy_headers(request.header_list)
	}
}

fn cached_response_header_list(headers &http.HeaderList, decision cachepolicy.Decision) &http.HeaderList {
	mut result := http.HeaderList.create()
	for header in headers.headers() {
		if header.name.to_lower() != 'age' && !http.is_header_exempted_from_cache_storage(header.name) {
			result.append(header)
		}
	}
	result.append(http.Header{ name: 'Age', value: decision.age_header_value() })
	return result
}
