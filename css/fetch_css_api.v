@[has_globals]
module css

import dom
import fetch
import url as liburl

// https://drafts.csswg.org/css-values-4/#style-resource-base-url
pub struct StyleSheetAndURL {
pub mut:
	sheet ?&CSSStyleSheet
	url   string
}

pub type CSSFetchClientProvider = fn (&dom.Document) ?fetch.RequestClient

__global css_fetch_client_provider_ ?CSSFetchClientProvider = ?CSSFetchClientProvider(none)

pub fn install_css_fetch_client_provider(provider CSSFetchClientProvider) {
	css_fetch_client_provider_ = provider
}

pub struct CSSFetchEnvironmentSettings {
pub mut:
	api_base_url string
	origin       string
	origin_object ?dom.Origin
	client ?fetch.RequestClient
}

pub fn CSSFetchEnvironmentSettings.from_document(document &dom.Document) CSSFetchEnvironmentSettings {
	base_url := document.base_url().to_string()
	return CSSFetchEnvironmentSettings{
		api_base_url: base_url
		origin: document.origin().serialize()
		origin_object: document.origin()
		client: if provider := css_fetch_client_provider_ { provider(document) } else { none }
	}
}

pub struct RuleOrDeclarationStyleDeclaration {
pub mut:
	declaration &CSSStyleProperties = unsafe { nil }
}

pub struct RuleOrDeclarationRule {
pub mut:
	parent_style_sheet ?&CSSStyleSheet
}

pub type RuleOrDeclarationValue = RuleOrDeclarationRule | RuleOrDeclarationStyleDeclaration

pub struct RuleOrDeclaration {
pub mut:
	value                       RuleOrDeclarationValue
	environment_settings_object CSSFetchEnvironmentSettings
}

pub fn RuleOrDeclaration.from_style_declaration(declaration &CSSStyleProperties, environment_settings_object CSSFetchEnvironmentSettings) RuleOrDeclaration {
	return RuleOrDeclaration{
		value: RuleOrDeclarationValue(RuleOrDeclarationStyleDeclaration{
			declaration: declaration
		})
		environment_settings_object: environment_settings_object
	}
}

pub fn RuleOrDeclaration.from_rule(rule &CSSRule, environment_settings_object CSSFetchEnvironmentSettings) RuleOrDeclaration {
	return RuleOrDeclaration{
		value: RuleOrDeclarationValue(RuleOrDeclarationRule{
			parent_style_sheet: rule.parent_style_sheet
		})
		environment_settings_object: environment_settings_object
	}
}

fn style_resource_base_url(css_rule_or_declaration RuleOrDeclaration) StyleSheetAndURL {
	// 1. Let sheet be null.
	mut sheet := ?&CSSStyleSheet(none)

	// 2. If cssRuleOrDeclaration is a CSS declaration block whose parent CSS rule is not null, set cssRuleOrDeclaration to cssRuleOrDeclaration's parent CSS rule.
	match css_rule_or_declaration.value {
		RuleOrDeclarationStyleDeclaration {
			if parent_rule := css_rule_or_declaration.value.declaration.parent_rule {
				sheet = parent_rule.parent_style_sheet
			}
		}
		RuleOrDeclarationRule {
			// 3. If cssRuleOrDeclaration is a CSS rule, set sheet to cssRuleOrDeclaration's parent style sheet.
			sheet = css_rule_or_declaration.value.parent_style_sheet
		}
	}

	// 4. If sheet is not null:
	if style_sheet := sheet {
		// 1. If sheet's stylesheet base URL is not null, return sheet's stylesheet base URL.
		if base_url := style_sheet.base_url {
			return StyleSheetAndURL{
				sheet: style_sheet
				url: base_url
			}
		}

		// 2. If sheet's location is not null, return sheet's location.
		if location := style_sheet.base.location {
			return StyleSheetAndURL{
				sheet: style_sheet
				url: location
			}
		}
	}

	// 5. Return cssRuleOrDeclaration's relevant settings object's API base URL.
	return StyleSheetAndURL{
		sheet: sheet
		url: css_rule_or_declaration.environment_settings_object.api_base_url
	}
}

