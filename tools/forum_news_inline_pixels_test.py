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
    def compare_fixture(self, name, width=800, height=600, scroll_y=0):
        output = Path(tempfile.mkdtemp(prefix='forum-news-inline-', dir=REPO / 'Build'))
        fixture = REPO / 'Tests/Browser/Brave/input' / (name + '.html')
        reference = REPO / 'Tests/Browser/Brave/expected' / (name + '.png')
        actual = output / 'actual.png'
        environment = {k:v for k,v in os.environ.items()
                       if not k.lower().endswith('_proxy') and not k.startswith(('VOX_', 'LADYBIRD_', 'DYLD_', 'GC_'))}
        environment.update(VOX_PROFILE_DIR=str(output / 'profile'), VOX_TEST_WINDOW='1',
            VOX_CAPTURE_DOCUMENT_ONLY='1', LADYBIRD_SCREENSHOT_SCALE='1',
            LADYBIRD_SCREENSHOT_DELAY_SECONDS='0')
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
