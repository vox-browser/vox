module browsersettings

// Persian (fa) validation messages. English stays the single source of truth
// where validation runs; these strings are served through `error_table()` in
// `settings_locale.v` and must cover every `SETTINGS_ERRORS` entry in
// `tools/check_browser_locale.py`.

const fa_error_messages = {
	'Enter a proxy hostname or IP address, without a URL scheme.': 'نام میزبان یا نشانی IP پروکسی را بدون طرح URL وارد کنید.'
	'Enter a port between 1 and 65535.':                            'درگاه بین 1 تا 65535 وارد کنید.'
	'Enter a valid proxy hostname or IP address.':                  'نام میزبان یا نشانی IP معتبر پروکسی وارد کنید.'
	'Enter site hostnames without schemes, paths, ports or wildcards.': 'نام میزبان سایت‌ها را بدون طرح، مسیر، درگاه یا نویسه جایگزین وارد کنید.'
	'Enter at least one site, or leave the field empty for all sites.': 'دست‌کم یک سایت وارد کنید، یا برای همهٔ سایت‌ها خالی بگذارید.'
	'Settings have not been initialized.':                          'تنظیمات مقداردهی اولیه نشده‌اند.'
}
