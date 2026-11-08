module main

import css
import dom

fn site_test_animation_clock(document &dom.Document) ?f64 {
	return 1250
}

fn site_test_unavailable_animation_clock(document &dom.Document) ?f64 {
	return none
}

fn test_css_animation_clock_reads_and_seeks_without_a_display_tick() {
	mut document := site_wakeup_fixture('.prc-Skeleton-SkeletonBox-e93nW{animation-duration:0s;animation-iteration-count:1}')
	defer { document.finalize() }
	mut computer := css.css_style_computer_for(document)
	computer.set_animation_time_ms(1000)
	css.set_document_animation_clock_reader(document, site_test_animation_clock)
	record := css.document_css_animations(document)[0]
	document.needs_animated_style_update = false
	assert css.document_css_animation_current_time(document, record.handle)? == 1250
	assert css.document_css_animation_set_current_time(document, record.handle, 250)
	assert css.document_css_animation_current_time(document, record.handle)? == 250
	assert computer.animation_time_ms_ == 1000
	assert !document.needs_animated_style_update
}

fn test_github_completed_clock_tick_keeps_current_time_without_requesting_style() {
	mut document := site_wakeup_fixture('.prc-Skeleton-SkeletonBox-e93nW{animation-duration:0s;animation-iteration-count:1}')
	defer { document.finalize() }
	configure_site_animation_clock_demand(document)
	css.set_document_animation_clock_reader(document, site_test_unavailable_animation_clock)
	mut computer := css.css_style_computer_for(document)
	record := css.document_css_animations(document)[0]
	document.needs_animated_style_update = false
	computer.set_animation_time_ms(750)
	assert document.needs_animated_style_update == disable_github_animation_wakeup_throttling
	assert css.document_css_animation_current_time(document, record.handle)? == 750
	assert css.document_css_animation_set_current_time(document, record.handle, -250)
	document.needs_animated_style_update = false
	computer.set_animation_time_ms(800)
	assert document.needs_animated_style_update
}

fn test_github_clock_demand_preserves_active_effects_and_host_scope() {
	mut document := site_wakeup_fixture('')
	defer { document.finalize() }
	configure_site_animation_clock_demand(document)
	mut computer := css.css_style_computer_for(document)
	document.needs_animated_style_update = false
	computer.set_animation_time_ms(750)
	assert document.needs_animated_style_update
	document.url = dom.URL{value:'https://example.org/'}
	document.needs_animated_style_update = false
	computer.set_animation_time_ms(800)
	assert document.needs_animated_style_update
}

fn test_github_scroll_clock_stays_idle_until_its_source_moves() {
	mut document := parse_browser_navigation_document('<!doctype html><style>@keyframes progress{from{opacity:0.2}to{opacity:1}}#nav{overflow:auto;width:100px;height:20px;animation:progress 1ms linear both;animation-timeline:scroll(self)}#nav span{display:block;width:300px;height:100px}</style><div id="nav"><span>scroll me</span></div>', dom.URL{value:'https://github.com/vlang/v'}, none)
	defer { document.finalize() }
	mut app := BrowserApp{document:document}
	app.relayout(320,312)
	configure_site_animation_clock_demand(document)
	mut computer := css.css_style_computer_for(document)
	document.needs_animated_style_update = false
	computer.set_animation_time_ms(250)
	assert document.needs_animated_style_update == disable_github_animation_wakeup_throttling
	mut nav := document.get_element_by_id('nav')?
	before := css.computed_properties_for_element(nav)?.property(.opacity,.yes)?.css_text
	nav.set_scroll_top(40)
	document.needs_animated_style_update = false
	computer.set_animation_time_ms(500)
	assert document.needs_animated_style_update
	document.update_layout(.debugging)
	after := css.computed_properties_for_element(nav)?.property(.opacity,.yes)?.css_text
	assert after != before
}
