module devtools

fn test_parse_declarations_respects_strings_functions_and_priority() {
	declarations := parse_declarations('color: Red;  background: url("a;b.png") no-repeat ; MARGIN: 0 !important; --Gap: calc(1px + 2px); bogus;')
	assert declarations.map(it.name) == ['color', 'background', 'margin', '--Gap']
	assert declarations[1].value == 'url("a;b.png") no-repeat'
	assert declarations[2].value == '0' && declarations[2].important
	assert declarations[3].value == 'calc(1px + 2px)'
	assert serialize_declarations(declarations) == 'color: Red; background: url("a;b.png") no-repeat; margin: 0 !important; --Gap: calc(1px + 2px);'
}

fn test_with_declaration_sets_appends_and_removes() {
	base := parse_declarations('color: red; padding: 1px')
	assert serialize_declarations(with_declaration(base, 'COLOR', 'blue !important')) == 'color: blue !important; padding: 1px;'
	assert serialize_declarations(with_declaration(base, 'margin', '4px')) == 'color: red; padding: 1px; margin: 4px;'
	assert serialize_declarations(with_declaration(base, 'color', '  ')) == 'padding: 1px;'
}

fn test_mark_overridden_follows_cascade_and_importance() {
	mut rules := [
		StyleRule{
			origin:       .inline
			declarations: parse_declarations('margin-top: 1px; color: red')
		},
		StyleRule{
			selector:     '#card'
			origin:       .author
			declarations: parse_declarations('margin: 0; color: blue !important; padding: 2px')
		},
		StyleRule{
			selector:     'div'
			origin:       .user_agent
			declarations: parse_declarations('display: block; padding-left: 4px; margin-top: 8px')
		},
	]
	mark_overridden(mut rules)
	overridden := rules.map(it.declarations.map('${it.name}=${it.overridden}'))
	assert overridden[0] == ['margin-top=false', 'color=true']
	// A later shorthand is only partly overridden by an earlier longhand.
	assert overridden[1] == ['margin=false', 'color=false', 'padding=false']
	assert overridden[2] == ['display=false', 'padding-left=true', 'margin-top=true']
	assert rules[0].editable() && rules[1].editable() && !rules[2].editable()
}

fn test_box_edges_and_filtering() {
	assert css_pixels('12.5px') == 12.5
	assert css_pixels('auto') == 0
	assert box_edge(0) == '-'
	assert box_edge(16) == '16'
	assert box_edge(10.333) == '10.33'
	snapshot := StyleSnapshot{
		computed: [ComputedProperty{'color', 'rgb(0, 0, 0)'}, ComputedProperty{'display', 'block'},
			ComputedProperty{'margin-top', '8px'}]
	}
	assert snapshot.filtered_computed('MARGIN').map(it.name) == ['margin-top']
	assert snapshot.filtered_computed('block').map(it.name) == ['display']
	assert snapshot.filtered_computed(' ').len == 3
}

fn test_console_imports_messages_and_walks_history() {
	mut tools := &DevTools{}
	assert tools.import_console(['hello', 'JavaScript: ReferenceError: x'])
	assert tools.console.map(it.kind) == [ConsoleKind.log, .error]
	assert !tools.import_console(['hello', 'JavaScript: ReferenceError: x'])
	assert tools.import_console(['hello', 'JavaScript: ReferenceError: x', 'more'])
	assert tools.console.len == 3 && tools.console[2].text == 'more'
	// The host starts a new list with each document.
	assert tools.import_console(['fresh'])
	assert tools.console.last().text == 'fresh'
	tools.clear_console()
	assert tools.console.len == 0
	assert tools.history_step(true) == none
	tools.remember_input('1 + 1')
	tools.remember_input('document.title')
	tools.remember_input('document.title')
	assert tools.console_history == ['1 + 1', 'document.title']
	assert tools.history_step(true) or { '' } == 'document.title'
	assert tools.history_step(true) or { '' } == '1 + 1'
	assert tools.history_step(true) or { '' } == '1 + 1'
	assert tools.history_step(false) or { '' } == 'document.title'
	assert tools.history_step(false) or { 'x' } == ''
}

fn test_console_expression_quotes_input_and_counts_wrapped_lines() {
	assert js_string('a"b\\c\nd ') == '"a\\"b\\\\c\\nd\\u2028"'
	assert js_string('\x01') == '"\\u0001"'
	expression := console_expression('var x = "y";')
	assert expression.ends_with('((0, eval)("var x = \\"y\\";"))')
	assert expression.starts_with('(function (value) {')
	assert console_line_count('', 10) == 1
	assert console_line_count('abcdefghijk', 10) == 2
	assert console_line_count('a\nb\nc', 10) == 3
	assert console_line_count('x'.repeat(10000), 10) == 40
}

fn test_console_errors_drop_the_wrapper_frames() {
	assert clean_console_error('Uncaught ReferenceError: x\neval code@\neval@[native code]\nglobal code@') == 'Uncaught ReferenceError: x'
	assert clean_console_error('Uncaught Error: y\nthrower@https://a.example/app.js:3:9\neval code@') == 'Uncaught Error: y\nthrower@https://a.example/app.js:3:9'
}
