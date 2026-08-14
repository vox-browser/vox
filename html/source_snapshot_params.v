// Copyright (c) 2023, Aliaksandr Kalenik <kalenik.aliaksandr@gmail.com>
// Copyright (c) 2025, Luke Wilde <luke@ladybird.org>
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of Libraries/LibWeb/HTML/SourceSnapshotParams.h/.cpp.
// A GC::Cell data holder; visit_edges is GC-only and out of scope for this port.
// https://html.spec.whatwg.org/multipage/browsing-the-web.html#source-snapshot-params
module html

pub struct SourceSnapshotParams {
pub:
	// a boolean
	has_transient_activation bool
	// a sandboxing flag set
	sandboxing_flags SandboxingFlagSet
	// a boolean
	allows_downloading bool
	// An environment settings object, only used as a request client. EnvironmentSettingsObject is
	// not translated in this port, so it is held opaquely.
	fetch_client voidptr = unsafe { nil }
	// a policy container
	source_policy_container PolicyContainer
}
