module libjs

enum TokenCategory {
	invalid
	trivia
	number
	string_cat // 'string' is a V keyword
	punctuation
	operator
	keyword
	control_keyword
	identifier_cat
}

enum TokenType {
	ampersand
	ampersand_equals
	arrow
	asterisk
	asterisk_equals
	async
	await_kw // 'await' might conflict
	big_int_literal
	bool_literal
	bracket_close
	bracket_open
	break_kw
	caret
	caret_equals
	case_kw
	catch_kw
	class_kw
	colon
	comma
	const_kw
	continue_kw
	curly_close
	curly_open
	debugger
	default_kw
	delete_kw
	do_kw
	double_ampersand
	double_ampersand_equals
	double_asterisk
	double_asterisk_equals
	double_pipe
	double_pipe_equals
	double_question_mark
	double_question_mark_equals
	else_kw
	enum_kw
	eof
	equals
	equals_equals
	equals_equals_equals
	escaped_keyword
	exclamation_mark
	exclamation_mark_equals
	exclamation_mark_equals_equals
	export_kw
	extends_kw
	finally_kw
	for_kw
	function_kw
	greater_than
	greater_than_equals
	identifier
	if_kw
	implements_kw
	import_kw
	in_kw
	instanceof_kw
	interface_kw
	invalid
	less_than
	less_than_equals
	let_kw
	minus
	minus_equals
	minus_minus
	new_kw
	null_literal
	numeric_literal
	package_kw
	paren_close
	paren_open
	percent
	percent_equals
	period
	pipe
	pipe_equals
	plus
	plus_equals
	plus_plus
	private_kw
	private_identifier
	protected_kw
	public_kw
	question_mark
	question_mark_period
	regex_flags
	regex_literal
	return_kw
	semicolon
	shift_left
	shift_left_equals
	shift_right
	shift_right_equals
	slash
	slash_equals
	static_kw
	string_literal
	super_kw
	switch_kw
	template_literal_end
	template_literal_expr_end
	template_literal_expr_start
	template_literal_start
	template_literal_string
	this_kw
	throw_kw
	tilde
	triple_dot
	trivia
	try_kw
	typeof_kw
	unsigned_shift_right
	unsigned_shift_right_equals
	unterminated_regex_literal
	unterminated_string_literal
	unterminated_template_literal
	var_kw
	void_kw
	while_kw
	with_kw
	yield_kw
}

fn (t TokenType) name() string {
	return match t {
		.ampersand { 'Ampersand' }
		.ampersand_equals { 'AmpersandEquals' }
		.arrow { 'Arrow' }
		.asterisk { 'Asterisk' }
		.asterisk_equals { 'AsteriskEquals' }
		.async { 'Async' }
		.await_kw { 'Await' }
		.big_int_literal { 'BigIntLiteral' }
		.bool_literal { 'BoolLiteral' }
		.bracket_close { 'BracketClose' }
		.bracket_open { 'BracketOpen' }
		.break_kw { 'Break' }
		.caret { 'Caret' }
		.caret_equals { 'CaretEquals' }
		.case_kw { 'Case' }
		.catch_kw { 'Catch' }
		.class_kw { 'Class' }
		.colon { 'Colon' }
		.comma { 'Comma' }
		.const_kw { 'Const' }
		.continue_kw { 'Continue' }
		.curly_close { 'CurlyClose' }
		.curly_open { 'CurlyOpen' }
		.debugger { 'Debugger' }
		.default_kw { 'Default' }
		.delete_kw { 'Delete' }
		.do_kw { 'Do' }
		.double_ampersand { 'DoubleAmpersand' }
		.double_ampersand_equals { 'DoubleAmpersandEquals' }
		.double_asterisk { 'DoubleAsterisk' }
		.double_asterisk_equals { 'DoubleAsteriskEquals' }
		.double_pipe { 'DoublePipe' }
		.double_pipe_equals { 'DoublePipeEquals' }
		.double_question_mark { 'DoubleQuestionMark' }
		.double_question_mark_equals { 'DoubleQuestionMarkEquals' }
		.else_kw { 'Else' }
		.enum_kw { 'Enum' }
		.eof { 'Eof' }
		.equals { 'Equals' }
		.equals_equals { 'EqualsEquals' }
		.equals_equals_equals { 'EqualsEqualsEquals' }
		.escaped_keyword { 'EscapedKeyword' }
		.exclamation_mark { 'ExclamationMark' }
		.exclamation_mark_equals { 'ExclamationMarkEquals' }
		.exclamation_mark_equals_equals { 'ExclamationMarkEqualsEquals' }
		.export_kw { 'Export' }
		.extends_kw { 'Extends' }
		.finally_kw { 'Finally' }
		.for_kw { 'For' }
		.function_kw { 'Function' }
		.greater_than { 'GreaterThan' }
		.greater_than_equals { 'GreaterThanEquals' }
		.identifier { 'Identifier' }
		.if_kw { 'If' }
		.implements_kw { 'Implements' }
		.import_kw { 'Import' }
		.in_kw { 'In' }
		.instanceof_kw { 'Instanceof' }
		.interface_kw { 'Interface' }
		.invalid { 'Invalid' }
		.less_than { 'LessThan' }
		.less_than_equals { 'LessThanEquals' }
		.let_kw { 'Let' }
		.minus { 'Minus' }
		.minus_equals { 'MinusEquals' }
		.minus_minus { 'MinusMinus' }
		.new_kw { 'New' }
		.null_literal { 'NullLiteral' }
		.numeric_literal { 'NumericLiteral' }
		.package_kw { 'Package' }
		.paren_close { 'ParenClose' }
		.paren_open { 'ParenOpen' }
		.percent { 'Percent' }
		.percent_equals { 'PercentEquals' }
		.period { 'Period' }
		.pipe { 'Pipe' }
		.pipe_equals { 'PipeEquals' }
		.plus { 'Plus' }
		.plus_equals { 'PlusEquals' }
		.plus_plus { 'PlusPlus' }
		.private_kw { 'Private' }
		.private_identifier { 'PrivateIdentifier' }
		.protected_kw { 'Protected' }
		.public_kw { 'Public' }
		.question_mark { 'QuestionMark' }
		.question_mark_period { 'QuestionMarkPeriod' }
		.regex_flags { 'RegexFlags' }
		.regex_literal { 'RegexLiteral' }
		.return_kw { 'Return' }
		.semicolon { 'Semicolon' }
		.shift_left { 'ShiftLeft' }
		.shift_left_equals { 'ShiftLeftEquals' }
		.shift_right { 'ShiftRight' }
		.shift_right_equals { 'ShiftRightEquals' }
		.slash { 'Slash' }
		.slash_equals { 'SlashEquals' }
		.static_kw { 'Static' }
		.string_literal { 'StringLiteral' }
		.super_kw { 'Super' }
		.switch_kw { 'Switch' }
		.template_literal_end { 'TemplateLiteralEnd' }
		.template_literal_expr_end { 'TemplateLiteralExprEnd' }
		.template_literal_expr_start { 'TemplateLiteralExprStart' }
		.template_literal_start { 'TemplateLiteralStart' }
		.template_literal_string { 'TemplateLiteralString' }
		.this_kw { 'This' }
		.throw_kw { 'Throw' }
		.tilde { 'Tilde' }
		.triple_dot { 'TripleDot' }
		.trivia { 'Trivia' }
		.try_kw { 'Try' }
		.typeof_kw { 'Typeof' }
		.unsigned_shift_right { 'UnsignedShiftRight' }
		.unsigned_shift_right_equals { 'UnsignedShiftRightEquals' }
		.unterminated_regex_literal { 'UnterminatedRegexLiteral' }
		.unterminated_string_literal { 'UnterminatedStringLiteral' }
		.unterminated_template_literal { 'UnterminatedTemplateLiteral' }
		.var_kw { 'Var' }
		.void_kw { 'Void' }
		.while_kw { 'While' }
		.with_kw { 'With' }
		.yield_kw { 'Yield' }
	}
}

