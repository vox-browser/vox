module css

import dom
import strings

// Translated media/support CSSOM logic formerly hosted as stubs in cssom_rules.v.

@[heap]
pub struct Supports {
pub mut:
	condition &BooleanExpression = unsafe { nil }
	matches   bool
}

pub fn Supports.create(condition &BooleanExpression) &Supports {
	return &Supports{
		condition: condition
		matches:   condition.evaluate_to_boolean(none)
	}
}

pub fn (supports &Supports) to_string() string {
	return supports.condition.to_string()
}

pub fn (supports &Supports) matches_condition() bool {
	return supports.matches
}

pub fn (supports &Supports) dump(indent_levels int) string {
	return '${cssom_indent(indent_levels)}Supports condition: (matches = ${supports.matches})\n${supports.condition.dump(
		indent_levels + 1)}'
}

pub fn parse_css_supports(context ParsingParams, condition_text string) ?&Supports {
	_ = context
	return parse_css_supports_stub(condition_text)
}

fn parse_css_supports_stub(condition_text string) ?&Supports {
	trimmed := condition_text.trim_space()
	if trimmed.len == 0 {
		return none
	}
	return Supports.create(BooleanExpression.create_general_enclosed(trimmed, .true_))
}

pub enum MediaQueryKnownMediaType {
	all
	print
	screen
}

pub fn media_type_from_string(name string) ?MediaQueryKnownMediaType {
	return match name.to_lower() {
		'all' { MediaQueryKnownMediaType.all }
		'print' { MediaQueryKnownMediaType.print }
		'screen' { MediaQueryKnownMediaType.screen }
		else { none }
	}
}

pub fn media_query_known_media_type_to_string(media_type MediaQueryKnownMediaType) string {
	return match media_type {
		.all { 'all' }
		.print { 'print' }
		.screen { 'screen' }
	}
}

@[heap]
pub struct MediaQuery {
pub mut:
	text    string = 'all'
	matches bool   = true
}

pub fn parse_media_query(context ParsingParams, text string) ?&MediaQuery {
	_ = context
	trimmed := text.trim_space()
	if trimmed.len == 0 {
		return none
	}
	return &MediaQuery{
		text:    trimmed
		matches: media_query_text_matches_stub(trimmed)
	}
}

pub fn (media_query &MediaQuery) evaluate(doc &dom.Document) bool {
	_ = doc
	return media_query.matches
}

pub fn (media_query &MediaQuery) to_string() string {
	return media_query.text
}

pub fn (media_query &MediaQuery) matches() bool {
	return media_query.matches
}

pub fn (media_query &MediaQuery) dump(indent_levels int) string {
	return '${cssom_indent(indent_levels)}Media condition: ${media_query.text} (matches = ${media_query.matches})\n'
}

pub struct MediaQueryListEntry {
pub mut:
	text    string
	matches bool
}

@[heap]
pub struct MediaList {
pub mut:
	media                  []MediaQueryListEntry
	associated_style_sheet ?&CSSStyleSheet
}

pub fn MediaList.create(media []MediaQueryListEntry) &MediaList {
	return &MediaList{
		media: media
	}
}

pub fn MediaList.create_empty() &MediaList {
	return MediaList.create([]MediaQueryListEntry{})
}

// https://www.w3.org/TR/cssom-1/#dom-medialist-mediatext
pub fn (media_list &MediaList) media_text() string {
	return serialize_a_media_query_list_entries(media_list.media)
}

// https://www.w3.org/TR/cssom-1/#dom-medialist-mediatext
pub fn (mut media_list MediaList) set_media_text(text string) {
	media_list.media.clear()
	if text.trim_space().len != 0 {
		media_list.media = parse_media_query_list_stub(text)
	}
	media_list.invalidate_associated_style_sheet()
}

pub fn (media_list &MediaList) length() int {
	return media_list.media.len
}

// https://www.w3.org/TR/cssom-1/#dom-medialist-item
pub fn (media_list &MediaList) item(index u32) ?string {
	if int(index) >= media_list.media.len {
		return none
	}
	return media_list.media[index].text
}

