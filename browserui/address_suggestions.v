module browserui

import math
import ui2

// Address-bar autocomplete. The browser supplies history and bookmark entries
// as candidates; this component ranks them, chooses the inline completion and
// owns the dropdown's rows, keyboard selection, layout and actions.

pub const address_suggestion_matches = 6
pub const address_suggestion_row_height = 26.0
const address_suggestion_padding = 4.0
// Native labels measure their complete text. Keep long URLs and titles short.
const address_suggestion_text_limit = 240

pub struct AddressCandidate {
pub:
	url          string
	title        string
	visits       int
	last_visited i64
	bookmarked   bool
}

pub enum AddressSuggestionKind {
	// The text as typed. The browser resolves it to an address or a search,
	// exactly as Enter does without a dropdown.
	typed
	// A history or bookmark destination.
	visit
	// The typed text sent to the search engine, even when it names a host.
	search
}

pub struct AddressSuggestion {
pub:
	kind       AddressSuggestionKind
	url        string // destination; the trimmed query for typed and search rows
	title      string
	fill       string // field text while the row is selected
	bookmarked bool
}

pub struct AddressQuery {
pub:
	text string
	// False after deletions, cuts, pastes and undo: the dropdown still updates,
	// but the field keeps exactly what the user left in it.
	allow_inline bool = true
	now          i64
	search_label string = 'Search'
}

pub struct AddressDropdown {
pub:
	token       u64
	query       string // field text as typed, without the inline completion
	inline      bool   // the first row's fill extends query with a completion
	suggestions []AddressSuggestion
pub mut:
	// Row 0 is the default match, which Enter opens without moving the selection.
	active int
}

// A lowercase query word. Words with other text match titles character by
// character with Unicode lowering; ASCII words fold bytes.
struct AddressTerm {
	text  string
	ascii bool
	runes []rune
}

struct RankedAddress {
	index        int
	score        f64
	last_visited i64
	url          string
}

struct AddressHost {
mut:
	score f64
	best  int = -1 // most frecent candidate on the host
	root  int = -1 // a visited root page of the host
	best_frecency f64
}

// address_display_range is the byte range of an address that the bar shows:
// without the HTTP(S) scheme, a leading `www.` and the root path's slash.
fn address_display_range(address string) (int, int) {
	mut start := if address.starts_with('https://') {
		'https://'.len
	} else if address.starts_with('http://') {
		'http://'.len
	} else {
		return 0, address.len
	}
	if address_folded_prefix(address, start, address.len, 'www.') { start += 'www.'.len }
	mut end := address.len
	for index in start .. address.len {
		if address[index] == `/` {
			if index == address.len - 1 { end = index }
			break
		}
	}
	return start, end
}

pub fn address_display_url(address string) string {
	start, end := address_display_range(address)
	if start == 0 && end == address.len { return address }
	return address[start..end]
}

// address_looks_like_url mirrors the browser's address resolution: text without
// spaces that names a host, a path or a scheme opens as an address.
pub fn address_looks_like_url(text string) bool {
	trimmed := text.trim_space()
	if trimmed == '' || trimmed.contains(' ') { return false }
	return trimmed.contains('.') || trimmed.contains(':') || trimmed.starts_with('localhost')
		|| trimmed.starts_with('/')
}

