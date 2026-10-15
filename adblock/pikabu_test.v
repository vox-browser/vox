module adblock

import json

struct PikabuListManifest {
	lists []PikabuManifestList
	engine PikabuCorpusEngine
	requests []PikabuCorpusRequest
}

struct PikabuManifestList {
	name string
	sha256 string
}

struct PikabuCorpusEngine {
	version string
	commit string
}

struct PikabuCorpusRequest {
	url string
	source_url string
	request_type string
	method string
	phase string
	response_headers []ResponseHeader
	request_headers []ResponseHeader
	expected Decision
}

fn test_russian_default_list_retains_pikabu_ad_and_content_decisions() {
	$if !darwin { return }
	manifest := json.decode(PikabuListManifest, $embed_file('lists/manifest.json').to_string())!
	assert manifest.lists.len == default_list_count
	assert manifest.lists.any(it.name == 'RUS-0')
	for url in ['https://cs45.pikabu.ru/v2/event/j/3/ad_request', 'https://pikabu.ru/ajax//advert'] {
		decision := check(Request{url: url, source_url: 'https://pikabu.ru/', request_type: 'xmlhttprequest', method: 'POST'})
		assert decision.error == '', decision.error
		assert decision.blocked, '${url}: ${decision}'
	}
	for url in ['https://pikabu.ru/', 'https://pikabu.ru/story/ordinary_story', 'https://pikabu.ru/ajax/stories'] {
		decision := check(Request{url: url, source_url: 'https://pikabu.ru/', request_type: if url.contains('/ajax/') { 'xmlhttprequest' } else { 'main_frame' }})
		assert decision.error == '', decision.error
		assert !decision.blocked, '${url}: ${decision}'
	}
	response := check_response(Request{url: 'https://pikabu.ru/ajax/stories', source_url: 'https://pikabu.ru/', request_type: 'xmlhttprequest'}, [ResponseHeader{name: 'LLaSalBBubRRl', value: '1'}])
	assert response.error == '', response.error
	assert response.blocked
	assert response.rule.contains('responseheader=llasalbbubrrl')
}

fn test_recorded_pikabu_request_and_header_decisions_match_full_ublock_origin() {
	$if !darwin { return }
	manifest := json.decode(PikabuListManifest, $embed_file('lists/manifest.json').to_string())!
	for raw in [$embed_file('../tools/adblock/fixtures/pikabu.json').to_string(),
		$embed_file('../tools/adblock/fixtures/pikabu-response-controls.json').to_string()] {
		corpus := json.decode(PikabuListManifest, raw)!
		assert corpus.engine == manifest.engine
		assert corpus.lists == manifest.lists
		assert corpus.requests.len > 0
		for entry in corpus.requests {
			request := Request{url: entry.url, source_url: entry.source_url,
				request_type: entry.request_type, method: entry.method}
			mut headers := entry.response_headers.clone()
			headers << entry.request_headers
			assert entry.phase in ['request', 'response']
			actual := if entry.phase == 'response' { check_response(request, headers) } else { check(request) }
			assert actual.error == '', actual.error
			assert actual.blocked == entry.expected.blocked, '${entry.phase} ${entry.url}: ${actual}'
			assert actual.exception == entry.expected.exception, '${entry.phase} ${entry.url}: ${actual}'
			assert actual.rule == entry.expected.rule, '${entry.phase} ${entry.url}: ${actual}'
		}
	}
}