// https://www.w3.org/TR/cssom-1/#dom-medialist-appendmedium
pub fn (mut media_list MediaList) append_medium(medium string) {
	// 1. Let m be the result of parsing the given value.
	parsed := parse_media_query_entry_stub(medium) or { return }

	// 2. If m is null, then return.
	serialized := parsed.text

	// 3. If comparing m with any of the media queries in the collection of media queries returns true, then return.
	for existing_medium in media_list.media {
		if existing_medium.text == serialized {
			return
		}
	}

	// 4. Append m to the collection of media queries.
	media_list.media << parsed
	media_list.invalidate_associated_style_sheet()
}

// https://www.w3.org/TR/cssom-1/#dom-medialist-deletemedium
pub fn (mut media_list MediaList) delete_medium(medium string) ! {
	// 1. Let m be the result of parsing the given value.
	parsed := parse_media_query_entry_stub(medium) or { return }

	// 2. If m is null, then return.
	serialized := parsed.text

	// 3. Remove any media query from the collection of media queries for which comparing the media query with m
	//    returns true. If nothing was removed, then throw a NotFoundError exception.
	mut was_removed := false
	mut kept := []MediaQueryListEntry{}
	for existing in media_list.media {
		if existing.text == serialized {
			was_removed = true
			continue
		}
		kept << existing
	}
	if !was_removed {
		return error('NotFoundError: Media query not found in list')
	}

	media_list.media = kept
	media_list.invalidate_associated_style_sheet()
}

pub fn (mut media_list MediaList) evaluate(document &dom.Document) bool {
	for i in 0 .. media_list.media.len {
		media_list.media[i].matches = evaluate_media_query_entry_stub(media_list.media[i], document)
	}
	return media_list.matches()
}

pub fn (media_list &MediaList) matches() bool {
	if media_list.media.len == 0 {
		return true
	}

	for media in media_list.media {
		if media.matches {
			return true
		}
	}
	return false
}

pub fn (mut media_list MediaList) set_associated_style_sheet(style_sheet &CSSStyleSheet) {
	unsafe {
		media_list.associated_style_sheet = style_sheet
	}
}

fn (media_list &MediaList) invalidate_associated_style_sheet() {
	if sheet := media_list.associated_style_sheet {
		mut mutable_sheet := unsafe { &CSSStyleSheet(sheet) }
		mutable_sheet.invalidate_owners(dom.StyleInvalidationReason.style_change)
	}
}

pub fn (media_list &MediaList) dump(indent_levels int) string {
	mut builder := strings.new_builder(64)
	builder.write_string('${cssom_indent(indent_levels)}Media list (${media_list.media.len}):\n')
	for media in media_list.media {
		builder.write_string('${cssom_indent(indent_levels + 1)}${media.text} (matches = ${media.matches})\n')
	}
	return builder.str()
}

pub fn serialize_a_media_query_list(media_queries []&MediaQuery) string {
	// 1. If the media query list is empty, then return the empty string.
	if media_queries.len == 0 {
		return ''
	}

	// 2. Serialize each media query in the list of media queries, in the same order as they
	// appear in the media query list, and then serialize the list.
	mut serialized := []string{}
	for media_query in media_queries {
		serialized << media_query.to_string()
	}
	return serialized.join(', ')
}

pub fn serialize_a_media_query_list_entries(media_queries []MediaQueryListEntry) string {
	if media_queries.len == 0 {
		return ''
	}
	mut serialized := []string{}
	for media_query in media_queries {
		serialized << media_query.text
	}
	return serialized.join(', ')
}

fn media_query_text_matches_stub(text string) bool {
	lower := text.to_lower().trim_space()
	if lower == 'not all' {
		return false
	}
	if lower == 'all' || lower == 'screen' {
		return true
	}
	if lower == 'print' {
		return false
	}
	return true
}

fn parse_media_query_entry_stub(medium string) ?MediaQueryListEntry {
	trimmed := medium.trim_space()
	if trimmed.len == 0 {
		return none
	}
	return MediaQueryListEntry{
		text:    trimmed
		matches: media_query_text_matches_stub(trimmed)
	}
}

fn parse_media_query_list_stub(text string) []MediaQueryListEntry {
	mut media := []MediaQueryListEntry{}
	for part in text.split(',') {
		if entry := parse_media_query_entry_stub(part) {
			media << entry
		}
	}
	return media
}

fn evaluate_media_query_entry_stub(entry MediaQueryListEntry, document &dom.Document) bool {
	_ = document
	return media_query_text_matches_stub(entry.text)
}
