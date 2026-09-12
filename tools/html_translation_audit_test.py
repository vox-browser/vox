import unittest

import html_translation_audit as audit


class VFieldInventoryTests(unittest.TestCase):
    def test_collects_only_direct_struct_fields(self) -> None:
        fields = audit.v_field_names_in_text(
            """
pub struct PaintStyle {
pub mut:
    color_space ColorSpace
    transform   ?Affine
    cache       map[string]Value = map[string]Value{
        'ignored': Value{}
    }
    // fake_field string
    label string = 'https://example.test/{not_a_field}'
}

// An accessor's state is often stored on a later struct.
pub struct LaterState {
    snapshot Snapshot
}
"""
        )

        self.assertEqual(
            fields,
            {
                ("cache", "PaintStyle"),
                ("color_space", "PaintStyle"),
                ("label", "PaintStyle"),
                ("transform", "PaintStyle"),
                ("snapshot", "LaterState"),
            },
        )

    def test_explicit_field_mapping_fails_open_when_target_moves(self) -> None:
        present = {("gradient_transform", "SVGGradientPaintStyle")}
        self.assertEqual(
            audit.mapped_field_candidate_names(
                "gradient_transform", "SVGGradientPaintStyle", present
            ),
            ("SVGGradientPaintStyle.gradient_transform",),
        )
        self.assertEqual(
            audit.mapped_field_candidate_names(
                "gradient_transform", "SVGGradientPaintStyle", set()
            ),
            (),
        )


    def test_multi_field_mapping_requires_every_component(self) -> None:
        complete = {
            ("svg_viewbox_transform_", "UsedValues"),
            ("svg_transform_", "UsedValues"),
        }
        self.assertEqual(
            audit.mapped_field_candidate_names(
                "computed_transforms", "SVGGraphicsPaintable", complete
            ),
            (
                "UsedValues.svg_viewbox_transform_",
                "UsedValues.svg_transform_",
            ),
        )
        self.assertEqual(
            audit.mapped_field_candidate_names(
                "computed_transforms",
                "SVGGraphicsPaintable",
                {("svg_viewbox_transform_", "UsedValues")},
            ),
            (),
        )


class ConsolidatedOwnerTests(unittest.TestCase):
    def test_filtered_response_methods_use_unified_response_owner(self) -> None:
        functions = {
            ("navigation_timing_allow_values_list", "Response"),
            ("fetch_response_redirect_taint", "Response"),
            ("request_server_request", "Response"),
        }

        self.assertEqual(
            audit.candidate_names(
                "navigation_timing_allow_values_list", "FilteredResponse", functions
            ),
            ("navigation_timing_allow_values_list",),
        )
        self.assertEqual(
            audit.candidate_names("redirect_taint", "FilteredResponse", functions),
            ("fetch_response_redirect_taint",),
        )
        self.assertEqual(
            audit.candidate_names(
                "request_server_request", "FilteredResponse", functions
            ),
            ("request_server_request",),
        )

    def test_webgl_proxy_methods_use_shared_proxy_owner(self) -> None:
        functions = {
            ("shader_source", "WebGLContextProxyBase"),
            ("get_uniform_indices", "WebGLContextProxyBase"),
        }

        self.assertEqual(
            audit.candidate_names("shader_source", "WebGLContextProxy", functions),
            ("shader_source",),
        )
        self.assertEqual(
            audit.candidate_names(
                "get_uniform_indices", "WebGLContextProxy", functions
            ),
            ("get_uniform_indices",),
        )


class ConsolidatedFunctionTests(unittest.TestCase):
    def test_animation_overlay_adapter_maps_to_the_css_update_callback(self) -> None:
        self.assertEqual(
            audit.CONSOLIDATED_FUNCTION_MAPPINGS[
                ("AnimationEffect.cpp", "animated_overlay_entries")
            ],
            ("style_computer_update_animated_style_callback",),
        )

    def test_webgl_base_buffer_helpers_map_to_free_functions(self) -> None:
        self.assertEqual(
            audit.CONSOLIDATED_METHOD_MAPPINGS[
                ("WebGLRenderingContextBase", "with_buffer_source_bytes")
            ],
            (("with_buffer_source_bytes", None),),
        )
        self.assertEqual(
            audit.CONSOLIDATED_METHOD_MAPPINGS[
                ("WebGLRenderingContextBase", "utf16_string_from_gl_string")
            ],
            (("utf16_string_from_gl_string", None),),
        )

    def test_nullable_webgl_wrapper_is_a_language_binding_artifact(self) -> None:
        self.assertIn(
            ("BindingsGlue.h", "webgl_wrappable"),
            audit.LANGUAGE_ARTIFACT_FREE_FUNCTIONS,
        )


if __name__ == "__main__":
    unittest.main()
