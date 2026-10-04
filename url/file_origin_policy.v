// SPDX-License-Identifier: BSD-2-Clause

// LibURL/URL.cpp:22,335–345: the process-wide file-origin policy.
module url

__global s_file_scheme_urls_have_tuple_origins = false

pub fn set_file_scheme_urls_have_tuple_origins() {
	// Source VERIFY is fatal in every build mode, including production.
	if s_file_scheme_urls_have_tuple_origins {
		panic('File scheme tuple origins have already been enabled')
	}
	s_file_scheme_urls_have_tuple_origins = true
}

pub fn file_scheme_urls_have_tuple_origins() bool {
	return s_file_scheme_urls_have_tuple_origins
}
