module browserui

import ui2

pub const update_notice_width = 460
pub const update_notice_height = 220

pub struct UpdateNotice {
pub mut:
	latest      string
	open        bool
	open_failed bool
}

pub fn (notice UpdateNotice) elements(current string) ui2.Element {
	return ui2.Element{
		...ui2.view('update-root', ui2.rect(0, 0, update_notice_width, update_notice_height), ui2.BoxStyle{ bg: 0xf7f7f7 }, [
			ui2.label('update-heading', tr('update.title'), ui2.rect(24, 20, 412, 28), ui2.TextStyle{ size: 18 }),
			ui2.label('update-version', update_version_text(notice.latest, current), ui2.rect(24, 58, 412, 22), ui2.TextStyle{ size: 13 }),
			ui2.label('update-help', tr('update.help'), ui2.rect(24, 90, 412, 22), ui2.TextStyle{ size: 13 }),
			ui2.label('update-quit-help', tr('update.quit-help'), ui2.rect(24, 112, 412, 22), ui2.TextStyle{ size: 13 }),
			ui2.label('update-error', if notice.open_failed { tr('update.error') } else { '' }, ui2.rect(24, 142, 412, 22), ui2.TextStyle{ size: 12, color: 0xb42318 }),
			ui2.with_native_style(ui2.button('update-later', tr('update.later'), ui2.rect(254, 176, 86, 28), ui2.BoxStyle{}, ui2.TextStyle{ size: 13 })),
			ui2.with_native_style(ui2.button('update-ok', 'OK', ui2.rect(350, 176, 86, 28), ui2.BoxStyle{}, ui2.TextStyle{ size: 13 })),
		])
		accessibility_role:  'dialog'
		accessibility_label: tr('update.title')
	}
}

pub fn (notice UpdateNotice) key_action(key string, command bool) string {
	if !notice.open { return '' }
	if key == 'escape' || (command && key == 'w') { return 'update-later' }
	if !command && key in ['enter', 'kp_enter'] { return 'update-ok' }
	return ''
}
