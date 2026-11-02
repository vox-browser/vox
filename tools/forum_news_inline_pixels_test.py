"""Focused native rendering regressions extracted from the ten-site suite."""
import os
from pathlib import Path
import shutil
import sys
import tempfile
import unittest

from check_pixel_equality import compare
from forum_news_pixels import REPO, VOX, executable_identity, guarded, write_json


@unittest.skipUnless(sys.platform == 'darwin', 'The reference uses native macOS fonts')
class ForumNewsInlinePixelsTests(unittest.TestCase):

    def test_automatic_svg_width_uses_the_quantized_ratio_height(self):
        self.compare_fixture('svg-auto-ratio-rounding', width=1024, height=768)

    def test_later_full_width_float_stays_below_the_completed_inline_line(self):
        self.compare_fixture('inline-block-followed-by-full-float', width=1024, height=768)
    def test_chromium_blurred_byte_color_text_keeps_gpu_blending(self):
        self.compare_fixture('chromium-blurred-byte-text-shadow', width=1024, height=768,
                             settle_seconds=5)

    def test_chromium_transformed_solid_rectangles_use_skia_edge_coverage(self):
        self.compare_fixture('chromium-transformed-solid-fill', width=1024, height=768,
                             settle_seconds=5)

    def test_chromium_baseline_inlines_use_their_own_font_boxes(self):
        self.compare_fixture('chromium-inline-font-box', width=1024, height=768,
                             settle_seconds=5)

    def test_svg_background_layout_keeps_fractional_container_dimensions(self):
        self.compare_fixture('svg-fractional-background-container', width=1024, height=768,
                             settle_seconds=5)

    def test_chromium_rejects_grouped_rules_with_mozilla_pseudo_elements(self):
        self.compare_fixture('chromium-mozilla-selector-list', width=1024, height=768,
                             settle_seconds=5)

    def test_empty_inline_descendants_keep_edges_before_following_content(self):
        self.compare_fixture('empty-inline-ending-edges', width=1024, height=768,
                             settle_seconds=5)

    def test_zero_width_sides_flush_transparent_border_color_runs(self):
        self.compare_fixture('border-color-runs-zero-width', width=1024, height=768,
                             settle_seconds=5)

    def test_unchecked_light_radio_controls_use_chromium_size_and_ring(self):
        self.compare_fixture('chromium-unchecked-radio', width=1024, height=768,
                             settle_seconds=5)

    def test_empty_generated_text_preserves_enclosing_inline_end_edges(self):
        self.compare_fixture('empty-pseudo-inline-end-edges', width=1024, height=768,
                             settle_seconds=5)

    def test_generated_icons_load_the_author_font_before_system_fallback(self):
        self.compare_fixture('pending-generated-icon-font', width=1024, height=768,
                             settle_seconds=2)

    def test_pikabu_direct_image_retains_uniform_raster_scale_and_fractional_visible_quads(self):
        self.compare_fixture('pikabu-direct-composited-image', width=1024, height=768)

    def test_picture_local_rounded_clip_keeps_ordinary_image_sampling(self):
        self.compare_fixture('pikabu-picture-local-image-clip', width=1024, height=768)

    def test_hoisted_image_keeps_its_clip_outside_the_raster_picture(self):
        self.compare_fixture('pikabu-hoisted-image-clip', width=1024, height=768)

    def test_shadow_picture_bounds_preserve_existing_rounded_control_pixels(self):
        self.compare_fixture('pikabu-shadow-picture-tiles', width=1024, height=768)

    def test_rounded_svg_backgrounds_follow_the_parent_tile_msaa_mode(self):
        self.compare_fixture('svg-rounded-parent-msaa', width=1024, height=768)

    def test_svg_ellipses_preserve_pixels_beside_paths_and_in_separate_tiles(self):
        self.compare_fixture('svg-ellipse-parent-msaa', width=1024, height=768)

    def test_rounded_mask_keeps_the_replaced_image_and_its_background_together(self):
        self.compare_fixture('rounded-masked-replaced-image', width=1024, height=768)

    def test_completed_animations_return_header_icons_to_their_parent_picture(self):
        self.compare_fixture('completed-animation-parent-picture', width=1024, height=768,
                             settle_seconds=5)

    def test_pikabu_svg_banner_samples_its_image_pattern_at_the_final_viewport(self):
        self.compare_fixture('pikabu-svg-image-pattern')

    def test_svg_pattern_images_keep_use_and_resource_transforms(self):
        self.compare_fixture('pikabu-svg-pattern-image')

    def test_clamped_svg_spacer_sizes_the_positioned_image_wrapper(self):
        self.compare_fixture('pikabu-clamped-svg-image')

    def test_webp_yuv_and_rgba_paint_paths_preserve_reference_pixels(self):
        for case, width, height in [
                ('webp-yuv', 1024, 768), ('webp-yuv-scaled', 1024, 768),
                ('webp-rgba-mip', 1024, 768), ('webp-rgba-mip-blend', 1024, 768),
                ('webp-alpha-premultiplication', 800, 600),
                ('webp-root-raster-tiles', 1280, 800)]:
            with self.subTest(case=case):
                self.compare_fixture(case, width=width, height=height)

    def test_svg_drop_shadow_preserves_local_vectors_and_root_raster_tiles(self):
        self.compare_fixture('verge-svg-filter-space', width=1024, height=768)

    def test_css_shadows_follow_the_effect_rotation_before_descendant_svg_transforms(self):
        self.compare_fixture('verge-transformed-drop-shadow', width=1024, height=768)

    def compare_fixture(self, name, width=800, height=600, scroll_y=0, document_active=False,
                        initial_viewport=False, settle_seconds=0):
        output = Path(tempfile.mkdtemp(prefix='forum-news-inline-', dir=REPO / 'Build'))
        fixture = REPO / 'Tests/Browser/Brave/input' / (name + '.html')
        reference = REPO / 'Tests/Browser/Brave/expected' / (name + '.png')
        actual = output / 'actual.png'
        environment = {k:v for k,v in os.environ.items()
                       if not k.lower().endswith('_proxy') and not k.startswith(('VOX_', 'LADYBIRD_', 'DYLD_', 'GC_'))}
        environment.update(VOX_PROFILE_DIR=str(output / 'profile'), VOX_TEST_WINDOW='1',
            VOX_CAPTURE_DOCUMENT_ONLY='1', LADYBIRD_SCREENSHOT_SCALE='1',
            LADYBIRD_SCREENSHOT_DELAY_SECONDS=str(settle_seconds))
        if document_active:
            environment['VOX_CAPTURE_DOCUMENT_ACTIVE'] = '1'
        if initial_viewport:
            environment['VOX_CAPTURE_INITIAL_VIEWPORT'] = '1'
        identity = executable_identity(VOX)
        write_json(output / 'identity.json', identity)
        command = [VOX, '--window-width', str(width), '--window-height', str(height + 84)]
        if scroll_y:
            command += ['--screenshot-scroll-y', str(scroll_y)]
        guarded(command + ['--screenshot', actual, fixture], output / 'capture', 60, environment)
        self.assertEqual(executable_identity(VOX), identity, 'Production bundle changed during capture')
        compiler = os.environ.get('V_BIN') or shutil.which('v') or str(Path.home() / 'code/v/v')
        tool = output / 'pixel_diff'
        guarded([compiler, '-memory-limit', '10G', '-nocache', '-o', tool,
                 REPO / 'tools/pixel_diff.v'], output / 'diff-tool', 60)
        verdict = compare(reference, actual, output / 'diff.png', tool)
        write_json(output / 'pixels.json', verdict)
        self.assertTrue(verdict['exact'], verdict['metrics'] + '\nArtifacts: ' + str(output))

    def test_cnn_solid_svg_background_keeps_the_header_in_one_picture(self):
        self.compare_fixture('cnn-svg-background-header', width=1024, height=768)

    def test_cnn_repeated_svg_background_keeps_the_header_in_one_picture(self):
        self.compare_fixture('cnn-repeated-svg-background-header', width=1024, height=768)

    def test_cnn_opaque_header_keeps_its_mask_in_paint_order(self):
        self.compare_fixture('cnn-opaque-header-mask', width=1024, height=768)

    def test_cnn_fractional_svg_background_uses_an_independent_picture(self):
        self.compare_fixture('cnn-fractional-svg-background', width=1024, height=768)

    def test_cnn_ticker_keeps_its_picture_beside_an_offscreen_svg_background(self):
        self.compare_fixture('cnn-ticker-offscreen-background', width=1024, height=768)

    def test_guardian_carousel_overlay_keeps_the_logo_in_its_root_raster(self):
        self.compare_fixture('guardian-carousel-paint-clients', width=1024, height=768)

    def test_guardian_late_font_updates_the_editions_intrinsic_width(self):
        self.compare_fixture('guardian-intrinsic-font-width')

    def test_jpegxl_request_pixels_and_css_backgrounds_share_the_decoder(self):
        self.compare_fixture('jpegxl-image-paths')

    def test_screen_blending_preserves_floating_point_group_opacity(self):
        self.compare_fixture('screen-opacity-composite')

    def test_odd_image_upload_keeps_chromium_pixels_in_retained_pictures(self):
        self.compare_fixture('odd-image-picture-upload')

    def test_cropped_images_honor_conservative_html_decoding_hints(self):
        self.compare_fixture('cropped-image-decoding-modes')

    def test_inactive_images_do_not_override_visible_decode_hints(self):
        self.compare_fixture('cropped-image-inactive-decode-hints')

    def test_image_decode_reuse_follows_resource_identity(self):
        self.compare_fixture('image-decode-resource-reuse')

    def test_concurrent_compositor_picture_keeps_its_image_decode(self):
        self.compare_fixture('image-decode-compositor-reuse')

    def test_scrolling_picture_reuses_a_completed_larger_image_decode(self):
        self.compare_fixture('image-decode-scrolling-reuse', scroll_y=8800, initial_viewport=True)

    def test_compositor_parent_resumes_after_disjoint_scrolling_content(self):
        self.compare_fixture('compositor-disjoint-scroll-gap')

    def test_letter_spacing_disables_optional_ligatures(self):
        self.compare_fixture('spaced-optional-ligatures')

    def test_cropped_glyph_runs_keep_the_document_subpixel_origin(self):
        self.compare_fixture('glyph-document-origin', width=1280, height=600)

    def test_object_fit_compares_fixed_point_dimensions_before_switching_axes(self):
        self.compare_fixture('object-fit-fixed-point-svg', width=1280, height=600)

    def test_calculated_flex_bases_keep_integral_card_boundaries(self):
        self.compare_fixture('calc-flex-card-boundaries', width=1280, height=600)

    def test_definite_flex_basis_survives_cross_axis_limits(self):
        self.compare_fixture('definite-flex-basis-cross-limit')

    def test_automatic_table_columns_match_chromium_surplus_rounding(self):
        self.compare_fixture('automatic-table-column-surplus')

    def test_collapsed_table_borders_retain_fractional_shares_and_placement(self):
        self.compare_fixture('collapsed-table-fractional-shares')

    def test_trailing_fallback_spaces_preserve_intrinsic_button_width(self):
        self.compare_fixture('fallback-space-intrinsic-button')

    def test_middle_aligned_story_tags_match_brave_exactly(self):
        self.compare_fixture('lobsters-tag-alignment')

    def test_rounded_inline_backgrounds_match_brave_exactly(self):
        self.compare_fixture('lobsters-rounded-inline-background')

    def test_fractional_foregrounds_match_brave_exactly(self):
        self.compare_fixture('forum-fractional-foreground')

    def test_inline_backgrounds_and_borders_share_multisample_coverage(self):
        self.compare_fixture('lobsters-inline-msaa-compositing')

    def test_automatic_hyphenation_matches_brave_exactly(self):
        self.compare_fixture('stackoverflow-auto-hyphenation')

    def test_inserted_hyphens_shape_independently_of_the_source_word(self):
        self.compare_fixture('stackoverflow-independent-hyphen-shaping')

    def test_clamped_excerpts_retain_partial_words_before_the_ellipsis(self):
        self.compare_fixture('stackoverflow-clamped-excerpts')

    def test_fractional_border_colors_match_brave_exactly(self):
        self.compare_fixture('stackoverflow-fractional-borders')

    def test_single_svg_paths_preserve_fill_and_stroke_opacity(self):
        self.compare_fixture('forum-single-svg-opacity')

    def test_composited_svg_edges_round_before_blending_with_the_parent(self):
        self.compare_fixture('forum-composited-svg-edges')

    def test_block_text_controls_subtract_border_box_edges_once(self):
        self.compare_fixture('stackoverflow-block-text-control-width')

    def test_svg_rectangles_preserve_fractional_user_coordinates(self):
        self.compare_fixture('forum-fractional-svg-rectangles')

    def test_empty_clips_do_not_change_neighboring_tag_and_avatar_antialiasing(self):
        self.compare_fixture('lobsters-empty-clip-antialiasing')

    def test_empty_accessibility_clips_preserve_the_header_raster(self):
        self.compare_fixture('stackoverflow-empty-accessibility-clip')

    def test_svg_border_fringe_keeps_the_header_on_its_full_raster_tile(self):
        self.compare_fixture('stackoverflow-bordered-header', width=1024, height=768)

    def test_transparent_svg_backgrounds_do_not_change_neighboring_antialiasing(self):
        self.compare_fixture('lobsters-transparent-svg-background')

    def test_modern_svg_color_alpha_survives_solid_paint_conversion(self):
        self.compare_fixture('forum-modern-svg-color-alpha')

    def test_fractional_gaps_keep_forum_counters_on_their_brave_glyph_positions(self):
        self.compare_fixture('stackoverflow-fractional-flex-gap')

    def test_promoted_sidebar_text_blends_through_its_transparent_raster(self):
        self.compare_fixture('stackoverflow-promoted-sidebar-text')

    def test_inert_sticky_text_keeps_its_ancestor_raster(self):
        self.compare_fixture('stackoverflow-inert-sticky-text')

    def test_partial_sticky_recordings_keep_their_container_relative_tile_origin(self):
        self.compare_fixture('stackoverflow-sticky-raster-bounds', width=1024, height=768)

    def test_disjoint_svg_does_not_change_rounded_fallback_coverage(self):
        self.compare_fixture('forum-disjoint-msaa-raster', width=1024, height=768)

    def test_resolved_svg_viewport_coverage_is_not_clipped_twice(self):
        self.compare_fixture('forum-svg-viewport-fringe', width=1024, height=768)

    def test_scroll_pictures_preserve_earlier_children_after_opacity_groups(self):
        self.compare_fixture('forum-resumed-scroll-raster', width=1024, height=768)

    def test_svg_mask_paths_blend_with_the_translated_mask_backdrop(self):
        self.compare_fixture('forum-svg-mask-backdrop')

    def test_single_svg_opacity_keeps_fractional_color_until_painting(self):
        self.compare_fixture('forum-svg-single-paint-opacity', width=1024, height=768)

    def test_svg_solid_paints_retain_fractional_rgb_channels(self):
        self.compare_fixture('forum-svg-fractional-paint', width=1024, height=768)

    def test_rounded_backgrounds_retain_fractional_color_under_the_border(self):
        self.compare_fixture('forum-fractional-rounded-underlay', width=1024, height=768)

    def test_analytic_backgrounds_retain_fractional_color_without_changing_msaa(self):
        self.compare_fixture('forum-analytic-rounded-underlay', width=1024, height=768)

    def test_svg_mask_groups_retain_float_opacity(self):
        self.compare_fixture('forum-svg-mask-group-opacity')

    def test_programmatically_scrollable_sticky_text_keeps_its_compositor_raster(self):
        self.compare_fixture('stackoverflow-programmatic-sticky-text')

    def test_text_after_unclipped_sticky_content_keeps_its_overlap_raster(self):
        self.compare_fixture('stackoverflow-sticky-overlap-text')

    def test_svg_opacity_groups_remain_inside_the_parent_scroll_raster(self):
        self.compare_fixture('stackoverflow-svg-opacity-scroll-raster')

    def test_masked_vector_images_share_the_parent_svg_and_text_raster(self):
        self.compare_fixture('stackoverflow-masked-svg-scroll-raster')

    def test_fractional_underline_colors_keep_precision_in_the_parent_raster(self):
        self.compare_fixture('forum-fractional-underline-color')

    def test_variable_font_underlines_skip_the_instantiated_glyph_ink(self):
        self.compare_fixture('stackoverflow-variable-font-skip-ink')

    def test_css_fades_interpolate_premultiplied_colors(self):
        self.compare_fixture('css-premultiplied-fades', width=1024, height=768)

    def test_culled_scroll_metadata_retains_a_complete_gradient_picture(self):
        self.compare_fixture('culled-scroll-overlap-gradient', width=1280, height=800, scroll_y=6400)

    def test_rounded_color_managed_images_retain_the_complete_gradient_picture(self):
        self.compare_fixture('compositor-rounded-profiled-images', width=1280, height=800, scroll_y=6400)

    def test_translucent_underlines_paint_beneath_glyph_edges(self):
        self.compare_fixture('translucent-underline-paint-order')

    def test_gradient_repetitions_stop_at_the_unobscured_background_destination(self):
        self.compare_fixture('gradient-obscured-border-destination', width=1280, height=800, scroll_y=6400)

    def test_replaced_images_crop_the_source_before_decode_and_sampling(self):
        self.compare_fixture('replaced-image-source-crops', scroll_y=9000)


if __name__ == '__main__':
    unittest.main()
