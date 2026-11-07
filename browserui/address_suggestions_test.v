module browserui

const suggestion_now = i64(1_800_000_000)

fn suggestion_candidates() []AddressCandidate {
	return [
		AddressCandidate{ url: 'https://github.com/vlang/v', title: 'vlang/v: Simple, fast, safe language', visits: 9, last_visited: suggestion_now - 60 },
		AddressCandidate{ url: 'https://github.com/', title: 'GitHub', visits: 2, last_visited: suggestion_now - 3600 },
		AddressCandidate{ url: 'https://gitlab.com/explore', title: 'Explore · GitLab', visits: 1, last_visited: suggestion_now - 86400 * 30 },
		AddressCandidate{ url: 'http://intranet.example/wiki/Start', title: 'Start page', visits: 4, last_visited: suggestion_now - 600 },
		AddressCandidate{ url: 'https://news.ycombinator.com/item?id=1', title: 'A long\nthread', visits: 1, last_visited: suggestion_now - 120 },
		AddressCandidate{ url: 'https://docs.example.org/guide/install', title: 'Installing the guide tool', bookmarked: true },
	]
}

fn suggestion_dropdown(text string) AddressDropdown {
	return address_dropdown(5, AddressQuery{ text: text, now: suggestion_now, search_label: 'DuckDuckGo Search' }, suggestion_candidates()) or {
		panic('no dropdown for ${text}')
	}
}

fn selection_text(dropdown AddressDropdown) string {
	start, end := dropdown.field_selection()
	return '${start},${end}'
}

fn test_display_url_drops_the_http_scheme_www_and_root_slash() {
	assert address_display_url('https://www.example.com/') == 'example.com'
	assert address_display_url('http://example.com/a/') == 'example.com/a/'
	assert address_display_url('https://example.com/?q=1') == 'example.com/?q=1'
	assert address_display_url('file:///tmp/page.html') == 'file:///tmp/page.html'
	assert address_display_url('https://') == ''
}

fn test_inline_completion_extends_a_host_prefix_and_opens_its_visited_root() {
	dropdown := suggestion_dropdown('Gi')
	assert dropdown.inline
	first := dropdown.suggestions[0]
	// github.com's pages outrank gitlab.com; the typed case is preserved.
	assert first.fill == 'Github.com'
	assert first.url == 'https://github.com/'
	assert first.title == 'GitHub'
	assert dropdown.field_text() == 'Github.com'
	assert selection_text(dropdown) == '2,10'
	// The completed root is not repeated as a match row.
	assert dropdown.suggestions.filter(it.url == 'https://github.com/').len == 1
}

fn test_inline_completion_keeps_the_visited_scheme_and_builds_unvisited_roots() {
	dropdown := suggestion_dropdown('intra')
	assert dropdown.suggestions[0].fill == 'intranet.example'
	assert dropdown.suggestions[0].url == 'http://intranet.example/'
	www := suggestion_dropdown('www.news')
	assert www.suggestions[0].fill == 'www.news.ycombinator.com'
	assert www.suggestions[0].url == 'https://news.ycombinator.com/'
}

fn test_inline_completion_follows_paths_and_full_addresses() {
	path := suggestion_dropdown('github.com/vl')
	assert path.suggestions[0].fill == 'github.com/vlang/v'
	assert path.suggestions[0].url == 'https://github.com/vlang/v'
	assert selection_text(path) == '13,18'
	scheme := suggestion_dropdown('http://intranet.example/w')
	assert scheme.suggestions[0].fill == 'http://intranet.example/wiki/Start'
	exact := suggestion_dropdown('github.com')
	assert exact.inline
	assert exact.suggestions[0].fill == 'github.com'
	assert selection_text(exact) == '10,10'
}

fn test_deletions_and_unmatched_text_keep_the_typed_text() {
	deleted := address_dropdown(1, AddressQuery{ text: 'gi', allow_inline: false, now: suggestion_now }, suggestion_candidates()) or {
		panic('missing dropdown')
	}
	assert !deleted.inline
	assert deleted.suggestions[0].kind == .search
	assert deleted.suggestions[0].fill == 'gi'
	assert selection_text(deleted) == '2,2'
	// The history still matches; only the inline text is withheld.
	assert deleted.suggestions.any(it.url == 'https://github.com/vlang/v')
	for text in ['vlang', 'gi ', ' gi', 'git hub'] {
		dropdown := suggestion_dropdown(text)
		assert !dropdown.inline, text
		assert dropdown.suggestions[0].fill == text
	}
	assert address_dropdown(1, AddressQuery{ text: '   ', now: suggestion_now }, suggestion_candidates()) == none
}

fn test_default_row_opens_addresses_and_searches_other_text_with_an_explicit_search_row() {
	address := suggestion_dropdown('unvisited.example/page')
	assert address.suggestions[0].kind == .typed
	assert address.suggestions[0].url == 'unvisited.example/page'
	assert address.suggestions[0].title == 'Open address'
	last := address.suggestions.last()
	assert last.kind == .search && last.url == 'unvisited.example/page' && last.title == 'DuckDuckGo Search'
	search := suggestion_dropdown('simple fast language')
	assert search.suggestions[0].kind == .search
	assert search.suggestions.filter(it.kind == .search).len == 1
	assert search.suggestions[1].url == 'https://github.com/vlang/v'
	full := suggestion_dropdown('https://unvisited.example/')
	assert full.suggestions.all(it.kind != .search)
}

