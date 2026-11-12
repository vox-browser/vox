module browserui

import os

fn save_locale() (?string, ?string) {
	return os.getenv_opt('VOX_LANG'), os.getenv_opt('LANG')
}

fn restore_locale(saved ?string, other ?string) {
	if v := saved {
		os.setenv('VOX_LANG', v, true)
	} else {
		os.unsetenv('VOX_LANG')
	}
	if v := other {
		os.setenv('LANG', v, true)
	} else {
		os.unsetenv('LANG')
	}
}

fn test_locale_registry_lists_english_by_default() {
	assert default_locale() == 'en'
	assert supported_locales() == ['en']
	assert tr_for('en', 'nav.back') == 'Back'
}

fn test_locale_tables_cover_every_chrome_key() {
	for key, en in en_chrome_strings {
		assert en != '', 'empty en string for ${key}'
	}
	assert en_chrome_strings.len == 68
}

fn test_locale_normalizes_codes() {
	assert normalize_locale_code('en') == 'en'
	assert normalize_locale_code('EN_us.UTF-8') == 'en'
	assert normalize_locale_code('FA-ir') == 'fa'
	assert normalize_locale_code('fa_IR.UTF-8') == 'fa'
	assert normalize_locale_code('') == ''
	assert normalize_locale_code('  ') == ''
}

fn test_locale_falls_back_to_english() {
	assert tr_for('de', 'nav.back') == 'Back'
	assert tr_for('', 'nav.back') == 'Back'
	assert tr_for('fa', 'nav.back') == 'Back'
	assert tr_for('en', 'no.such.key') == 'no.such.key'
	assert tr_for('de', 'no.such.key') == 'no.such.key'
}

fn test_locale_prefers_vox_lang_over_lang() {
	old_vox, old_lang := save_locale()
	defer { restore_locale(old_vox, old_lang) }
	os.setenv('VOX_LANG', 'en', true)
	os.setenv('LANG', 'de_DE.UTF-8', true)
	assert ui_locale() == 'en'
	assert tr('nav.reload') == 'Reload'
}

fn test_locale_reads_lang_when_vox_lang_absent() {
	old_vox, old_lang := save_locale()
	defer { restore_locale(old_vox, old_lang) }
	os.unsetenv('VOX_LANG')
	os.setenv('LANG', 'en_US.UTF-8', true)
	assert ui_locale() == 'en'
	assert tr('menu.history') == 'History'
}

fn test_locale_defaults_to_english() {
	old_vox, old_lang := save_locale()
	defer { restore_locale(old_vox, old_lang) }
	os.setenv('VOX_LANG', 'xx', true)
	os.setenv('LANG', 'yy_ZZ.UTF-8', true)
	assert ui_locale() == 'en'
	assert tr('nav.reload') == 'Reload'
}

fn test_trf_substitutes_placeholders() {
	assert trf_for('en', 'find.status', {
		'current': '2'
		'total':   '5'
	}) == '2 of 5'
	assert trf_for('en', 'update.version', {
		'latest':  '0.2'
		'current': '0.1'
	}) == 'Version 0.2 is available (installed: 0.1).'
	assert trf_for('de', 'tab.close', {
		'title': 'example.com'
	}) == 'Close example.com'
	assert trf_for('en', 'no.such.key', {
		'title': 'x'
	}) == 'no.such.key'
}

fn test_format_digits_defaults_to_identity() {
	assert format_digits('en', '0123456789') == '0123456789'
	assert format_digits('de', 'v1080p 60fps') == 'v1080p 60fps'
	assert format_digits('en', '') == ''
}

fn set_test_locale(vox string) (?string, ?string) {
	old_vox, old_lang := save_locale()
	os.setenv('VOX_LANG', vox, true)
	os.setenv('LANG', 'en_US.UTF-8', true)
	return old_vox, old_lang
}

fn test_find_status_text() {
	old_vox, old_lang := set_test_locale('en')
	defer { restore_locale(old_vox, old_lang) }
	assert find_status_text('', false, 0, 0) == ''
	assert find_status_text('q', false, 0, 5) == ''
	assert find_status_text('q', true, 0, 5) == '0 of 5'
	assert find_status_text('q', true, 0, 0) == 'Not found'
	assert find_status_text('q', true, 2, 5) == '2 of 5'
}

fn test_update_version_text() {
	old_vox, old_lang := set_test_locale('en')
	defer { restore_locale(old_vox, old_lang) }
	assert update_version_text('0.2', '0.1') == 'Version 0.2 is available (installed: 0.1).'
}

fn test_window_controls_text() {
	old_vox, old_lang := set_test_locale('en')
	defer { restore_locale(old_vox, old_lang) }
	assert window_button_text('close') == 'close window'
	assert window_button_text('minimize') == 'minimize window'
	assert close_tab_text('example.com') == 'Close example.com'
	assert tab_color_text('red') == 'Red'
	assert tab_color_text('none') == 'tab.color.none'
}
