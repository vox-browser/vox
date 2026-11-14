// SPDX-License-Identifier: BSD-2-Clause
module libjs

fn test_strict_reserved_bindings_reject_only_exact_decoded_grammar_names() {
	for name in ['implements', 'interface', 'let', 'package', 'private', 'protected',
		'public', 'static', 'yield'] {
		assert parse_source('"use strict";var ${name};', .script).has_errors(), name
		assert !parse_source('var ${name};', .script).has_errors(), name
		for ordinary in ['${name}x', 'x${name}', name.to_upper()] {
			assert !parse_source('"use strict";var ${ordinary};', .script).has_errors(), ordinary
		}
	}
	assert parse_source(r'"use strict";var \u0069nterface;', .script).has_errors()
	assert !parse_source('"use strict";var interfáce,𝒑ublic;', .script).has_errors()
}