fn test_matches_require_every_term_and_rank_words_frequency_and_bookmarks() {
	guide := suggestion_dropdown('guide inst')
	matches := guide.suggestions.filter(it.kind == .visit)
	assert matches.len == 1
	assert matches[0].url == 'https://docs.example.org/guide/install'
	assert matches[0].bookmarked
	assert matches[0].fill == 'docs.example.org/guide/install'
	// Titles are single-line in the dropdown.
	titled := suggestion_dropdown('thread')
	assert titled.suggestions.any(it.title == 'A long thread')
	unmatched := address_dropdown(1, AddressQuery{ text: 'nothing-like-this', now: suggestion_now }, suggestion_candidates()) or {
		panic('missing dropdown')
	}
	assert unmatched.suggestions.len == 1
	assert unmatched.suggestions[0].kind == .search
	mut many := []AddressCandidate{}
	for index in 0 .. 20 {
		many << AddressCandidate{ url: 'https://site${index}.example/', title: 'Site', visits: index + 1, last_visited: suggestion_now }
	}
	ranked := address_dropdown(1, AddressQuery{ text: 'site', allow_inline: false, now: suggestion_now }, many) or {
		panic('missing dropdown')
	}
	visits := ranked.suggestions.filter(it.kind == .visit)
	assert visits.len == address_suggestion_matches
	// More visits rank first.
	assert visits[0].url == 'https://site19.example/'
	assert visits[1].url == 'https://site18.example/'
}

fn test_keyboard_selection_wraps_and_fills_the_field_with_each_row() {
	mut dropdown := suggestion_dropdown('gi')
	count := dropdown.suggestions.len
	assert dropdown.active == 0
	dropdown.move(1)
	assert dropdown.active == 1
	assert dropdown.field_text() == dropdown.suggestions[1].fill
	end := dropdown.field_text().runes().len
	assert selection_text(dropdown) == '${end},${end}'
	dropdown.move(-2)
	assert dropdown.active == count - 1
	assert dropdown.suggestions[dropdown.active].kind == .search
	assert dropdown.field_text() == 'gi'
	dropdown.move(1)
	assert dropdown.field_text() == 'github.com'
	assert selection_text(dropdown) == '2,10'
}

fn test_actions_belong_to_one_dropdown_and_rows_render_below_the_field() {
	mut dropdown := suggestion_dropdown('gi')
	assert dropdown.action(2) == 'address-suggestion:5:2'
	assert (dropdown.row_for_action('address-suggestion:5:2') or { -1 }) == 2
	assert dropdown.row_for_action('address-suggestion:6:2') == none
	assert dropdown.row_for_action('address-suggestion:5:99') == none
	assert dropdown.row_for_action('address-suggestion:5:x') == none
	assert dropdown.row_for_action('address-suggestion:5:-1') == none
	dropdown.move(1)
	elements := dropdown.elements(98, 58, 600, 1000)
	assert elements.len == 1
	panel := elements[0]
	assert panel.id == 'address-suggestions'
	assert panel.accessibility_role == 'menu'
	assert panel.frame.x == 98 && panel.frame.y == 58 && panel.frame.width == 600
	assert panel.children.len == dropdown.suggestions.len
	assert panel.frame.height == f64(dropdown.suggestions.len) * address_suggestion_row_height + 8
	assert panel.children[1].box.bg == 0xdbeafe
	assert panel.children[0].box.bg == 0xffffff
	row := panel.children[1].children
	assert row[0].text == 'github.com/vlang/v'
	assert row[1].text.starts_with('— vlang/v')
	assert row[2].action_id == 'address-suggestion:5:1'
	assert row[2].accessibility_value == 'selected'
	assert row[2].accessibility_label.starts_with('github.com/vlang/v — ')
	// Rows that do not fit are omitted rather than drawn over the status bar.
	short := dropdown.elements(98, 58, 600, 3 * address_suggestion_row_height + 8)
	assert short[0].children.len == 3
	assert dropdown.elements(98, 58, 600, 10).len == 0
}

fn test_matching_ignores_case_in_ascii_and_unicode_text() {
	candidates := [
		AddressCandidate{ url: 'https://Example.COM/Docs', title: 'Привет, МИР', visits: 1, last_visited: suggestion_now },
		AddressCandidate{ url: 'https://www.Mixed.example/', title: 'Mixed', visits: 1, last_visited: suggestion_now },
	]
	for text in ['EXAMPLE docs', 'мир', 'ПРИВЕТ'] {
		dropdown := address_dropdown(1, AddressQuery{ text: text, now: suggestion_now }, candidates) or {
			panic('missing dropdown')
		}
		assert dropdown.suggestions.any(it.url == 'https://Example.COM/Docs'), text
	}
	host := address_dropdown(1, AddressQuery{ text: 'MIX', now: suggestion_now }, candidates) or {
		panic('missing dropdown')
	}
	assert host.suggestions[0].fill == 'MIXed.example'
	assert host.suggestions[0].url == 'https://www.Mixed.example/'
	path := address_dropdown(1, AddressQuery{ text: 'example.com/d', now: suggestion_now }, candidates) or {
		panic('missing dropdown')
	}
	assert path.suggestions[0].fill == 'example.com/docs'
	assert path.suggestions[0].url == 'https://Example.COM/Docs'
}
