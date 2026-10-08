module html

import dom
import math

@[heap]
struct StartDateRoundingClock {
mut:
	offset ?i64
}

fn start_date_rounding_fixture() !(&HTMLMediaElement, &StartDateRoundingClock) {
	url := dom.URL{ value: 'https://start-date-rounding.example.test/' }
	document := parse_navigation_document('<audio id="audio"></audio>', url, url.origin(), none)!
	element := document.get_element_by_id('audio') or { return error('missing audio') }
	mut media := html_media_element_for_dom_element(element) or { return error('missing model') }
	clock := &StartDateRoundingClock{}
	media.set_playback_manager_hooks(MediaPlaybackManagerHooks{
		start_time_realtime: fn [clock] () ?i64 { return clock.offset }
	})
	return media, clock
}

fn test_actual_media_start_date_rounds_fractional_milliseconds_away_from_zero() {
	mut media, mut clock := start_date_rounding_fixture()!
	for pair in [[i64(1), i64(1)], [i64(999), i64(1)], [i64(1000), i64(1)],
		[i64(1001), i64(2)], [i64(-1), i64(-1)], [i64(-999), i64(-1)],
		[i64(-1000), i64(-1)], [i64(-1001), i64(-2)], [i64(0), i64(0)]] {
		clock.offset = pair[0]
		media.on_metadata_parsed(10)
		date := media.get_start_date()
		assert date.get_time() == f64(pair[1]), 'offset ${pair[0]}'
		if pair[0] == 0 { assert !math.signbit(date.get_time()) }
	}
	media.set_source(none)
	media.load()!
}

fn test_actual_media_start_date_rounding_avoids_integer_overflow_at_clock_extremes() {
	mut media, mut clock := start_date_rounding_fixture()!
	clock.offset = i64(9_000_000_000_000_000_001)
	media.on_metadata_parsed(10)
	assert media.get_start_date().get_time() == f64(i64(9_000_000_000_000_001))
	clock.offset = i64(-9_000_000_000_000_000_001)
	media.on_metadata_parsed(10)
	assert media.get_start_date().get_time() == f64(i64(-9_000_000_000_000_001))
	clock.offset = i64(9_223_372_036_854_775_807)
	media.on_metadata_parsed(10)
	assert media.get_start_date().get_time() == f64(i64(9_223_372_036_854_776))
	clock.offset = i64(-9_223_372_036_854_775_807) - 1
	media.on_metadata_parsed(10)
	assert media.get_start_date().get_time() == f64(i64(-9_223_372_036_854_776))
	media.set_source(none)
	media.load()!
}

fn test_actual_media_start_date_is_fresh_and_load_removes_the_timeline_offset() {
	mut media, mut clock := start_date_rounding_fixture()!
	assert math.is_nan(media.get_start_date().get_time())
	clock.offset = i64(1_725_084_800_987_654)
	media.on_metadata_parsed(10)
	first := media.get_start_date()
	second := media.get_start_date()
	assert first.get_time() == 1_725_084_800_988
	assert voidptr(first) != voidptr(second)
	clock.offset = none
	media.on_metadata_parsed(10)
	assert math.is_nan(media.get_start_date().get_time())
	assert first.get_time() == 1_725_084_800_988
	clock.offset = i64(42_001)
	media.on_metadata_parsed(10)
	media.set_source(none)
	media.set_source_candidates([])
	media.load()!
	assert math.is_nan(media.get_start_date().get_time())
}