pub type StyleResourceURL = URL | string

fn style_resource_url_string(url_value StyleResourceURL) string {
	return match url_value {
		URL { url_value.url() }
		string { url_value }
	}
}

// https://drafts.csswg.org/css-values-4/#resolve-a-style-resource-url
pub fn resolve_a_style_resource_url(url_value StyleResourceURL, css_rule_or_declaration RuleOrDeclaration) ?string {
	// 1. Let baseURL be the style resource base URL given cssRuleOrDeclaration.
	base := style_resource_base_url(css_rule_or_declaration).url

	// 2. Return the result of the URL parser steps with urlValue's url and base.
	url_string := style_resource_url_string(url_value)
	return resolve_css_url_with_base(url_string, base)
}

fn resolve_css_url_with_base(url_string string, base string) ?string {
	base_url := liburl.parse(base) or { return none }
	return liburl.parse_with_base(url_string, &base_url)?.serialize(false)
}

pub enum CorsMode {
	cors
	no_cors
}

fn fetch_a_style_resource_impl(url_value StyleResourceURL, css_rule_or_declaration RuleOrDeclaration, destination CSSRequestDestination, cors_mode CorsMode) ?CSSRequest {
	// 1. Let parsedUrl be the result of resolving urlValue given cssRuleOrDeclaration. If that failed, return.
	parsed_url := resolve_a_style_resource_url(url_value, css_rule_or_declaration) or {
		return none
	}

	// 2. Let settingsObject be cssRuleOrDeclaration's relevant settings object.
	environment_settings := css_rule_or_declaration.environment_settings_object

	// 3. Let req be a new request whose url is parsedUrl, whose destination is destination, mode is corsMode,
	//    origin is environmentSettings's origin, credentials mode is "same-origin", use-url-credentials flag is set,
	//    client is environmentSettings, and whose referrer is environmentSettings's API base URL.
	mut request := CSSRequest{
		url: parsed_url
		destination: destination
		mode: if cors_mode == .cors {
			CSSRequestMode.cors} else {
			CSSRequestMode.no_cors}
		origin: environment_settings.origin
		origin_object: environment_settings.origin_object
		credentials_mode: .same_origin
		use_url_credentials: true
		client_base_url: environment_settings.api_base_url
		client: environment_settings.client
		referrer: environment_settings.api_base_url
	}

	// 4. If corsMode is "no-cors", set req's credentials mode to "include".
	if cors_mode == .no_cors {
		request.credentials_mode = .include
	}

	// 5. Apply any URL request modifier steps that apply to this request.
	if url_value is URL {
		apply_request_modifiers_from_url_value(url_value, mut request)
	}

	// 6. If req's mode is "cors", and sheet is not null, then set req's referrer to the style resource base URL given cssRuleOrDeclaration. [CSSOM]
	// FIXME: Spec issue - sheet is not defined as a variable, we use the sheet determined from 'style resource base URL' instead.
	//        https://github.com/w3c/csswg-drafts/issues/12288
	sheet_and_base_url := style_resource_base_url(css_rule_or_declaration)
	if mode := request.mode {
		if mode == .cors && sheet_and_base_url.sheet != none {
			request.referrer = sheet_and_base_url.url
		}
	}

	// 7. If sheet's origin-clean flag is set, set req's initiator type to "css". [CSSOM]
	if sheet := sheet_and_base_url.sheet {
		if sheet.base.origin_clean {
			request.initiator_type = .css
		}
	} else {
		// AD-HOC: If the resource is not associated with a stylesheet, we must still set an initiator type in order
		//         for this resource to be observable through a PerformanceObserver. WPT relies on this.
		request.initiator_type = .script
	}

	// 9. Fetch req, with processresponseconsumebody set to processResponse.
	// NB: Implemented by caller.
	return request
}

