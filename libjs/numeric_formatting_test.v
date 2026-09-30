module libjs

import math

fn test_numeric_ast_formatting_uses_ecmascript_decimal_thresholds() {
	cases := {
		'1e20':                    '100000000000000000000'
		'1e21':                    '1e+21'
		'1e-6':                    '0.000001'
		'5e-7':                    '5e-7'
		'0.000035656023101182655': '0.000035656023101182655'
		'0.08424758911132812':     '0.08424758911132812'
		'1000000000000000128':     '1000000000000000100'
		'590295810358705651712':   '590295810358705700000'
		'5e-324':                  '5e-324'
		'1.7976931348623157e308':  '1.7976931348623157e+308'
	}
	for source, expected in cases {
		assert format_f64_value(source.f64()) == expected, source
		assert format_f64_value(-source.f64()) == '-${expected}', source
		parsed := parse_source('${source};', .script)
		ast_text := parsed.dump_ast()!
		assert ast_text.contains('NumericLiteral ${expected} @1:1'), ast_text
	}
}

fn test_numeric_ast_formatting_handles_zero_and_nonfinite_numbers() {
	assert format_f64_value(0) == '0'
	assert format_f64_value(-0.0) == '0'
	assert format_f64_value(math.nan()) == 'NaN'
	assert format_f64_value(math.inf(1)) == 'Infinity'
	assert format_f64_value(math.inf(-1)) == '-Infinity'
}
