module adblock

import json

struct PopularRequestCorpus {
	engine PopularCorpusEngine
	lists []PopularCorpusList
	sites []PopularCorpusSite
	requests []PopularCorpusRequest
}

struct PopularCorpusEngine {
	version string
	commit string
}

struct PopularCorpusList {
	name string
	sha256 string
}

struct PopularCorpusSite {
	id string
	selected_requests int
	selected_blocked int
}

struct PopularCorpusRequest {
	url string
	source_url string
	request_type string
	method string
	site string
	expected Decision
}

fn test_popular_site_requests_match_recorded_full_ubo_decisions() {
	$if !darwin { return }
	corpus := json.decode(PopularRequestCorpus, $embed_file('../tools/adblock/fixtures/popular-sites.json').to_string())!
	manifest := json.decode(PopularRequestCorpus, $embed_file('lists/manifest.json').to_string())!
	assert corpus.engine == manifest.engine, 'Re-record the corpus with the current full uBO engine'
	for recorded in corpus.lists {
		assert manifest.lists.any(it == recorded), 'Re-record the corpus after refreshing its recorded lists'
	}
	assert corpus.sites.len == 6
	mut site_counts := map[string]int{}
	mut block_counts := map[string]int{}
	for entry in corpus.requests {
		actual := check(Request{
			url: entry.url
			source_url: entry.source_url
			request_type: entry.request_type
			method: entry.method
		})
		assert actual.error == '', '${entry.site}: ${actual.error}'
		assert actual.blocked == entry.expected.blocked, '${entry.site}: ${entry.url}: expected ${entry.expected}, got ${actual}'
		assert actual.exception == entry.expected.exception, '${entry.site}: ${entry.url}: expected ${entry.expected}, got ${actual}'
		site_counts[entry.site]++
		if actual.blocked { block_counts[entry.site]++ }
	}
	for site in corpus.sites {
		assert site_counts[site.id] == site.selected_requests
		assert block_counts[site.id] == site.selected_blocked
		assert site.selected_requests > site.selected_blocked, '${site.id} must retain allowed content controls'
	}
}
