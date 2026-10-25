module main

$if vox_ui2 ? {
	import browsersettings
	import platform
	import ui2

	#include "native_browser_settings_darwin.h"
	fn C.native_browser_settings_install(callback fn ())
	fn C.native_browser_settings_content() voidptr
	fn C.native_browser_settings_visible() int
	fn C.native_browser_settings_show()
	fn C.native_browser_settings_hide()
	fn C.native_browser_settings_enabled(field voidptr, enabled int)
	fn C.native_browser_settings_style_control(control voidptr, role int)
	fn C.native_browser_settings_buttons(apply voidptr, cancel voidptr)
	fn C.native_browser_settings_remove()

	fn browser_settings_input(id string, value string, hint string, x f64, y f64, width f64) ui2.Element {
		return ui2.Element{
			...ui2.text_input(
				id:          id
				submit_id:   'settings-apply'
				text:        value
				hint_text:   hint
				multiline:   false
				autocorrect: false
				frame:       ui2.rect(x, y, width, 24)
				text_style:  ui2.TextStyle{ size: 13 }
			) or { panic(err) }
			accessibility_label: if id == 'settings-host' {
				'SOCKS5 proxy host'
			} else if id == 'settings-port' {
				'SOCKS5 proxy port'
			} else {
				'Only use SOCKS5 proxy for these sites; empty means all sites'
			}
		}
	}

	fn browser_settings_elements(proxy browsersettings.Proxy) ui2.Element {
		return ui2.view('settings-root', ui2.rect(0, 0, 500, 380), ui2.BoxStyle{}, [
			ui2.label('settings-heading', 'Network', ui2.rect(24, 20, 452, 24), ui2.TextStyle{ size: 18 }),
			ui2.checkbox('settings-enabled', 'Use SOCKS5 proxy', proxy.enabled, ui2.rect(24, 60, 452, 24), ui2.TextStyle{ size: 13 }),
			ui2.label('settings-host-label', 'Host', ui2.rect(24, 99, 320, 20), ui2.TextStyle{ size: 13 }),
			ui2.label('settings-port-label', 'Port', ui2.rect(368, 99, 108, 20), ui2.TextStyle{ size: 13 }),
			browser_settings_input('settings-host', proxy.host, '127.0.0.1', 24, 122, 324),
			browser_settings_input('settings-port', proxy.port, '1080', 368, 122, 108),
			ui2.label('settings-sites-label', 'Only for these sites', ui2.rect(24, 166, 452, 20), ui2.TextStyle{ size: 13 }),
			browser_settings_input('settings-sites', proxy.sites, 'example.com, another.org', 24, 190, 452),
			ui2.label('settings-sites-help', 'Includes subdomains. Separate with commas; leave empty for all.', ui2.rect(24, 224, 452, 20), ui2.TextStyle{ size: 12 }),
			ui2.label('settings-help', 'Other sites connect directly. Proxied DNS uses SOCKS5.', ui2.rect(24, 245, 452, 20), ui2.TextStyle{ size: 12 }),
			ui2.label('settings-request-help', 'Changes apply to new requests.', ui2.rect(24, 266, 452, 20), ui2.TextStyle{ size: 12 }),
			ui2.label('settings-error', '', ui2.rect(24, 294, 452, 24), ui2.TextStyle{ size: 12, color: 0xb42318 }),
			ui2.with_native_style(ui2.button('settings-cancel', 'Cancel', ui2.rect(294, 334, 86, 28), ui2.BoxStyle{}, ui2.TextStyle{ size: 13 })),
			ui2.with_native_style(ui2.button('settings-apply', 'Apply', ui2.rect(390, 334, 86, 28), ui2.BoxStyle{}, ui2.TextStyle{ size: 13 })),
		])
	}

	fn update_browser_settings_enabled() {
		enabled := int(ui2.control_checked('settings-enabled'))
		for id in ['settings-host', 'settings-port', 'settings-sites'] {
			C.native_browser_settings_enabled(ui2.embedded_browser_control(id), enabled)
		}
	}

	fn show_native_browser_settings() {
		// Repeated Cmd+, raises the existing draft without replacing edits.
		if C.native_browser_settings_visible() != 0 {
			C.native_browser_settings_show()
			return
		}
		persistent := platform.enter_persistent()
		defer { platform.leave_persistent(persistent) }
		proxy := browsersettings.current()
		ui2.update_embedded_settings(C.native_browser_settings_content(), browser_settings_elements(proxy))
		for id in ['settings-heading', 'settings-host-label', 'settings-port-label', 'settings-host',
			'settings-port', 'settings-sites-label', 'settings-sites'] {
			C.native_browser_settings_style_control(ui2.embedded_browser_control(id), 0)
		}
		for id in ['settings-help', 'settings-sites-help', 'settings-request-help'] {
			C.native_browser_settings_style_control(ui2.embedded_browser_control(id), 1)
		}
		C.native_browser_settings_style_control(ui2.embedded_browser_control('settings-error'), 2)
		C.native_browser_settings_buttons(ui2.embedded_browser_control('settings-apply'), ui2.embedded_browser_control('settings-cancel'))
		// A canceled field can differ from its previous declarative value.
		ui2.set_text('settings-host', proxy.host)
		ui2.set_text('settings-port', proxy.port)
		ui2.set_text('settings-sites', proxy.sites)
		ui2.set_text('settings-error', '')
		ui2.set_control_checked('settings-enabled', proxy.enabled)
		update_browser_settings_enabled()
		C.native_browser_settings_show()
	}

	fn browser_settings_event(event string) {
		match event {
			'settings-enabled' { update_browser_settings_enabled() }
			'settings-cancel' { C.native_browser_settings_hide() }
			'settings-apply' {
				browsersettings.save(browsersettings.Proxy{
					enabled: ui2.control_checked('settings-enabled')
					host:    ui2.text('settings-host')
					port:    ui2.text('settings-port')
					sites:   ui2.text('settings-sites')
				}) or {
					ui2.set_text('settings-error', err.msg())
					return
				}
				C.native_browser_settings_hide()
			}
			else {}
		}
	}
}