// address_dropdown builds the rows for the typed text. It returns none when
// there is nothing to complete, which closes the dropdown.
pub fn address_dropdown(token u64, query AddressQuery, candidates []AddressCandidate) ?AddressDropdown {
	trimmed := query.text.trim_space()
	if trimmed == '' { return none }
	mut rows := []AddressSuggestion{}
	mut inline := false
	if query.allow_inline {
		if completion := address_inline_completion(query.text, candidates, query.now) {
			rows << completion
			inline = true
		}
	}
	url_like := address_looks_like_url(trimmed)
	if rows.len == 0 {
		rows << AddressSuggestion{
			kind:  if url_like { AddressSuggestionKind.typed } else { AddressSuggestionKind.search }
			url:   trimmed
			title: if url_like { 'Open address' } else { query.search_label }
			fill:  query.text
		}
	}
	lowered := trimmed.to_lower()
	mut terms := []AddressTerm{}
	for word in lowered.fields() {
		ascii := word.is_pure_ascii()
		terms << AddressTerm{ text: word, ascii: ascii, runes: if ascii { []rune{} } else { word.runes() } }
	}
	mut ranked := []RankedAddress{}
	for index, candidate in candidates {
		if candidate.url == rows[0].url { continue }
		score := address_candidate_score(candidate, terms, lowered, query.now)
		if score > 0 {
			ranked << RankedAddress{
				index:        index
				score:        score
				last_visited: candidate.last_visited
				url:          candidate.url
			}
		}
	}
	ranked.sort_with_compare(fn (a &RankedAddress, b &RankedAddress) int {
		if a.score != b.score { return if a.score > b.score { -1 } else { 1 } }
		if a.last_visited != b.last_visited { return if a.last_visited > b.last_visited { -1 } else { 1 } }
		return compare_strings(a.url, b.url)
	})
	for entry in ranked {
		if rows.len > address_suggestion_matches { break }
		candidate := candidates[entry.index]
		rows << AddressSuggestion{
			kind:       .visit
			url:        candidate.url
			title:      address_suggestion_title(candidate.title)
			fill:       address_display_url(candidate.url)
			bookmarked: candidate.bookmarked
		}
	}
	// Offer an explicit search when the default row would open an address.
	if rows[0].kind != .search && !trimmed.contains('://') {
		rows << AddressSuggestion{ kind: .search, url: trimmed, title: query.search_label, fill: query.text }
	}
	return AddressDropdown{ token: token, query: query.text, inline: inline, suggestions: rows }
}

// address_inline_completion extends text typed at the start of a visited host
// (or, once the text has a path, of a visited address) with its remainder.
// Hosts rank by their pages' combined frecency and open at their root.
// Candidates are compared in place; only matches allocate.
fn address_inline_completion(text string, candidates []AddressCandidate, now i64) ?AddressSuggestion {
	if text == '' || text.contains(' ') || text != text.trim_space() { return none }
	lowered := text.to_lower_ascii()
	if lowered.contains('://') {
		mut best := -1
		mut best_score := 0.0
		for index, candidate in candidates {
			if !address_folded_prefix(candidate.url, 0, candidate.url.len, lowered) { continue }
			score := address_frecency(candidate, now)
			if best < 0 || score > best_score {
				best = index
				best_score = score
			}
		}
		if best < 0 { return none }
		candidate := candidates[best]
		return AddressSuggestion{
			kind:       .visit
			url:        candidate.url
			title:      address_suggestion_title(candidate.title)
			fill:       text + candidate.url[lowered.len..]
			bookmarked: candidate.bookmarked
		}
	}
	key := if lowered.starts_with('www.') { lowered['www.'.len..] } else { lowered }
	if key == '' { return none }
	if key.contains('/') || key.contains('?') || key.contains('#') {
		mut best := -1
		mut best_score := 0.0
		mut best_end := 0
		mut best_start := 0
		for index, candidate in candidates {
			start, end := address_display_range(candidate.url)
			if !address_folded_prefix(candidate.url, start, end, key) { continue }
			score := address_frecency(candidate, now)
			if best < 0 || score > best_score {
				best = index
				best_score = score
				best_start = start
				best_end = end
			}
		}
		if best < 0 { return none }
		candidate := candidates[best]
		return AddressSuggestion{
			kind:       .visit
			url:        candidate.url
			title:      address_suggestion_title(candidate.title)
			fill:       text + candidate.url[best_start + key.len..best_end]
			bookmarked: candidate.bookmarked
		}
	}
	mut hosts := map[string]AddressHost{}
	for index, candidate in candidates {
		host_start, authority_end := address_authority(candidate.url) or { continue }
		if !address_folded_prefix(candidate.url, host_start, authority_end, key) { continue }
		host := candidate.url[host_start..authority_end].to_lower_ascii()
		frecency := address_frecency(candidate, now)
		mut entry := hosts[host] or { AddressHost{} }
		entry.score += frecency
		if entry.best < 0 || frecency > entry.best_frecency {
			entry.best = index
			entry.best_frecency = frecency
		}
		is_root := authority_end == candidate.url.len - 1 && candidate.url[authority_end] == `/`
		if is_root && (entry.root < 0 || frecency > address_frecency(candidates[entry.root], now)) {
			entry.root = index
		}
		hosts[host] = entry
	}
	mut chosen := ''
	mut chosen_score := 0.0
	for host, entry in hosts {
		if chosen == '' || entry.score > chosen_score
			|| (entry.score == chosen_score && (host.len < chosen.len
			|| (host.len == chosen.len && host < chosen))) {
			chosen = host
			chosen_score = entry.score
		}
	}
	if chosen == '' { return none }
	entry := hosts[chosen] or { return none }
	if entry.root >= 0 {
		root := candidates[entry.root]
		return AddressSuggestion{
			kind:       .visit
			url:        root.url
			title:      address_suggestion_title(root.title)
			fill:       text + chosen[key.len..]
			bookmarked: root.bookmarked
		}
	}
	best := candidates[entry.best].url
	_, authority_end := address_authority(best) or { return none }
	return AddressSuggestion{
		kind:  .visit
		url:   best[..authority_end].to_lower_ascii() + '/'
		title: chosen
		fill:  text + chosen[key.len..]
	}
}

