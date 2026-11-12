module browserui

// Persian (fa) chrome strings for the browser i18n system. This table must
// cover exactly the `en_chrome_strings` keys; `tools/check_browser_locale.py`
// enforces the parity. Registered in `supported_locales()` / `locale_table()`
// in `browser_locale.v`; selected with `VOX_LANG=fa` or `LANG=fa_IR.UTF-8`.

const fa_chrome_strings = {
	'nav.back':              'قبلی'
	'nav.forward':           'بعدی'
	'nav.reload':            'بارگذاری مجدد'
	'chrome.history':        'سابقه'
	'menu.browser':          'مرورگر'
	'menu.settings':         'تنظیمات…'
	'menu.history':          'سابقه'
	'menu.devtools':         'ابزارهای توسعه‌دهنده'
	'menu.inspect':          'بازرسی عنصر'
	'menu.console':          'کنسول جاوااسکریپت'
	'address.hint':          'نشانی اینترنتی را وارد کنید'
	'address.info':          'اطلاعات صفحه'
	'address.suggestions':   'پیشنهادهای نشانی'
	'tab.new':               'برگهٔ جدید'
	'tab.loading':           'در حال بارگذاری'
	'tab.color.menu':        'رنگ برگه…'
	'tab.color.group':       'رنگ برگه'
	'tab.color.default':     'پیش‌فرض'
	'tab.color.red':         'قرمز'
	'tab.color.orange':      'نارنجی'
	'tab.color.yellow':      'زرد'
	'tab.color.green':       'سبز'
	'tab.color.blue':        'آبی'
	'tab.color.purple':      'بنفش'
	'tab.color.pink':        'صورتی'
	'tab.rename.menu':       'تغییر نام برگه…'
	'tab.title.heading':     'تغییر نام برگه'
	'tab.title.hint':        'عنوان برگه'
	'tab.title.a11y':        'عنوان سفارشی برگه'
	'tab.title.help':        'برای استفاده از عنوان صفحه، خالی بگذارید.'
	'tab.title.use-page':    'استفاده از عنوان صفحه'
	'tab.title.cancel':      'لغو'
	'tab.title.save':        'ذخیره'
	'find.hint':             'جستجو در صفحه'
	'find.notfound':         'یافت نشد'
	'find.status':           '{current} از {total}'
	'status.build-time':     'زمان ساخت (UTC)'
	'update.title':          'به‌روزرسانی Vox در دسترس است'
	'update.help':           '«OK» نشانی vox-browser.org را در مرورگر پیش‌فرض شما باز می‌کند'
	'update.quit-help':      'و این نسخهٔ Vox را می‌بندد.'
	'update.error':          'مرورگر شما باز نشد. دوباره «OK» را امتحان کنید.'
	'update.later':          'بعداً'
	'update.version':        'نگارش {latest} در دسترس است (نصب‌شده: {current}).'
	'window.button':         '{action} پنجره'
	'window.close':          'بستن پنجره'
	'window.minimize':       'کوچک‌کردن پنجره'
	'window.zoom':           'بزرگ‌کردن پنجره'
	'tab.close':             'بستن {title}'
	'ctx.open-link':         'باز کردن پیوند در برگهٔ جدید'
	'ctx.copy-link':         'کپی نشانی پیوند'
	'ctx.inspect':           'بازرسی'
	'settings.title':        'تنظیمات Vox'
	'settings.browsing':     'مرور'
	'settings.tab-coloring': 'فعال‌سازی رنگ برگه‌ها'
	'settings.custom-titles': 'فعال‌سازی عنوان‌های سفارشی برگه'
	'settings.network':      'شبکه'
	'settings.proxy':        'استفاده از پروکسی SOCKS5'
	'settings.host':         'میزبان'
	'settings.port':         'درگاه'
	'settings.a11y.host':    'میزبان پروکسی SOCKS5'
	'settings.a11y.port':    'درگاه پروکسی SOCKS5'
	'settings.sites':        'فقط برای این سایت‌ها'
	'settings.a11y.sites':   'پروکسی SOCKS5 فقط برای این سایت‌ها؛ خالی یعنی همهٔ سایت‌ها'
	'settings.sites-help':   'شامل زیردامنه‌ها می‌شود. با کاما جدا کنید؛ برای همه خالی بگذارید.'
	'settings.other-direct': 'سایر سایت‌ها مستقیم متصل می‌شوند. DNS پروکسی‌شده از SOCKS5 استفاده می‌کند.'
	'settings.apply-note':   'تغییرات روی درخواست‌های جدید اعمال می‌شود.'
	'settings.advanced':     'پیشرفته'
	'settings.gpu':          'پیمایش با شتاب GPU'
	'settings.gpu-help':     'اگر صفحه‌های پیمایش‌شده خطای ترسیمی نشان دادند، خاموش کنید.'
	'settings.cancel':       'لغو'
	'settings.apply':        'اعمال'
}

// fa_digits renders ASCII digits as Persian digits for display-only counts.
// Byte matching is safe: ASCII digits never occur inside multibyte UTF-8.
pub fn fa_digits(input string) string {
	digits := ['۰', '۱', '۲', '۳', '۴', '۵', '۶', '۷', '۸', '۹']
	mut out := ''
	for b in input.bytes() {
		if b >= 48 && b <= 57 {
			out += digits[b - 48]
		} else {
			out += b.ascii_str()
		}
	}
	return out
}
