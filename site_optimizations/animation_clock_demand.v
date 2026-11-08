module main

import css
import dom
import html
import platform

fn configure_site_animation_clock_demand(document &dom.Document) {
	if disable_github_animation_wakeup_throttling
		|| !site_batches_image_completion_layout(document.url.serialize()) { return }
	css.set_document_animation_clock_demand_filter(document, site_animation_clock_demands_style)
	css.set_document_animation_clock_reader(document, html.document_animation_clock_now)
}

fn site_animation_clock_demands_style(document &dom.Document, time_ms f64) bool {
	if disable_github_animation_wakeup_throttling
		|| !site_batches_image_completion_layout(document.url.serialize())
		|| !document.layout_is_up_to_date() { return true }
	workspace := platform.begin_thread_scratch('site animation clock demand')
	records := css.document_css_animations(document)
	workspace.leave()
	defer { workspace.finish() }
	for record in records {
		if record.is_transition { return true }
		animation := unsafe { &css.CSSAnimation(record.handle) }
		if animation.needs_style_sample_from_clock(time_ms) { return true }
	}
	if site_has_relevant_web_animation(document) { return true }
	if github_animation_wakeup_diagnostics { eprintln('Vox site animation demand: idle clock tick') }
	return false
}
