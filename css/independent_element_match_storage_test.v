module css

import dom
import platform

fn match_storage_append(parent &dom.Node, child &dom.Node) {
    mut target := unsafe { &dom.Node(parent) }
    target.append_child(child) or { panic(err) }
}

fn test_independent_element_matches_keep_namespace_quirks_and_live_attributes() {
    for html_document in [false, true] {
        for quirks in [false, true] {
            mut document := dom.Document.create(dom.url_about_blank())
            defer { document.finalize() }
            document.set_document_type(if html_document { dom.DocumentType_.html } else { dom.DocumentType_.xml })
            if quirks { document.set_quirks_mode(.yes) }
            root := document.create_element_ns('http://www.w3.org/1999/xhtml', 'main')!
            match_storage_append(document.as_node(), root.as_node())
            install_document_selector_query_hook(document)
            for namespace in ['http://www.w3.org/1999/xhtml', 'http://www.w3.org/2000/svg', ''] {
                mut element := document.create_element_ns(namespace, 'linearGradient')!
                element.set_attribute_value('id', 'TARGET')
                element.set_attribute_value('class', 'ITEM beta')
                element.set_attribute_value('data-label', 'Value two')
                element.set_attribute_value_ns('token', 'Name', 'q', 'urn:query')
                match_storage_append(root.as_node(), element.as_node())
                for text in ['*', '*|*', '|*', 'linearGradient', 'lineargradient', '#TARGET',
                    '#target', '.ITEM', '.item', '[id], [class]', '[data-label="value two" i]',
                    '[data-label~=two]', '[data-label^=Value]', '[*|token]', '[|token]'] {
                    selectors := document_query_selector_list(document, text) or { panic(text) }
                    mut expected := false
                    for selector in selectors.selectors {
                        mut context := MatchContext{has_result_cache: unsafe { nil }}
                        expected = expected || matches(selector, element, none, mut context, none,
                            unsafe { &dom.ParentNode(element) }, .normal, none)
                    }
                    assert element.matches(text) or { false } == expected, text
                    assert element_matches_selector(element, text) == expected, text
                }
                element.set_attribute_value('class', 'changed')
                reuse := platform.begin_thread_scratch('overwrite element matching vectors')
                _ = []u8{len: 256 * 1024, init: 0xa5}
                reuse.finish()
                assert !(element.matches('.ITEM') or { false })
                assert element.matches('.changed') or { false }
                assert element.matches(':scope') or { false }
                assert element.matches('main > :first-child, main > :last-child, .changed') or { false }
            }
        }
    }
}

fn test_independent_match_callbacks_retire_their_vectors() {
    mut document := dom.Document.create(dom.url_about_blank())
    defer { document.finalize() }
    document.set_document_type(.html)
    mut element := document.create_element('span')!
    element.set_attribute_value('class', 'target')
    element.set_attribute_value('data-label', 'Value two')
    match_storage_append(document.as_node(), element.as_node())
    text := 'span.target[data-label="value two" i]'
    selectors := document_query_selector_list(document, text) or { panic('missing selector') }
    hook := document.selector_query_hook() or { panic('missing hook') }
    scope := unsafe { &dom.ParentNode(element) }
    before_control := platform.thread_arena_usage().used
    for _ in 0 .. 512 {
        mut context := MatchContext{has_result_cache: unsafe { nil }}
        assert matches(selectors.selectors[0], element, none, mut context, none, scope, .normal, none)
        assert !selector_list_contains_named_namespace(selectors)
    }
    control := platform.thread_arena_usage().used - before_control
    before := platform.thread_arena_usage().used
    for _ in 0 .. 512 {
        assert dom_selector_query_matches(hook.target, text, element, scope)
        assert !dom_selector_query_contains_named_namespace(hook.target, text)
    }
    retained := platform.thread_arena_usage().used - before
    $if prealloc {
        assert retained < 4096
        assert control > retained + 8192
        println('ELEMENT_MATCH_STORAGE control=${control} candidate=${retained}')
    }
}
