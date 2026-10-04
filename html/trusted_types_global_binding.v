// TrustedTypePolicyFactory queries its owning global's current CSP list.
module html

import trustedtypes

fn global_scope_trusted_types_policies(scope &WindowOrWorkerGlobalScopeMixin) []trustedtypes.TrustedTypesCSPPolicy {
	mut result := []trustedtypes.TrustedTypesCSPPolicy{}
	if realm := scope.error_reporting_realm_ {
		if realm.settings_handle != unsafe { nil } {
			settings := unsafe { &EnvironmentSettingsObject(realm.settings_handle) }
			for policy in settings.policy_container().csp_list {
				mut names := ?[]string(none)
				mut sinks := []string{}
				for directive in policy.directives {
					match directive.name.to_lower() {
						'trusted-types' { names = directive.value.clone() }
						'require-trusted-types-for' { sinks = directive.value.clone() }
						else {}
					}
				}
				result << trustedtypes.TrustedTypesCSPPolicy{
					disposition:               if policy.disposition == .enforce {
						trustedtypes.CSPDisposition.enforce
					} else {
						trustedtypes.CSPDisposition.report_only
					}
					trusted_types:             names
					require_trusted_types_for: sinks
				}
			}
			// TrustedTypePolicyFactory.cpp:245–246 uses this one actual list.
			return result
		}
	}
	if window := scope.associated_window_ {
		result << trusted_types_meta_policies(window.associated_document())
	}
	return result
}
