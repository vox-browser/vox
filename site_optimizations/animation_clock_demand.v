module main

import css
import dom
import platform

fn configure_site_animation_clock_demand(document &dom.Document) {
	if disable_github_animation_wakeup_throttling
		|| !site_batches_image_completion_layout(document.url.serialize()) { return }
	css.set_document_animation_clock_demand_filter(document, site_animation_clock_demands_style)
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
	if hook := document.animations_hook_ {
		if hook.effect_targets != unsafe { nil } && hook.effect_targets(hook.target).len > 0 {
			if hook.calculate_get_animations == unsafe { nil } { return true }
			relevant := hook.calculate_get_animations(hook.target, document.as_node()) or { return true }
			for animation in relevant {
				if animation.concrete_kind_ == .web_animation { return true }
			}
		}
	}
	if github_animation_wakeup_diagnostics { eprintln('Vox site animation demand: idle clock tick') }
	return false
}
