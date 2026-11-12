module browserui

import os

fn save_fa_locale() (?string, ?string) {
	return os.getenv_opt('VOX_LANG'), os.getenv_opt('LANG')
}

fn restore_fa_locale(saved ?string, other ?string) {
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

fn set_fa_locale(vox string) (?string, ?string) {
	old_vox, old_lang := save_fa_locale()
	os.setenv('VOX_LANG', vox, true)
	os.setenv('LANG', 'en_US.UTF-8', true)
	return old_vox, old_lang
}

fn test_fa_table_covers_every_chrome_key() {
	assert fa_chrome_strings.len == en_chrome_strings.len
	for key, en in en_chrome_strings {
		assert en != '', 'empty en string for ${key}'
		fa := fa_chrome_strings[key] or { '' }
		assert fa != '', 'missing fa translation for ${key}'
	}
}

fn test_fa_spot_checks() {
	assert tr_for('fa', 'nav.back') == 'قبلی'
	assert tr_for('fa', 'settings.apply') == 'اعمال'
	assert tr_for('fa', 'ctx.inspect') == 'بازرسی'
	assert tr_for('fa', 'address.info') == 'اطلاعات صفحه'
	assert tr_for('fa', 'window.close') == 'بستن پنجره'
}

fn test_fa_locale_selection() {
	old_vox, old_lang := save_fa_locale()
	defer { restore_fa_locale(old_vox, old_lang) }
	os.setenv('VOX_LANG', 'fa', true)
	os.setenv('LANG', 'en_US.UTF-8', true)
	assert ui_locale() == 'fa'
	assert tr('nav.reload') == 'بارگذاری مجدد'
	os.setenv('VOX_LANG', 'FA-ir', true)
	assert ui_locale() == 'fa'
	os.unsetenv('VOX_LANG')
	os.setenv('LANG', 'fa_IR.UTF-8', true)
	assert ui_locale() == 'fa'
	assert tr('menu.history') == 'سابقه'
}

fn test_fa_digits() {
	assert fa_digits('0123456789') == '۰۱۲۳۴۵۶۷۸۹'
	assert fa_digits('v1080p 60fps') == 'v۱۰۸۰p ۶۰fps'
	assert fa_digits('') == ''
	assert fa_digits('سلام') == 'سلام'
}

fn test_find_status_text_fa() {
	old_vox, old_lang := set_fa_locale('fa')
	defer { restore_fa_locale(old_vox, old_lang) }
	assert find_status_text('q', true, 0, 0) == 'یافت نشد'
	assert find_status_text('q', true, 2, 5) == '۲ از ۵'
}

fn test_update_version_text_fa() {
	old_vox, old_lang := set_fa_locale('fa')
	defer { restore_fa_locale(old_vox, old_lang) }
	assert update_version_text('0.2', '0.1') == 'نگارش 0.2 در دسترس است (نصب‌شده: 0.1).'
}

fn test_window_controls_text_fa() {
	old_vox, old_lang := set_fa_locale('fa')
	defer { restore_fa_locale(old_vox, old_lang) }
	assert window_button_text('close') == 'بستن پنجره'
	assert window_button_text('minimize') == 'کوچک‌کردن پنجره'
	assert window_button_text('zoom') == 'بزرگ‌کردن پنجره'
	assert close_tab_text('example.com') == 'بستن example.com'
	assert tab_color_text('red') == 'قرمز'
	assert tab_color_text('default') == 'پیش‌فرض'
}
