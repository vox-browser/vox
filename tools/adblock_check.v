module main

import adblock
import json
import os

struct Corpus {
	requests []CorpusCase
}

struct CorpusCase {
	url          string
	source_url   string
	request_type string
	method       string = 'GET'
	phase        string = 'request'
	response_headers []adblock.ResponseHeader
	request_headers []adblock.ResponseHeader
	expected     adblock.Decision
}

fn check_case(entry CorpusCase) adblock.Decision {
	request := adblock.Request{url: entry.url, source_url: entry.source_url, request_type: entry.request_type, method: entry.method}
	if entry.phase == 'response' {
		mut headers := entry.response_headers.clone()
		headers << entry.request_headers
		return adblock.check_response(request, headers)
	}
	if entry.phase != 'request' { return adblock.Decision{error: 'Unknown filtering phase: ${entry.phase}'} }
	return adblock.check(request)
}

// Batch entry point for comparing request decisions against full uBlock Origin.
// Input is an array of {url, source_url, request_type}; output preserves its order.
fn main() {
	if os.args.len >= 3 && os.args[1] == '--document-filters' {
		filters := adblock.document_filters(os.args[2], os.args[3..]) or {
			eprintln(err)
			exit(1)
		}
		println(json.encode(filters))
		return
	}
	if os.args.len == 3 && os.args[1] == '--verify' {
		verify(os.args[2])
		return
	}
	if os.args.len != 2 {
		eprintln('Usage: adblock_check REQUESTS.json | --verify CORPUS.json | --document-filters URL [TOKENS...]')
		exit(2)
	}
	content := os.read_file(os.args[1]) or {
		eprintln(err)
		exit(1)
	}
	requests := json.decode([]CorpusCase, content) or {
		eprintln(err)
		exit(1)
	}
	mut decisions := []adblock.Decision{cap: requests.len}
	for request in requests {
		decision := check_case(request)
		if decision.error != '' {
			eprintln(decision.error)
			exit(1)
		}
		decisions << decision
	}
	println(json.encode(decisions))
}

fn verify(path string) {
	content := os.read_file(path) or {
		eprintln(err)
		exit(1)
	}
	corpus := json.decode(Corpus, content) or {
		eprintln(err)
		exit(1)
	}
	if corpus.requests.len == 0 {
		eprintln('Corpus contains no requests')
		exit(1)
	}
	mut failures := 0
	mut blocked := 0
	for entry in corpus.requests {
		actual := check_case(entry)
		if actual.error != '' {
			eprintln(actual.error)
			exit(1)
		}
		if actual.blocked {
			blocked++
		}
		if actual.error != '' || actual.blocked != entry.expected.blocked
			|| actual.exception != entry.expected.exception {
			failures++
			eprintln('${entry.request_type} ${entry.url}: expected ${json.encode(entry.expected)}, got ${json.encode(actual)}')
		}
	}
	println('Compared ${corpus.requests.len} requests: ${blocked} blocked, ${corpus.requests.len - blocked} allowed, ${failures} mismatches')
	if failures != 0 {
		exit(1)
	}
}
