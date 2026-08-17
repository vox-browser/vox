module editing

fn test_all_upstream_command_names_are_exposed() {
	names := all_command_names()
	assert names == [
		'backColor',
		'bold',
		'copy',
		'createLink',
		'cut',
		'defaultParagraphSeparator',
		'delete',
		'fontName',
		'fontSize',
		'foreColor',
		'formatBlock',
		'forwardDelete',
		'hiliteColor',
		'indent',
		'insertHorizontalRule',
		'insertHTML',
		'insertImage',
		'insertLineBreak',
		'insertOrderedList',
		'insertParagraph',
		'insertText',
		'insertUnorderedList',
		'italic',
		'justifyCenter',
		'justifyFull',
		'justifyLeft',
		'justifyRight',
		'outdent',
		'paste',
		'preserveWhitespace',
		'redo',
		'removeFormat',
		'selectAll',
		'strikethrough',
		'styleWithCSS',
		'subscript',
		'superscript',
		'underline',
		'undo',
		'unlink',
		'useCSS',
	]
}

fn test_command_name_lookup_is_ascii_case_insensitive() {
	assert canonical_command_name('BoLd')? == command_bold
	assert canonical_command_name('INSERTunorderedLIST')? == command_insert_unordered_list
	assert canonical_command_name('does-not-exist') == none
	// Upstream comparison folds ASCII only. Unicode case mappings must not turn
	// a non-ASCII command spelling into an ASCII command.
	assert canonical_command_name('bacKColor') == none
	assert find_command_definition('bacKColor') == none
}

fn test_command_definition_table_matches_upstream_action_registry() {
	definitions := command_definitions()
	assert definitions.map(it.command) == [
		command_back_color,
		command_bold,
		command_create_link,
		command_delete,
		command_default_paragraph_separator,
		command_font_name,
		command_font_size,
		command_fore_color,
		command_format_block,
		command_forward_delete,
		command_hilite_color,
		command_indent,
		command_insert_horizontal_rule,
		command_insert_html,
		command_insert_image,
		command_insert_line_break,
		command_insert_ordered_list,
		command_insert_paragraph,
		command_insert_text,
		command_insert_unordered_list,
		command_italic,
		command_justify_center,
		command_justify_full,
		command_justify_left,
		command_justify_right,
		command_outdent,
		command_preserve_whitespace,
		command_remove_format,
		command_select_all,
		command_strikethrough,
		command_style_with_css,
		command_subscript,
		command_superscript,
		command_underline,
		command_unlink,
		command_use_css,
	]
	assert definitions.filter(it.has_action).len == 35
	assert definitions.filter(it.has_state).map(it.command) == [
		command_insert_ordered_list,
		command_insert_unordered_list,
		command_justify_center,
		command_justify_full,
		command_justify_left,
		command_justify_right,
		command_style_with_css,
	]
	assert definitions.filter(it.has_value).map(it.command) == [
		command_default_paragraph_separator,
		command_font_size,
		command_format_block,
		command_justify_center,
		command_justify_full,
		command_justify_left,
		command_justify_right,
	]
	assert definitions.filter(it.has_indeterminate).map(it.command) == [
		command_format_block,
		command_insert_ordered_list,
		command_insert_unordered_list,
		command_justify_center,
		command_justify_full,
		command_justify_left,
		command_justify_right,
		command_subscript,
		command_superscript,
	]
	assert find_command_definition('copy') == none
	assert find_command_definition('undo') == none
	preserve := find_command_definition(command_preserve_whitespace)?
	assert !preserve.has_action
	bold := find_command_definition('BOLD')?
	assert bold.command == command_bold
	assert bold.relevant_css_property == 'font-weight'
	assert bold.inline_activated_values == ['bold', '600', '700', '800', '900']
	assert bold.mapped_value == 'formatBold'
	delete_definition := find_command_definition('delete')?
	assert delete_definition.preserves_overrides
	assert delete_definition.mapped_value == 'deleteContentBackward'
}
