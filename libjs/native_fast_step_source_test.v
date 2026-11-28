module libjs

import strings

fn test_native_fast_step_source_preserves_exact_substitutions() {
	for template in [
		'BUDGET',
		'if(!number(v[0])) goto SLOW;\nif(!number(v[1])) goto SLOW;\nBUDGET v[2]=num(v[0].number+v[1].number);',
		'BUDGETSLOWSLOWBUDGET',
		'BUDGESLO',
		'',
	] {
		for offset in [0, 9, 10, 940, 65535] {
			mut output := strings.new_builder(2)
			output.write_string('prefix\n')
			write_native_fast_step(mut output, template, offset)
			expected := template.replace('SLOW', 'S${offset}').replace('BUDGET', native_fast_budget_check)
			assert output.str() == 'prefix\n${expected}\n'
		}
	}
}
