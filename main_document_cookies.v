module main

import browsercookies
import dom
import httpcookie
import url

fn install_browser_document_cookie_client(mut document dom.Document) {
	document.set_cookie_client_hook(dom.DocumentCookieClientHook{
		request_cookie: fn (_ voidptr, record &url.URL, source httpcookie.Source) httpcookie.VersionedCookie {
			return httpcookie.VersionedCookie{
				cookie: browsercookies.cookie_string(record, source, browsercookies.Context{})
			}
		}
		set_cookie: fn (_ voidptr, record &url.URL, cookie httpcookie.ParsedCookie, source httpcookie.Source) {
			browsercookies.set_cookie(record, cookie, source, browsercookies.Context{})
		}
	})
}
