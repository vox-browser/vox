module main

import css
import dom
import os
import platform

const disable_github_animation_wakeup_throttling = os.getenv('VOX_DISABLE_GITHUB_ANIMATION_WAKEUP_THROTTLING') != ''
const github_animation_wakeup_diagnostics = os.getenv('VOX_GITHUB_ANIMATION_WAKEUP_DIAGNOSTICS') != ''

fn (app &BrowserApp) site_animation_wakeup_delay_for_frame() int {
	if app.document == unsafe { nil } { return 16 }
	return site_animation_wakeup_delay(app.document)
}

fn site_animation_wakeup_fallback(reason string) int {
	if github_animation_wakeup_diagnostics {
		eprintln('Vox site animation wakeup: keep_ms=16 reason=${reason}')
	}
	return 16
}

// Native display grants follow effects that can advance with wall time.
// Input and script tasks still grant rendering opportunities, and HTML retains
// timeline sampling and event delivery. Completed effects can remain registered.
fn site_animation_wakeup_delay(document &dom.Document) int {
	if disable_github_animation_wakeup_throttling
		|| !site_batches_image_completion_layout(document.url.serialize()) { return 16 }
	if !document.layout_is_up_to_date() { return site_animation_wakeup_fallback('pending layout') }
	workspace := platform.begin_thread_scratch('site animation wakeups')
	records := css.document_css_animations(document)
	workspace.leave()
	defer { workspace.finish() }
	for record in records {
		if record.play_state != 'running' { continue }
		if record.is_transition { return site_animation_wakeup_fallback('CSS transition') }
		animation := unsafe { &css.CSSAnimation(record.handle) }
		if timeline := animation.timeline_ {
			if timeline.kind == .scroll { continue }
		}
		current := css.document_css_animation_current_time(document, record.handle) or { return 16 }
		if animation.needs_style_sample_from_clock(current + animation.start_time_) {
			return site_animation_wakeup_fallback('active CSS effect: ${record.name}')
		}
	}
	if site_has_relevant_web_animation(document) { return site_animation_wakeup_fallback('Web Animation effect') }
	if github_animation_wakeup_diagnostics { eprintln('Vox site animation wakeup: delay_ms=-1') }
	return -1
}

fn site_has_relevant_web_animation(document &dom.Document) bool {
	if hook := document.animations_hook_ {
		if hook.effect_targets != unsafe { nil } && hook.effect_targets(hook.target).len > 0 {
			if hook.calculate_get_animations == unsafe { nil } { return true }
			relevant := hook.calculate_get_animations(hook.target, document.as_node()) or { return true }
			for animation in relevant {
				if animation.concrete_kind_ == .web_animation { return true }
			}
		}
	}
	return false
}