fn css_request_to_fetch_request(request CSSRequest) &fetch.Request {
	mut fetch_request := fetch.Request.create()
	if client := request.client { fetch_request.set_client(client) }
	fetch_request.url_list = [dom.URL{ value: request.url }]
	fetch_request.mode = match request.mode or { CSSRequestMode.no_cors } {
		.cors { .cors }
		.no_cors { .no_cors }
	}
	fetch_request.credentials_mode = match request.credentials_mode or {
		CSSRequestCredentialsMode.same_origin} {
		.include { .include }
		.same_origin { .same_origin }
	}
	fetch_request.destination = match request.destination {
		.empty { none }
		.image { fetch.Destination.image }
		.font { fetch.Destination.font }
		.style { fetch.Destination.style }
	}
	fetch_request.origin = fetch.RequestOrigin{
		is_client: false
		origin: request.origin_object or { dom.Origin{ value: request.origin } }
	}
	fetch_request.use_url_credentials = request.use_url_credentials
	fetch_request.integrity_metadata = request.integrity_metadata
	if request.referrer != '' {
		fetch_request.referrer = fetch.Referrer{
			url: dom.URL{ value: request.referrer }
		}
	}
	if policy := request.referrer_policy {
		fetch_request.referrer_policy = match policy {
			.no_referrer { 'no-referrer' }
			.no_referrer_when_downgrade { 'no-referrer-when-downgrade' }
			.same_origin { 'same-origin' }
			.origin { 'origin' }
			.strict_origin { 'strict-origin' }
			.origin_when_cross_origin { 'origin-when-cross-origin' }
			.strict_origin_when_cross_origin { 'strict-origin-when-cross-origin' }
			.unsafe_url { 'unsafe-url' }
		}
	}
	if initiator_type := request.initiator_type {
		fetch_request.initiator_type = match initiator_type {
			.css { fetch.InitiatorType.css }
			.script { fetch.InitiatorType.script }
		}
	}
	return fetch_request
}

// https://drafts.csswg.org/css-values-4/#fetch-a-style-resource
pub fn fetch_a_style_resource(url_value StyleResourceURL, css_rule_or_declaration RuleOrDeclaration, destination CSSRequestDestination, cors_mode CorsMode, process_response fetch.ProcessResponseConsumeBody, host &fetch.FetchHost) ?&fetch.FetchController {
	request := fetch_a_style_resource_impl(url_value, css_rule_or_declaration, destination, cors_mode) or { return none }
	mut fetch_request := css_request_to_fetch_request(request)
	algorithms := fetch.FetchAlgorithms.create(fetch.FetchAlgorithmsInput{
		process_response_consume_body: process_response
	})
	return fetch.fetch(fetch_request, algorithms, host, .no)
}

// https://drafts.csswg.org/css-images-4/#fetch-an-external-image-for-a-stylesheet
pub fn fetch_an_external_image_for_a_stylesheet(url_value StyleResourceURL, declaration RuleOrDeclaration, mut document dom.Document) ?&dom.SharedResourceRequest {
	// To fetch an external image for a stylesheet, given a <url> url and a CSS declaration block declaration, fetch a
	// style resource given url, with ruleOrDeclaration being declaration, destination "image", CORS mode "no-cors",
	// and processResponse being the following steps given response res and null, failure or a byte stream byteStream:
	// If byteStream is a byte stream, load the image from the byte stream.

	// NB: We can't directly call fetch_a_style_resource() because we want to make use of SharedResourceRequest to
	//     deduplicate image requests.
	request := fetch_a_style_resource_impl(url_value, declaration, .image, .no_cors) or {
		return none
	}

	// SharedResourceRequest owns deduplication, fetch/decode state, and decoded
	// image data. The host starts the request through its fetch callback when one
	// is installed at the platform boundary.
	return dom.SharedResourceRequest.get_or_create(mut document, dom.URL{value: request.url})
}

// https://drafts.csswg.org/css-values-5/#apply-request-modifiers-from-url-value
pub fn apply_request_modifiers_from_url_value(url URL, mut request CSSRequest) {
	// To apply request modifiers from URL value given a request req and a <url> url, call the URL request modifier
	// steps for url's <request-url-modifier>s in sequence given req.
	for request_url_modifier in url.request_url_modifiers() {
		request_url_modifier.modify_request(mut request)
	}
}
