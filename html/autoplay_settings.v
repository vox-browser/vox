// Copyright (c) 2026-present, the Ladybird developers
// SPDX-License-Identifier: BSD-2-Clause

// Translation of HTML/Autoplay{Policy,Settings}.{h,cpp}.
@[has_globals]
module html

import dom
import platform

__global html_autoplay_settings &AutoplaySettings

pub enum AutoplayPolicy {
	allow_audio_and_video
	block_audio
	block_audio_and_video
}

pub enum AutoplayDecision {
	allowed
	allowed_if_inaudible
	blocked
}

pub fn autoplay_policy_from_string(value string) ?AutoplayPolicy {
	return match value {
		'allow-audio-and-video' { .allow_audio_and_video }
		'block-audio' { .block_audio }
		'block-audio-and-video' { .block_audio_and_video }
		else { none }
	}
}

pub fn autoplay_policy_to_string(policy AutoplayPolicy) string {
	return match policy {
		.allow_audio_and_video { 'allow-audio-and-video' }
		.block_audio { 'block-audio' }
		.block_audio_and_video { 'block-audio-and-video' }
	}
}

@[heap]
pub struct AutoplaySettings {
mut:
	policy_    AutoplayPolicy = .block_audio
	allowlist_ []dom.Origin
}

pub fn AutoplaySettings.the() &AutoplaySettings {
	if html_autoplay_settings == unsafe { nil } {
		// The first media query usually runs inside a document arena; the
		// process-wide settings must not live there.
		persistent := platform.enter_persistent()
		html_autoplay_settings = &AutoplaySettings{}
		platform.leave_persistent(persistent)
	}
	return html_autoplay_settings
}

pub fn (settings &AutoplaySettings) policy() AutoplayPolicy {
	return settings.policy_
}

pub fn (settings &AutoplaySettings) allowlist() []dom.Origin {
	return settings.allowlist_.clone()
}

pub fn (settings &AutoplaySettings) decision_for_origin(document &dom.Document, origin dom.Origin) AutoplayDecision {
	for allowed in settings.allowlist_ {
		if allowed.is_same_origin_domain(origin) {
			return .allowed
		}
	}
	if origin.is_opaque_file_origin() && document.origin().is_opaque_file_origin() {
		return .allowed
	}
	return match settings.policy_ {
		.allow_audio_and_video { .allowed }
		.block_audio { .allowed_if_inaudible }
		.block_audio_and_video { .blocked }
	}
}

pub fn (mut settings AutoplaySettings) set_policy(policy AutoplayPolicy, allowlist []string) {
	persistent := platform.enter_persistent()
	defer { platform.leave_persistent(persistent) }
	settings.policy_ = policy
	settings.allowlist_.clear()
	for entry in allowlist {
		mut url := dom.dom_url_parse(entry, dom.url_about_blank(), 'UTF-8') or {
			dom.dom_url_parse('https://${entry}', dom.url_about_blank(), 'UTF-8') or {
				continue
			}
		}
		settings.allowlist_ << url.origin()
	}
}
