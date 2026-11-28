module libjs

import os

$if test {
	// Fresh-process benchmark controls, with no production setting. Public test
	// setters remain authoritative when this environment variable is absent.
	fn configure_optimization_control_for_testing() {
		for optimization in os.getenv('VOX_LIBJS_TEST_DISABLE_OPTIMIZATION').split(',') {
			match optimization {
				'' {}
				'regexp-flags' { set_intrinsic_regexp_flags_for_testing(false) }
				'declarative-reads' { set_direct_declarative_reads_for_testing(false) }
				'regex-suffix-starts' { set_regex_suffix_starts_for_testing(false) }
				'small-property-hints' { set_small_property_hints_for_testing(false) }
				'indexed-properties' { set_indexed_properties_for_testing(false) }
				'string-key-scans' { set_string_key_scans_for_testing(false) }
				'direct-frame-clears' { set_direct_frame_clears_for_testing(false) }
				'direct-call-bindings' { set_direct_call_bindings_for_testing(false) }
				'regexp-test-results' { set_regexp_test_results_for_testing(false) }
				'regexp-empty-replacements' { set_empty_regexp_replacements_for_testing(false) }
				'validation-arity' { set_validation_arity_for_testing(false) }
				'compiler-validation' { set_compiler_validation_for_testing(false) }
				'prototype-lookups' { set_indexed_prototype_lookups_for_testing(false) }
				'register-call-metadata' { set_register_call_metadata_for_testing(false) }
				'native-cache-digests' { set_native_cache_digests_for_testing(false) }
				'native-binding-reads' { set_native_binding_reads_for_testing(false) }
				'native-key-encoding' { set_native_key_encoding_for_testing(false) }
				else { panic('Unknown LibJS test optimization control') }
			}
		}
	}
}
