module html

import contentsecuritypolicy as csp
import dom
import encoding
import url as liburl

fn javascript_url_source(address dom.URL) string {
	bytes := liburl.percent_decode(address.serialize().all_after(':'))
	decoder := encoding.TextDecoder.construct('utf-8', encoding.TextDecoderOptions{
		ignore_bom: true
	}) or { panic(err) }
	return decoder.decode(bytes, encoding.TextDecodeOptions{}) or { panic(err) }
}

fn javascript_url_is_blocked_by_csp(document &dom.Document, address dom.URL) bool {
	pointer := document.relevant_settings_object()
	if pointer == unsafe { nil } { return false }
	settings := unsafe { &EnvironmentSettingsObject(pointer) }
	mut global := settings.fetch_request_client_csp_global()
	return csp.should_elements_inline_type_behavior_be_blocked_by_content_security_policy(mut global,csp.ElementContext{},.navigation,liburl.percent_decode(address.serialize()).bytestr()) == .blocked
}
