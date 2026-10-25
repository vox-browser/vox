module browserhistory

fn test_most_visited_groups_sites_and_ranks_by_frequency_then_recency() {
	mut store := open('', 10000000)!
	store.record('http://www.docs.example/intro', 'Introduction', 10000000)!
	store.record('https://news.example/old', 'Old news', 10000100)!
	store.record('https://docs.example/reference', 'Reference', 10000200)!
	store.record('https://news.example/latest', 'Latest news', 10000300)!
	store.record('https://recent.example/', 'Recent', 10000400)!
	sites := store.most_visited(8, 10000400)
	assert sites.len == 3
	assert sites[0].host == 'news.example'
	assert sites[0].visits == 2
	assert sites[0].url == 'https://news.example/latest'
	assert sites[0].title == 'Latest news'
	assert sites[1].host == 'docs.example'
	assert sites[1].visits == 2
	assert sites[2].host == 'recent.example'
	assert store.visits.len == 5
}

fn test_most_visited_excludes_expired_local_internal_and_credential_urls() {
	mut store := open('', 10000000)!
	store.visits = [
		Visit{url: 'https://old.example/', visited_at: 10000000 - retention_seconds},
		Visit{url: 'file:///tmp/local.html', visited_at: 10000000},
		Visit{url: 'vox://history', visited_at: 10000000},
		Visit{url: 'javascript:alert(1)', visited_at: 10000000},
		Visit{url: 'https://user:secret@private.example/', visited_at: 10000000},
		Visit{url: 'not a url', visited_at: 10000000},
		Visit{url: 'https://safe.example/', visited_at: 10000000},
	]
	sites := store.most_visited(8, 10000000)
	assert sites.len == 1
	assert sites[0].host == 'safe.example'
	assert store.most_visited(8, 10000000 + retention_seconds).len == 0
}

fn test_most_visited_limits_results_and_preserves_distinct_ports() {
	mut store := open('', 10000000)!
	for index in 0 .. 12 {
		store.record('https://site${index}.example/', 'Site ${index}', 10000000 + index)!
	}
	sites := store.most_visited(8, 10000020)
	assert sites.len == 8
	assert sites[0].host == 'site11.example'
	assert sites[7].host == 'site4.example'
	assert store.most_visited(0, 10000020).len == 0
	assert store.most_visited(-1, 10000020).len == 0
	store.visits = [
		Visit{url: 'http://example.com:8080/a', visited_at: 10000000},
		Visit{url: 'https://example.com:8080/b', visited_at: 10000001},
		Visit{url: 'https://example.com/', visited_at: 10000002},
	]
	ports := store.most_visited(8, 10000002)
	assert ports.len == 2
	assert ports[0].host == 'example.com:8080'
	assert ports[0].visits == 2
	store.visits = [
		Visit{url: 'https://z.example/', visited_at: 10000000},
		Visit{url: 'https://a.example/', visited_at: 10000000},
	]
	assert store.most_visited(8, 10000000).map(it.host) == ['a.example', 'z.example']
}
