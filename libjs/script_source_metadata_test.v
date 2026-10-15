module libjs

fn test_script_source_metadata_finds_only_exact_directives_in_the_prologue() {
	for source in [
		'"use strict";',
		"'use strict'",
		'"first directive"; "use strict"; var x=1;',
		'"first directive"\n"use strict"\nvar x=1;',
		'/* header */ "use strict" /* trailing comment */;',
		'// header\n"use strict"// comment\nvar x=1;',
		'"first directive"/* a\ncomment */"use strict";',
		'\ufeff\u00a0\u2003"use strict"\u2028var x=1;',
		'#!/usr/bin/env node\n"use strict"; var x=1;',
		'<!-- browser script comment\n"use strict";',
		'"use strict"\n++counter;',
		'"use strict"\n--counter;',
	] {
		assert script_source_is_strict(source), source
	}
	for source in [
		'',
		'/* comment */',
		'var x=1; "use strict";',
		';"use strict";',
		'("use strict");',
		'`use strict`;',
		'"Use strict";',
		r'"use\x20strict";',
		r'"use\u0020strict";',
		'"first directive";;"use strict";',
		'function nested(){"use strict";}',
		'"first" + "second"; "use strict";',
	] {
		assert !script_source_is_strict(source), source
	}
}

fn test_script_source_metadata_rejects_literal_expression_continuations_across_lines() {
	for continuation in [
		'(function(){})();',
		'[0];',
		'.length;',
		'?.length;',
		'`tagged`;',
		'+ 1;',
		'- 1;',
		'* 2;',
		'/ 2;',
		'% 2;',
		'** 2;',
		'<< 1;',
		'>> 1;',
		'>>> 1;',
		'< "z";',
		'<= "z";',
		'> "z";',
		'>= "z";',
		'== "z";',
		'=== "z";',
		'!= "z";',
		'!== "z";',
		'in Object("key");',
		'instanceof String;',
		'& 1;',
		'| 1;',
		'^ 1;',
		'&& true;',
		'|| true;',
		'?? true;',
		'? 1 : 2;',
		', 1;',
	] {
		for separator in ['\n', '/* line\ncomment */'] {
			source := '"use strict"${separator}${continuation}'
			assert !script_source_is_strict(source), source
		}
	}
	assert !script_source_is_strict('"first"\n[0]; "use strict";')
	assert !script_source_is_strict('"first"\n+ 1; "use strict";')
}

fn test_script_source_metadata_stops_before_parsing_a_large_non_directive_program() {
	// The suffix is deliberately outside the translated parser's recursion
	// budget and ultimately invalid. Metadata discovery has no reason to scan
	// or diagnose it after the first non-string token.
	large := 'var first=1;' + '('.repeat(100000) + 'not a complete program'
	assert !script_source_is_strict(large)
	assert script_source_is_strict('"use strict";' + large)
}
