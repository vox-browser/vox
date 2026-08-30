// Copyright (c) 2024, Luke Wilde <luke@ladybird.org>
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of Libraries/LibWeb/HTML/SandboxingFlagSet.cpp.
module html

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
	return flags.bits & 0x1ff == 0
}

pub fn (flags SandboxingFlagSet) union(other SandboxingFlagSet) SandboxingFlagSet {
	return SandboxingFlagSet{
		bits: flags.bits | other.bits
	}
}

fn (mut flags SandboxingFlagSet) add(flag SandboxingFlag) {
	flags = SandboxingFlagSet{
		bits: flags.bits | u32(flag)
	}
}

pub type SandboxingDirective = []string | string

// https://html.spec.whatwg.org/multipage/browsers.html#parse-a-sandboxing-directive
pub fn parse_a_sandboxing_directive(input SandboxingDirective) SandboxingFlagSet {
	mut tokens := []string{}
	match input {
		string {
			lowercase_input := ascii_lowercase_string(input)
			mut position := 0
			for position < lowercase_input.len {
				for position < lowercase_input.len && is_number_ascii_whitespace(lowercase_input[position]) {
					position++
				}
				start := position
				for position < lowercase_input.len && !is_number_ascii_whitespace(lowercase_input[position]) {
					position++
				}
				if start < position {
					tokens << lowercase_input[start..position]
				}
			}
		}
		[]string {
			for token in input {
				tokens << ascii_lowercase_string(token)
			}
		}
	}

	mut output := SandboxingFlagSet{}
	output.add(.sandboxed_navigation)
	if 'allow-popups' !in tokens {
		output.add(.sandboxed_auxiliary_navigation)
	}
	if 'allow-top-navigation' !in tokens {
		output.add(.sandboxed_top_level_navigation_without_user_activation)
	}
	if 'allow-top-navigation' !in tokens && 'allow-top-navigation-by-user-activation' !in tokens {
		output.add(.sandboxed_top_level_navigation_with_user_activation)
	}
	if 'allow-same-origin' !in tokens {
		output.add(.sandboxed_origin)
	}
	if 'allow-forms' !in tokens {
		output.add(.sandboxed_forms)
	}
	if 'allow-pointer-lock' !in tokens {
		output.add(.sandboxed_pointer_lock)
	}
	if 'allow-scripts' !in tokens {
		output.add(.sandboxed_scripts)
		output.add(.sandboxed_automatic_features)
	}
	output.add(.sandboxed_document_domain)
	if 'allow-popups-to-escape-sandbox' !in tokens {
		output.add(.sandbox_propagates_to_auxiliary_browsing_contexts)
	}
	if 'allow-modals' !in tokens {
		output.add(.sandboxed_modals)
	}
	if 'allow-orientation-lock' !in tokens {
		output.add(.sandboxed_orientation_lock)
	}
	if 'allow-presentation' !in tokens {
		output.add(.sandboxed_presentation)
	}
	if 'allow-downloads' !in tokens {
		output.add(.sandboxed_downloads)
	}
	if 'allow-top-navigation-to-custom-protocols' !in tokens && 'allow-popups' !in tokens && 'allow-top-navigation' !in tokens {
		output.add(.sandboxed_custom_protocols)
	}
	return output
}