// address_authority locates an HTTP(S) address's host, skipping a leading
// `www.` that completion ignores, and the end of its authority. Addresses
// carrying credentials are never completed.
fn address_authority(address string) ?(int, int) {
	scheme_end := if address.starts_with('https://') {
		'https://'.len
	} else if address.starts_with('http://') {
		'http://'.len
	} else {
		return none
	}
	mut end := address.len
	for index in scheme_end .. address.len {
		character := address[index]
		if character == `/` || character == `?` || character == `#` {
			end = index
			break
		}
		if character == `@` { return none }
	}
	if end == scheme_end { return none }
	host_start := if address_folded_prefix(address, scheme_end, end, 'www.') {
		scheme_end + 'www.'.len
	} else {
		scheme_end
	}
	return host_start, end
}

fn address_frecency(candidate AddressCandidate, now i64) f64 {
	mut score := 12.0 * math.log2(1.0 + f64(candidate.visits))
	if candidate.last_visited > 0 {
		age := math.max(0.0, f64(now - candidate.last_visited) / 86400.0)
		score += 25.0 / (1.0 + age / 7.0)
	}
	if candidate.bookmarked { score += 20 }
	return score
}

// Every term must occur in the shown address or the title. Matches at the
// start of the address or of a word outrank matches inside words.
// Neither the address nor the title is copied or lowered as a whole.
fn address_candidate_score(candidate AddressCandidate, terms []AddressTerm, query string, now i64) f64 {
	if terms.len == 0 { return 0 }
	url_start, url_end := address_display_range(candidate.url)
	mut score := 0.0
	for term in terms {
		url_first, url_word := address_match(candidate.url, url_start, url_end, term.text)
		mut term_score := 0.0
		if url_first == 0 {
			term_score = 30
		} else if url_first > 0 {
			term_score = if url_word { 15 } else { 6 }
		}
		if term_score < 12 {
			title_first, title_word := if term.ascii {
				address_match(candidate.title, 0, candidate.title.len, term.text)
			} else {
				address_unicode_match(candidate.title, term.runes)
			}
			if title_first >= 0 {
				term_score = math.max(term_score, if title_word { 12.0 } else { 4.0 })
			}
		}
		if term_score == 0 { return 0 }
		score += term_score
	}
	if address_folded_prefix(candidate.url, url_start, url_end, query) { score += 40 }
	return score + address_frecency(candidate, now)
}

fn address_ascii_lower(character u8) u8 {
	return if character >= `A` && character <= `Z` { character + 32 } else { character }
}

