// The embedding browser owns persistent responses; Fetch retains policy and
// task delivery. This is a cache lookup boundary, not a second network client.
@[has_globals]
module requestserver

import fetch

pub type NativeResponseCacheProvider = fn (&fetch.Request) ?&fetch.Response

__global native_response_cache_provider_ ?NativeResponseCacheProvider

pub fn install_native_response_cache_provider(provider ?NativeResponseCacheProvider) {
	native_response_cache_provider_ = provider
}
