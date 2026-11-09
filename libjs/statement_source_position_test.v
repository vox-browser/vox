module libjs

fn test_assignment_source_positions_preserve_calls_and_utf16_columns() {
	source := parse_source('call(async () => {\n    target.innerHTML = "value"; other.value = 1;\n    if (ok) {\n      target.textContent = "other";\n    }\n});', .script)
	line, column := source.assignment_target_start_at(2, 11)?
	assert line == 2 && column == 5, '${line}:${column}\n${source.dump_ast()!}'
	other_line, other_column := source.assignment_target_start_at(2, 39)?
	assert other_line == 2 && other_column == 33
	nested_line, nested_column := source.assignment_target_start_at(4, 13)?
	assert nested_line == 4 && nested_column == 7
	unicode := parse_source('"😀"; target.value = 1;', .script)
	unicode_line, unicode_column := unicode.assignment_target_start_at(1, 13)?
	assert unicode_line == 1 && unicode_column == 7, '${unicode_line}:${unicode_column}\n${unicode.dump_ast()!}'
	assert source.assignment_target_start_at(99, 1) == none
	assert source.assignment_target_start_at(2, 25) == none
	assert parse_source('target.setAttribute("style", "");', .script).assignment_target_start_at(1, 7) == none
	assert parse_source('let invalid = ;', .script).assignment_target_start_at(1, 5) == none
}