// address_folded_prefix reports whether text[start..end] begins with the
// lowercase term, ignoring ASCII case.
fn address_folded_prefix(text string, start int, end int, term string) bool {
	if start + term.len > end { return false }
	for index in 0 .. term.len {
		if address_ascii_lower(text[start + index]) != term[index] { return false }
	}
	return true
}

// address_match finds a lowercase term in text[start..end], ignoring ASCII
// case. It returns the first match's offset from start and whether any match
// begins a word.
fn address_match(text string, start int, end int, term string) (int, bool) {
	if term.len == 0 { return -1, false }
	mut first := -1
	for position := start; position + term.len <= end; position++ {
		if address_ascii_lower(text[position]) != term[0]
			|| !address_folded_prefix(text, position, end, term) {
			continue
		}
		if first < 0 { first = position - start }
		if position == start || !address_word_byte(text[position - 1]) { return first, true }
	}
	return first, false
}

// address_unicode_match is address_match for a word with non-ASCII text. It
// decodes and lowers the text's characters as it compares them.
fn address_unicode_match(text string, term []rune) (int, bool) {
	if term.len == 0 { return -1, false }
	mut first := -1
	mut position := 0
	for position < text.len {
		character, width := address_decode_rune(text, position)
		if character.to_lower() == term[0] {
			mut offset := position + width
			mut matched := 1
			for matched < term.len && offset < text.len {
				next, next_width := address_decode_rune(text, offset)
				if next.to_lower() != term[matched] { break }
				offset += next_width
				matched++
			}
			if matched == term.len {
				if first < 0 { first = position }
				if position == 0 || !address_word_byte(text[position - 1]) { return first, true }
			}
		}
		position += width
	}
	return first, false
}

// address_decode_rune reads one UTF-8 character; invalid bytes read as themselves.
fn address_decode_rune(text string, index int) (rune, int) {
	lead := text[index]
	if lead < 0x80 { return rune(lead), 1 }
	width, mask := if lead >= 0xf0 {
		4, u32(0x07)
	} else if lead >= 0xe0 {
		3, u32(0x0f)
	} else if lead >= 0xc0 {
		2, u32(0x1f)
	} else {
		1, u32(0xff)
	}
	if width == 1 || index + width > text.len { return rune(lead), 1 }
	mut value := u32(lead) & mask
	for offset in 1 .. width {
		value = (value << 6) | (u32(text[index + offset]) & 0x3f)
	}
	return rune(value), width
}

fn address_word_byte(character u8) bool {
	return character.is_alnum() || character >= 0x80
}

fn address_suggestion_title(title string) string {
	return address_suggestion_text(title.replace_each(['\r', ' ', '\n', ' ', '\t', ' ']).trim_space())
}

fn address_suggestion_text(text string) string {
	if text.len <= address_suggestion_text_limit { return text }
	runes := text.runes()
	if runes.len <= address_suggestion_text_limit { return text }
	return runes[..address_suggestion_text_limit].string() + '…'
}

// owned copies the dropdown out of the temporary scope that ranked it.
pub fn (dropdown AddressDropdown) owned() AddressDropdown {
	mut rows := []AddressSuggestion{cap: dropdown.suggestions.len}
	for row in dropdown.suggestions {
		rows << AddressSuggestion{
			...row
			url:   row.url.clone()
			title: row.title.clone()
			fill:  row.fill.clone()
		}
	}
	return AddressDropdown{
		...dropdown
		query:       dropdown.query.clone()
		suggestions: rows
	}
}

pub fn (dropdown AddressDropdown) action(index int) string {
	return 'address-suggestion:${dropdown.token}:${index}'
}

// row_for_action accepts only this dropdown's own row actions.
pub fn (dropdown AddressDropdown) row_for_action(action string) ?int {
	parts := action.split(':')
	if parts.len != 3 || parts[0] != 'address-suggestion' || parts[1] != dropdown.token.str() {
		return none
	}
	index := parts[2].int()
	if parts[2] != index.str() || index < 0 || index >= dropdown.suggestions.len { return none }
	return index
}

