// Copyright (c) 2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause

// CSP consumes HTML's parse-a-sandboxing-directive output. These typed flags
// mirror HTML::SandboxingFlagSet at the module boundary and avoid a CSP -> HTML
// module dependency cycle in embedders.
module contentsecuritypolicy

pub enum SandboxingFlag as u32 {
	sandboxed_navigation                                   = 1
	sandboxed_auxiliary_navigation                         = 2
	sandboxed_top_level_navigation_without_user_activation = 4
	sandboxed_top_level_navigation_with_user_activation    = 8
	sandboxed_plugins                                      = 16
	sandboxed_origin                                       = 32
	sandboxed_forms                                        = 64
	sandboxed_pointer_lock                                 = 128
	sandboxed_scripts                                      = 256
	sandboxed_automatic_features                           = 512
	sandboxed_document_domain                              = 1024
	sandbox_propagates_to_auxiliary_browsing_contexts      = 2048
	sandboxed_modals                                       = 4096
	sandboxed_orientation_lock                             = 8192
	sandboxed_presentation                                 = 16384
	sandboxed_downloads                                    = 32768
	sandboxed_custom_protocols                             = 65536
}

pub struct SandboxingFlagSet {
pub:
	bits u32
}

pub fn (flags SandboxingFlagSet) contains(flag SandboxingFlag) bool {
	return flags.bits & u32(flag) != 0
}

pub fn (flags SandboxingFlagSet) is_empty() bool {
	return flags.bits == 0
}

fn (mut flags SandboxingFlagSet) add(flag SandboxingFlag) {
	flags = SandboxingFlagSet{
		bits: flags.bits | u32(flag)
	}
}

pub fn parse_a_sandboxing_directive(input []string) SandboxingFlagSet {
	tokens := input.map(it.to_lower())
	mut output := SandboxingFlagSet{}
	output.add(.sandboxed_navigation)
	if 'allow-popups' !in tokens { output.add(.sandboxed_auxiliary_navigation) }
	if 'allow-top-navigation' !in tokens {
		output.add(.sandboxed_top_level_navigation_without_user_activation)
	}
	if 'allow-top-navigation' !in tokens && 'allow-top-navigation-by-user-activation' !in tokens {
		output.add(.sandboxed_top_level_navigation_with_user_activation)
	}
	if 'allow-same-origin' !in tokens { output.add(.sandboxed_origin) }
	if 'allow-forms' !in tokens { output.add(.sandboxed_forms) }
	if 'allow-pointer-lock' !in tokens { output.add(.sandboxed_pointer_lock) }
	if 'allow-scripts' !in tokens {
		output.add(.sandboxed_scripts)
		output.add(.sandboxed_automatic_features)
	}
	output.add(.sandboxed_document_domain)
	if 'allow-popups-to-escape-sandbox' !in tokens {
		output.add(.sandbox_propagates_to_auxiliary_browsing_contexts)
	}
	if 'allow-modals' !in tokens { output.add(.sandboxed_modals) }
	if 'allow-orientation-lock' !in tokens { output.add(.sandboxed_orientation_lock) }
	if 'allow-presentation' !in tokens { output.add(.sandboxed_presentation) }
	if 'allow-downloads' !in tokens { output.add(.sandboxed_downloads) }
	if 'allow-top-navigation-to-custom-protocols' !in tokens && 'allow-popups' !in tokens
		&& 'allow-top-navigation' !in tokens {
		output.add(.sandboxed_custom_protocols)
	}
	return output
}