fn (t TokenType) category() TokenCategory {
	return match t {
		.ampersand, .ampersand_equals, .arrow, .asterisk, .asterisk_equals, .caret, .caret_equals,
		.double_ampersand, .double_ampersand_equals, .double_asterisk, .double_asterisk_equals,
		.double_pipe, .double_pipe_equals, .double_question_mark, .double_question_mark_equals,
		.equals, .equals_equals, .equals_equals_equals, .exclamation_mark,
		.exclamation_mark_equals, .exclamation_mark_equals_equals, .greater_than,
		.greater_than_equals, .less_than, .less_than_equals, .minus, .minus_equals, .minus_minus,
		.percent, .percent_equals, .period, .pipe, .pipe_equals, .plus, .plus_equals, .plus_plus,
		.question_mark, .question_mark_period, .shift_left, .shift_left_equals, .shift_right,
		.shift_right_equals, .slash, .slash_equals, .tilde, .triple_dot, .unsigned_shift_right,
		.unsigned_shift_right_equals {
			.operator
		}
		.async, .await_kw, .bool_literal, .class_kw, .const_kw, .debugger, .delete_kw, .enum_kw,
		.export_kw, .extends_kw, .function_kw, .implements_kw, .import_kw, .in_kw, .instanceof_kw,
		.interface_kw, .let_kw, .new_kw, .null_literal, .package_kw, .private_kw, .protected_kw,
		.public_kw, .static_kw, .super_kw, .this_kw, .typeof_kw, .var_kw, .void_kw {
			.keyword
		}
		.break_kw, .case_kw, .catch_kw, .continue_kw, .default_kw, .do_kw, .else_kw, .finally_kw,
		.for_kw, .if_kw, .return_kw, .switch_kw, .throw_kw, .try_kw, .while_kw, .with_kw,
		.yield_kw {
			.control_keyword
		}
		.identifier, .escaped_keyword, .private_identifier {
			.identifier_cat
		}
		.big_int_literal, .numeric_literal {
			.number
		}
		.regex_flags, .regex_literal, .string_literal, .template_literal_end,
		.template_literal_string, .template_literal_start, .unterminated_regex_literal,
		.unterminated_string_literal, .unterminated_template_literal {
			.string_cat
		}
		.bracket_close, .bracket_open, .colon, .comma, .curly_close, .curly_open, .paren_close,
		.paren_open, .semicolon, .template_literal_expr_end, .template_literal_expr_start {
			.punctuation
		}
		.trivia {
			.trivia
		}
		.eof, .invalid {
			.invalid
		}
	}
}

fn (t TokenType) is_identifier_name() bool {
	if t == .private_identifier {
		return false
	}
	cat := t.category()
	return cat == .identifier_cat || cat == .keyword || cat == .control_keyword
}

struct Token {
mut:
	token_type                 TokenType
	trivia_start               u32
	trivia_len                 u32
	value_start                u32
	value_len                  u32
	line_number                u32
	line_column                u32
	offset                     u32
	trivia_has_line_terminator bool
	identifier_value           ?Utf16String
	message                    ?string
}

fn Token.new(tt TokenType) Token {
	return Token{
		token_type: tt
	}
}
