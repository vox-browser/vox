// Copyright (c) 2023, Aliaksandr Kalenik <kalenik.aliaksandr@gmail.com>
// Copyright (c) 2025, Luke Wilde <luke@ladybird.org>
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of Libraries/LibWeb/HTML/SourceSnapshotParams.h/.cpp.
// A GC::Cell data holder; visit_edges is GC-only and out of scope for this port.
// https://html.spec.whatwg.org/multipage/browsing-the-web.html#source-snapshot-params
module html

import dom

// SourceSnapshotParams.h stores this pointer-retained record as a GC::Cell.
@[heap]
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
// Translation of HTML::snapshot_source_snapshot_params(Document*).
// The HTML side reads the actual DOM Document through V's acyclic module graph.
pub fn snapshot_source_snapshot_params(source_document &dom.Document) SourceSnapshotParams {
	if source_document == unsafe { nil } {
		return SourceSnapshotParams{
			has_transient_activation: true
			allows_downloading: true
			source_policy_container: dom.PolicyContainer{}
		}
	}
	flags := SandboxingFlagSet{
		bits: source_document.active_sandboxing_flag_bits()
	}
	settings_pointer := source_document.relevant_settings_object()
	if settings_pointer == unsafe { nil } {
		return SourceSnapshotParams{
			sandboxing_flags: flags
			allows_downloading: !flags.contains(.sandboxed_downloads)
			source_policy_container: dom.PolicyContainer{}
		}
	}
	settings := unsafe { &EnvironmentSettingsObject(settings_pointer) }
	return SourceSnapshotParams{
		has_transient_activation: settings.has_transient_activation()
		sandboxing_flags: flags
		allows_downloading: !flags.contains(.sandboxed_downloads)
		fetch_client: settings
		// SourceSnapshotParams.cpp:63 clones this Document's own container;
		// its relevant Window/settings may currently name another Document.
		source_policy_container: source_document.policy_container().clone()
	}
}
