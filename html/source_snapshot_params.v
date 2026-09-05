// Copyright (c) 2023, Aliaksandr Kalenik <kalenik.aliaksandr@gmail.com>
// Copyright (c) 2025, Luke Wilde <luke@ladybird.org>
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of Libraries/LibWeb/HTML/SourceSnapshotParams.h/.cpp.
// A GC::Cell data holder; visit_edges is GC-only and out of scope for this port.
// https://html.spec.whatwg.org/multipage/browsing-the-web.html#source-snapshot-params
module html

import dom

pub struct SourceSnapshotParams {
pub:
	// a boolean
	has_transient_activation bool
	// a sandboxing flag set
	sandboxing_flags SandboxingFlagSet
	// a boolean
	allows_downloading bool
	// an environment settings object, only used as a request client
	fetch_client ?&EnvironmentSettingsObject
	// a policy container
	source_policy_container PolicyContainer
}

// https://html.spec.whatwg.org/multipage/browsing-the-web.html#snapshotting-source-snapshot-params
// Translation of DOM::Document::snapshot_source_snapshot_params(). The C++
// method returns an HTML type directly. V's acyclic module graph places the
// implementation on the HTML side of the DOM/HTML bridge instead.
pub fn snapshot_source_snapshot_params(source_document &dom.Document) SourceSnapshotParams {
	flags := SandboxingFlagSet{
		bits: source_document.active_sandboxing_flag_bits()
	}
	settings_pointer := source_document.relevant_settings_object()
	if settings_pointer == unsafe { nil } {
		return SourceSnapshotParams{
			sandboxing_flags: flags
			allows_downloading: !flags.contains(.sandboxed_downloads)
			source_policy_container: PolicyContainer{}
		}
	}
	settings := unsafe { &EnvironmentSettingsObject(settings_pointer) }
	return SourceSnapshotParams{
		has_transient_activation: settings.has_transient_activation()
		sandboxing_flags: flags
		allows_downloading: !flags.contains(.sandboxed_downloads)
		fetch_client: settings
		source_policy_container: settings.policy_container().clone()
	}
}
