module main

import adblock
import browserjs
import css
import dom

struct PopularAdblockCase {
	url string
	setup string
	probe string
	has_scriptlets bool = true
	ad_html string = '<div id="advert" class="ad_banner"><span>Advertisement</span></div>'
	hide_advert bool = true
	preserve_generic bool
}

fn check_popular_adblock_case(test_case PopularAdblockCase) ! {
	mut document := parse_browser_navigation_document('<!doctype html><body>${test_case.ad_html}<div id="generic" class="ad_banner">Generic candidate</div><article id="content">Article content</article></body>',
		dom.URL{value: test_case.url}, none)
	mut runtime := browserjs.Runtime.create()
	defer { runtime.close(); document.finalize() }
	mut messages := []string{}
	run_document_javascript(document, document.url.serialize(), []string{}, runtime, mut messages)
	assert messages == [], '${test_case.url}: ${messages}'
	filters := adblock.document_filters(test_case.url, browser_adblock_tokens(document))!
	assert (filters.scriptlets != '') == test_case.has_scriptlets, test_case.url
	if test_case.setup != '' { runtime.evaluate_host(test_case.setup)! }
	install_browser_adblock_scriptlets(document, runtime, mut messages)
	refresh_browser_adblock(document, runtime, mut messages)
	assert messages == [], '${test_case.url}: ${messages}'
	assert runtime.evaluate_host(test_case.probe)! == 'true', test_case.url
	advert := document.get_element_by_id('advert') or { panic('missing advert') }
	advert_style := css.StyleComputer.new(document).compute_style(dom.AbstractElement.new(advert, none))
	assert ((advert_style.property(.display, .no) or { panic('missing value') }).css_text == 'none') == test_case.hide_advert, test_case.url
	if test_case.preserve_generic {
		generic := document.get_element_by_id('generic') or { panic('missing generic candidate') }
		generic_style := css.StyleComputer.new(document).compute_style(dom.AbstractElement.new(generic, none))
		assert (generic_style.property(.display, .no) or { panic('missing value') }).css_text != 'none', test_case.url
	}
	content := document.get_element_by_id('content') or { panic('missing article') }
	content_style := css.StyleComputer.new(document).compute_style(dom.AbstractElement.new(content, none))
	assert (content_style.property(.display, .no) or { panic('missing value') }).css_text != 'none', test_case.url
}

fn popular_adblock_cases() []PopularAdblockCase {
	return [
		PopularAdblockCase{
			url: 'https://www.cnn.com/'
			ad_html: '<div id="advert" class="ad-slot__ad-wrapper"><span>Advertisement</span></div>'
			probe: 'globalThis.FAVE={settings:{ads:{ssai:{prod:{liveUnauth:{enabled:true},liveAuth:{enabled:true},clips:{enabled:true}}}}}};Object.values(FAVE.settings.ads.ssai.prod).every(value=>value.enabled===false)'
		},
		PopularAdblockCase{
			url: 'https://www.youtube.com/'
			ad_html: '<yt-overlay-product-sticker id="advert"><span>Advertisement</span></yt-overlay-product-sticker>'
			preserve_generic: true
			setup: 'globalThis.ytInitialPlayerResponse={adSlots:[1],adPlacements:[1],playerAds:[1],videoDetails:{title:"Keep"}};globalThis.playerResponse={adPlacements:[1]}'
			probe: 'ytInitialPlayerResponse.adSlots===undefined&&ytInitialPlayerResponse.adPlacements===undefined&&ytInitialPlayerResponse.playerAds===undefined&&playerResponse.adPlacements===undefined&&ytInitialPlayerResponse.videoDetails.title==="Keep"'
		},
		PopularAdblockCase{
			url: 'https://www.reddit.com/'
			ad_html: '<shreddit-ad-post id="advert"><span>Advertisement</span></shreddit-ad-post>'
			preserve_generic: true
			probe: '(()=>{const parsed=JSON.parse(JSON.stringify({data:{children:[{data:{outbound_link:"tracking",title:"Keep"}}],feed:{elements:{edges:[{node:{outboundLink:"tracking",title:"Keep"}}]}}}}));return parsed.data.children[0].data.outbound_link===undefined&&parsed.data.feed.elements.edges[0].node.outboundLink===undefined&&parsed.data.children[0].data.title==="Keep"&&parsed.data.feed.elements.edges[0].node.title==="Keep"})()'
		},
		PopularAdblockCase{
			url: 'https://www.amazon.com/'
			ad_html: '<div id="advert" data-cel-widget="sp-rhf-desktop-carousel_desktop-rhf_1"><span>Advertisement</span></div>'
			preserve_generic: true
			probe: '(()=>{const parsed=JSON.parse(JSON.stringify({ads:[1],cuepointPlaylist:[1],title:"Keep",vodPlaybackUrls:{result:{playbackUrls:{cuepoints:[1],url:"content"}}}}));return parsed.ads===undefined&&parsed.cuepointPlaylist===undefined&&parsed.vodPlaybackUrls.result.playbackUrls.cuepoints===undefined&&parsed.title==="Keep"&&parsed.vodPlaybackUrls.result.playbackUrls.url==="content"})()'
		},
		PopularAdblockCase{
			url: 'https://www.yahoo.com/'
			ad_html: '<div id="advert" class="ad-container"><span>Advertisement</span></div>'
			probe: 'navigator.globalPrivacyControl===false'
		},
		PopularAdblockCase{
			url: 'https://github.com/'
			probe: 'JSON.parse(JSON.stringify({ads:[1],title:"Keep"})).ads.length===1&&document.getElementById("content").textContent==="Article content"'
			has_scriptlets: false
			hide_advert: false
			preserve_generic: true
		},
		PopularAdblockCase{
			url: 'https://www.espn.com/'
			probe: 'navigator.globalPrivacyControl===false'
		},
		PopularAdblockCase{
			url: 'https://en.wikipedia.org/wiki/Main_Page'
			probe: 'JSON.parse(JSON.stringify({ads:[1],title:"Keep"})).ads.length===1&&document.getElementById("content").textContent==="Article content"'
			has_scriptlets: false
			hide_advert: false
			preserve_generic: true
		},
	]
}

fn test_cnn_adblock_effects_in_the_native_page() {
	$if !darwin { return }
	check_popular_adblock_case(popular_adblock_cases()[0])!
}

fn test_youtube_adblock_effects_in_the_native_page() {
	$if !darwin { return }
	check_popular_adblock_case(popular_adblock_cases()[1])!
}

fn test_reddit_adblock_effects_in_the_native_page() {
	$if !darwin { return }
	check_popular_adblock_case(popular_adblock_cases()[2])!
}

fn test_amazon_adblock_effects_in_the_native_page() {
	$if !darwin { return }
	check_popular_adblock_case(popular_adblock_cases()[3])!
}

fn test_yahoo_adblock_effects_in_the_native_page() {
	$if !darwin { return }
	check_popular_adblock_case(popular_adblock_cases()[4])!
}

fn test_github_adblock_effects_in_the_native_page() {
	$if !darwin { return }
	check_popular_adblock_case(popular_adblock_cases()[5])!
}

fn test_espn_adblock_effects_in_the_native_page() {
	$if !darwin { return }
	check_popular_adblock_case(popular_adblock_cases()[6])!
}

fn test_wikipedia_adblock_effects_in_the_native_page() {
	$if !darwin { return }
	check_popular_adblock_case(popular_adblock_cases()[7])!
}
