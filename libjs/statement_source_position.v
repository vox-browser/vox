module libjs

// Map a native bytecode position in an assignment target (such as the dot in a
// property store) to that target's first authored token. Calls and other
// instruction positions retain their native coordinates. Inputs and outputs
// use one-based UTF-16 columns, independently of the UTF-8 source storage.
pub fn (source &ParsedSource) assignment_target_start_at(line u32, column u32) ?(u32, u32) {
	if source.has_errors() || source.reached_recursion_limit || line == 0 || column == 0 { return none }
	lines := source.source_text.replace('\r\n', '\n').replace('\r', '\n')
		.replace('\u2028', '\n').replace('\u2029', '\n').split('\n')
	if line > u32(lines.len) { return none }
	parser_column := utf16_to_parser_column(lines[line - 1], column) or { return none }
	point := Position{line: line, column: parser_column}
	mut match_ := StatementSourceMatch{}
	find_statement_source_position(&source.program, point, mut match_)
	for entry in source.function_table.entries {
		if function := entry {
			find_statement_source_position(&function.body, point, mut match_)
		}
	}
	if !match_.found { return none }
	start := match_.range.start
	return start.line, parser_to_utf16_column(lines[start.line - 1], start.column)
}

fn utf16_to_parser_column(text string, column u32) ?u32 {
	mut units := u32(1)
	mut characters := u32(1)
	for character in text.runes() {
		if units == column { return characters }
		units += if character > 0xffff { u32(2) } else { u32(1) }
		characters++
	}
	if units == column { return characters }
	return none
}

fn parser_to_utf16_column(text string, column u32) u32 {
	mut units := u32(1)
	for index, character in text.runes() {
		if u32(index) + 1 >= column { break }
		units += if character > 0xffff { u32(2) } else { u32(1) }
	}
	return units
}

struct StatementSourceMatch {
mut:
	found bool
	range SourceRange
}

fn source_position_precedes(left Position, right Position) bool {
	return left.line < right.line || (left.line == right.line && left.column < right.column)
}

fn find_statement_source_position(statement &Statement, point Position, mut match_ StatementSourceMatch) {
	if source_position_precedes(point, statement.range.start)
		|| !source_position_precedes(point, statement.range.end_) { return }
	if expression := statement.kind.expression {
		if range := assignment_target_range_at(expression, point) {
			if !match_.found || range.end_.offset - range.start.offset
				< match_.range.end_.offset - match_.range.start.offset {
				match_.found = true
				match_.range = range
			}
		}
	}
	if scope := statement.kind.scope {
		for child in scope.children { find_statement_source_position(&child, point, mut match_) }
	}
	if program := statement.kind.program_data {
		for child in program.scope.children { find_statement_source_position(&child, point, mut match_) }
	}
	if child := statement.kind.body { find_statement_source_position(child, point, mut match_) }
	if child := statement.kind.consequent { find_statement_source_position(child, point, mut match_) }
	if child := statement.kind.alternate { find_statement_source_position(child, point, mut match_) }
	if child := statement.kind.labelled_item { find_statement_source_position(child, point, mut match_) }
	if data := statement.kind.try_data {
		find_statement_source_position(&data.block, point, mut match_)
		if handler := data.handler { find_statement_source_position(&handler.body, point, mut match_) }
		if finalizer := data.finalizer { find_statement_source_position(&finalizer, point, mut match_) }
	}
	if data := statement.kind.switch_data {
		for case_ in data.cases {
			for child in case_.scope.children { find_statement_source_position(&child, point, mut match_) }
		}
	}
	if data := statement.kind.export_data {
		if child := data.statement { find_statement_source_position(child, point, mut match_) }
	}
}

fn assignment_target_range_at(expression &Expression, point Position) ?SourceRange {
	if expression.kind.tag != .assignment { return none }
	lhs := expression.kind.assignment_lhs or { return none }
	if lhs !is AssignmentLhsExpression { return none }
	target := lhs.expression
	if source_position_precedes(point, target.range.start)
		|| !source_position_precedes(point, target.range.end_) { return none }
	mut base := target
	for base.kind.tag == .member {
		base = base.kind.object or { return none }
	}
	return SourceRange{start: base.range.start, end_: target.range.end_}
}
