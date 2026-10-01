import tempfile
import unittest
from pathlib import Path

import libweb_translation_audit as audit


class TrivialImplementationInventoryTests(unittest.TestCase):
    def test_verified_allocator_factory_is_not_suspicious(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            source = Path(directory) / "permissionsapi" / "permissions.v"
            source.parent.mkdir()
            source.write_text(
                """
module permissionsapi

struct Permissions {}

fn Permissions.create() &Permissions {
    return &Permissions{}
}
"""
            )
            region_source = Path(directory) / "webvtt" / "vtt_region.v"
            region_source.parent.mkdir()
            region_source.write_text(
                """
module webvtt

struct VTTRegion {}

fn VTTRegion.create() &VTTRegion {
    return &VTTRegion{}
}
"""
            )

            suspicious, verified = audit.trivial_implementation_inventories(Path(directory))

        self.assertEqual(suspicious, [])
        self.assertEqual(len(verified), 2)
        self.assertEqual(
            {finding["owner"] for finding in verified}, {"Permissions", "VTTRegion"}
        )

    def test_foreign_function_declaration_is_not_an_empty_implementation(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            source = Path(directory) / "boundary.c.v"
            source.write_text(
                """
module boundary

fn C.external_value() &C.Value

const cache = map[string]int{}

fn genuinely_empty() {
}
"""
            )

            suspicious, _ = audit.trivial_implementation_inventories(Path(directory))

        self.assertEqual(
            suspicious,
            [
                {
                    "source": "boundary.c.v",
                    "line": 8,
                    "owner": None,
                    "name": "genuinely_empty",
                    "body": "",
                }
            ],
        )

    def test_webgl_proxy_noops_are_reviewed_upstream_equivalents(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            source = Path(directory) / "webgl" / "context_proxy.v"
            source.parent.mkdir()
            source.write_text(
                """
module webgl

struct WebGLContextProxyBase {}

fn (_ &WebGLContextProxyBase) make_current() {}
fn (_ &WebGLContextProxyBase) notify_content_will_change() {}
fn (_ &WebGLContextProxyBase) default_framebuffer() u32 { return 0 }
fn (_ &WebGLContextProxyBase) default_renderbuffer() u32 { return 0 }
"""
            )

            suspicious, verified = audit.trivial_implementation_inventories(
                Path(directory)
            )

        self.assertEqual(suspicious, [])
        self.assertEqual(len(verified), 4)

    def test_webaudio_default_factories_and_endpoint_arities_are_reviewed(self) -> None:
        expected = {
            ("webaudio/audio_param_map.v", "AudioParamMap", "create"),
            (
                "webaudio/media_stream_audio_destination.v",
                "MediaStreamAudioDestinationNode",
                "number_of_outputs",
            ),
            (
                "webaudio/media_stream_audio_source.v",
                "MediaStreamAudioSourceNode",
                "number_of_inputs",
            ),
            ("webaudio/render_graph.v", "RenderGraph", "create"),
        }
        self.assertTrue(expected.issubset(audit.VERIFIED_TRIVIAL_IMPLEMENTATIONS))

    def test_current_default_body_review_queue_is_classified(self) -> None:
        expected = {
            (
                "animations/document_timeline.v",
                "DocumentTimeline",
                "can_sample_current_time_at_timestamp",
            ),
            ("bindings/interface_object.v", "InterfaceConstructor", "has_constructor"),
            ("css/computed_values.v", "InitialValues", "position_anchor"),
            ("gamepad/types.v", "GamepadButton", "create"),
            (
                "internals/internal_animation_timeline.v",
                "InternalAnimationTimeline",
                "convert_a_timeline_time_to_an_origin_relative_time",
            ),
            ("loader/content_filter.v", "ContentBlocker", "create"),
            (
                "navigationtiming/navigation_timing.v",
                "PerformanceNavigationTiming",
                "critical_ch_restart",
            ),
            ("painting/video_frame_source.v", "VideoFrameSource", "create"),
            ("serviceworker/cache_storage.v", "CacheStorage", "create"),
            ("webassembly/module_instance.v", "Module", "create_for_serialization"),
            ("webxr/webxr.v", "XRSession", "update_render_state"),
            ("xpath/result.v", "XPathResult", "create"),
        }
        self.assertTrue(expected.issubset(audit.VERIFIED_TRIVIAL_IMPLEMENTATIONS))


class VFunctionInventoryTests(unittest.TestCase):
    def test_libjs_cannot_supply_libweb_symbols_fields_or_review_findings(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            web = root / "dom" / "control.v"
            web.parent.mkdir()
            web.write_text(
                """
module dom
pub struct Object {
pub:
    web_field int
}
// not translated: controlled LibWeb review fixture
fn (object &Object) web_only() bool { return false }
"""
            )
            runtime = root / "libjs" / "runtime.v"
            runtime.parent.mkdir()
            runtime.write_text(
                """
module libjs
pub struct Object {
pub:
    runtime_field int
}
// not translated: controlled LibJS review fixture
fn (object &Object) runtime_only() bool { return false }
"""
            )
            (runtime.parent / "upstream_fake_entry_points.v").write_text(
                "module libjs\nfn foreign_shim() bool { return false }\n"
            )
            (root / "root_support.v").write_text(
                "module main\nfn root_helper() bool { return true }\n"
            )

            functions, quarantined, quarantined_functions = audit.all_v_function_names(root)
            fields = audit.all_v_field_names(root)
            markers = audit.semantic_divergence_inventory(root)
            suspicious, verified = audit.trivial_implementation_inventories(root)

        self.assertEqual(functions, {("web_only", "Object"), ("root_helper", None)})
        self.assertEqual(fields, {("web_field", "Object")})
        self.assertEqual(quarantined, [])
        self.assertEqual(quarantined_functions, 0)
        self.assertEqual([marker["source"] for marker in markers], ["dom/control.v"])
        self.assertEqual(
            {finding["source"] for finding in suspicious},
            {"dom/control.v", "root_support.v"},
        )
        self.assertEqual(verified, [])

    def test_generic_receiver_owner_drops_type_parameters(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            source = Path(directory) / "bindings" / "wrapper_world.v"
            source.parent.mkdir()
            source.write_text(
                """
module bindings

pub struct WrapperWorldWeakValueCache[T] {}

pub struct WrapperWorldWeakValueCacheMap[K, V] {}

pub fn (cache &WrapperWorldWeakValueCache[T]) get() ?&T {
    return none
}

pub fn (mut cache WrapperWorldWeakValueCacheMap[K, V]) cache_for(key &K) ?&V {
    return none
}
"""
            )

            functions, _, _ = audit.all_v_function_names(Path(directory))

        self.assertIn(("get", "WrapperWorldWeakValueCache"), functions)
        self.assertNotIn(("get", "WrapperWorldWeakValueCache[T]"), functions)
        self.assertIn(("cache_for", "WrapperWorldWeakValueCacheMap"), functions)
        self.assertNotIn(("cache_for", "V]"), functions)


class ConsolidatedMethodMappingTests(unittest.TestCase):
    def test_html_element_lifecycle_mappings_require_every_delegate(self) -> None:
        functions = {
            ("activation_behavior", "EventTarget"),
            ("activate_the_hyperlink", "Element"),
            ("children_changed", "Element"),
            ("inserted", "Element"),
            ("removed_from", "Element"),
            ("attribute_changed", "Element"),
            ("update_a_style_block_for_dynamic_change", "StyleElementBase"),
            ("style_element_attribute_changed", "StyleElementBase"),
            ("contributes_a_script_blocking_style_sheet", "Element"),
            (
                "style_element_contributes_a_script_blocking_style_sheet",
                "StyleElementBase",
            ),
        }
        expected = {
            ("HTMLAnchorElement", "activation_behavior"),
            ("HTMLStyleElement", "children_changed"),
            ("HTMLStyleElement", "inserted"),
            ("HTMLStyleElement", "removed_from"),
            ("HTMLStyleElement", "attribute_changed"),
            (
                "HTMLStyleElement",
                "contributes_a_script_blocking_style_sheet",
            ),
        }

        for key in expected:
            mappings = audit.html_audit.CONSOLIDATED_METHOD_MAPPINGS[key]
            self.assertTrue(all(mapping in functions for mapping in mappings))

        functions.remove(("activate_the_hyperlink", "Element"))
        mappings = audit.html_audit.CONSOLIDATED_METHOD_MAPPINGS[
            ("HTMLAnchorElement", "activation_behavior")
        ]
        self.assertFalse(all(mapping in functions for mapping in mappings))


if __name__ == "__main__":
    unittest.main()
