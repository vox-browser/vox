module main

fn decode_cached_headers_concurrently(start chan bool, results chan bool) {
	_ := <-start
	for _ in 0 .. 64 {
		headers := decode_browser_cached_response_headers('[{"name":"vary","value":"Accept"},{"name":"set-cookie","value":"a=1"},{"name":"set-cookie","value":"b=2"},{"name":"x-escaped","value":"quote\\\" tab\\t"}]') or { results <- false; return }
		if headers.len != 4 || headers[0].name != 'vary' || headers[0].value != 'Accept'
			|| headers[1].value != 'a=1' || headers[2].value != 'b=2'
			|| headers[3].value != 'quote" tab\t' {
			results <- false
			return
		}
	}
	results <- true
}

fn test_concurrent_first_cache_header_reads_preserve_order_duplicates_and_escaping() {
	start := chan bool{cap: 32}
	results := chan bool{cap: 32}
	for _ in 0 .. 32 { spawn decode_cached_headers_concurrently(start, results) }
	for _ in 0 .. 32 { start <- true }
	for _ in 0 .. 32 { assert <-results }
}

fn test_invalid_cached_header_metadata_is_a_cache_miss_instead_of_a_panic() {
	assert decode_browser_cached_response_headers('[]')!.len == 0
	if _ := decode_browser_cached_response_headers('[{"name":') { assert false }
}
