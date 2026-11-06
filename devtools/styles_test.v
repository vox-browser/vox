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
