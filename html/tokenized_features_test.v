module html

fn test_tokenize_open_features() {
	features := tokenize_open_features('SCREENX = 10, screenY=20, innerWidth=640, innerHeight=480')
	assert features == {
		'left':   '10'
		'top':    '20'
		'width':  '640'
		'height': '480'
	}

	separators := tokenize_open_features('  popup , toolbar = yes,noopener  ')
	assert separators['popup'] == ''
	assert separators['toolbar'] == 'yes'
	assert separators['noopener'] == ''
}

fn test_parse_boolean_feature() {
	assert parse_boolean_feature('') == .yes
	assert parse_boolean_feature('yes') == .yes
	assert parse_boolean_feature('true') == .yes
	assert parse_boolean_feature('1') == .yes
	assert parse_boolean_feature('-2') == .yes
	assert parse_boolean_feature('0') == .no
	assert parse_boolean_feature('false') == .no
}

fn test_check_if_a_popup_window_is_requested() {
	assert check_if_a_popup_window_is_requested(map[string]string{}) == .no
	assert check_if_a_popup_window_is_requested({
		'popup': 'yes'
	}) == .yes
	assert check_if_a_popup_window_is_requested({
		'popup': '0'
	}) == .no
	assert check_if_a_popup_window_is_requested({
		'location':   'yes'
		'toolbar':    'yes'
		'menubar':    'yes'
		'resizable':  'yes'
		'scrollbars': 'yes'
		'status':     'yes'
	}) == .no
	assert check_if_a_popup_window_is_requested({
		'location': 'yes'
	}) == .yes
}