pub fn (dropdown AddressDropdown) selected() ?AddressSuggestion {
	if dropdown.active < 0 || dropdown.active >= dropdown.suggestions.len { return none }
	return dropdown.suggestions[dropdown.active]
}

// field_text is what the address field shows for the selected row.
pub fn (dropdown AddressDropdown) field_text() string {
	row := dropdown.selected() or { return dropdown.query }
	return row.fill
}

// field_selection is the rune range the field selects: the default row's
// inline completion, otherwise an insertion point at the end.
pub fn (dropdown AddressDropdown) field_selection() (int, int) {
	end := dropdown.field_text().runes().len
	if dropdown.active == 0 && dropdown.inline { return dropdown.query.runes().len, end }
	return end, end
}

pub fn (mut dropdown AddressDropdown) move(step int) {
	count := dropdown.suggestions.len
	if count == 0 { return }
	dropdown.active = ((dropdown.active + step) % count + count) % count
}

// row_labels returns the row's primary text and its dimmer description.
pub fn (row AddressSuggestion) row_labels() (string, string) {
	if row.kind == .visit { return address_suggestion_text(address_display_url(row.url)), row.title }
	return address_suggestion_text(row.url), row.title
}

// elements floats the dropdown below the address field at x/y with its width.
// Rows that do not fit in max_height are omitted.
pub fn (dropdown AddressDropdown) elements(x f64, y f64, width f64, max_height f64) []ui2.Element {
	visible := math.min(dropdown.suggestions.len,
		int((max_height - 2 * address_suggestion_padding) / address_suggestion_row_height))
	if visible <= 0 || width < 80 { return []ui2.Element{} }
	inner := width - 2 * address_suggestion_padding
	mut rows := []ui2.Element{}
	for index in 0 .. visible {
		row := dropdown.suggestions[index]
		primary, detail := row.row_labels()
		active := index == dropdown.active
		// Approximate the primary label's width, leaving the rest to the title.
		primary_width := math.min(inner * 0.62, math.max(48.0, f64(primary.runes().len) * 7.2 + 8))
		detail_text := if detail == '' { '' } else { '— ${detail}' }
		description := if detail == '' { primary } else { '${primary} ${detail_text}' }
		rows << ui2.view('address-suggestion-${index}', ui2.rect(address_suggestion_padding,
			address_suggestion_padding + f64(index) * address_suggestion_row_height, inner,
			address_suggestion_row_height), ui2.BoxStyle{
			bg:     if active { u32(0xdbeafe) } else { u32(0xffffff) }
			radius: 4
		}, [
			ui2.label('address-suggestion-text-${index}', primary, ui2.rect(10, 0, primary_width,
				address_suggestion_row_height), ui2.TextStyle{
				size:  12
				color: if row.kind == .visit { u32(0x1a56b8) } else { u32(0x222222) }
			}),
			ui2.label('address-suggestion-detail-${index}', detail_text, ui2.rect(16 + primary_width,
				0, math.max(0.0, inner - primary_width - 26), address_suggestion_row_height),
				ui2.TextStyle{ size: 12, color: 0x6b6b6b }),
			// The transparent row button sits above both labels and receives the click.
			ui2.Element{
				...ui2.button('address-suggestion-row-${index}', '', ui2.rect(0, 0, inner, address_suggestion_row_height),
					ui2.BoxStyle{ transparent: true }, ui2.TextStyle{ size: 12 })
				action_id:           dropdown.action(index)
				accessibility_role:  'menu_item'
				accessibility_label: description
				accessibility_value: if active { 'selected' } else { '' }
			},
		])
	}
	return [ui2.Element{
		...ui2.view('address-suggestions', ui2.rect(x, y, width, f64(visible) * address_suggestion_row_height +
			2 * address_suggestion_padding), ui2.BoxStyle{
			bg:            0xffffff
			radius:        6
			border_color:  0xc4c4c4
			border_left:   1
			border_top:    1
			border_right:  1
			border_bottom: 1
		}, rows)
		accessibility_role:  'menu'
		accessibility_label: 'Address suggestions'
	}]
}
