import struct
from types import SimpleNamespace
import unittest
import zlib

from measure_load_against_brave import (brave_command, check_viewport, compare, png_size,
                                        readiness_expression)
import measure_load_against_brave


def png(width, height):
    header = struct.pack('>II', width, height) + b'\x08\x06\x00\x00\x00'
    return (b'\x89PNG\r\n\x1a\n' + struct.pack('>I', len(header)) + b'IHDR' + header
            + struct.pack('>I', zlib.crc32(b'IHDR' + header)))


class LoadAgainstBraveTests(unittest.TestCase):
    def test_readiness_waits_for_the_page_origin_and_the_selector(self):
        expression = readiness_expression('https://github.com/vlang/v', 'tr.row a[href*="/commit/"]')
        self.assertIn('origin = "https://github.com/"', expression)
        self.assertIn(r'selector = "tr.row a[href*=\"/commit/\"]"', expression)
        self.assertIn("document.readyState === 'complete'", expression)
        self.assertIn('document.fonts.ready', expression)
        # The harness only awaits the promise; the page polls itself.
        self.assertIn('setTimeout(check, 10)', expression)

    def test_readiness_without_a_selector_or_a_network_origin(self):
        self.assertIn('selector = null', readiness_expression('https://news.ycombinator.com/', None))
        # The calibration page has no host: its whole URL is the prefix.
        self.assertIn('origin = "about:blank"', readiness_expression('about:blank', None))

    def test_png_size_reads_the_header(self):
        self.assertEqual(png_size(png(2048, 1536)), (2048, 1536))
        with self.assertRaisesRegex(ValueError, 'Not a PNG'):
            png_size(b'GIF89a' + bytes(32))

    def test_viewport_and_capture_must_match_the_request(self):
        page = dict(width=1024, height=768, scale=2)
        check_viewport(page, (2048, 1536), 1024, 768, 2)
        # A browser bar that appears while the page loads shrinks the viewport.
        with self.assertRaisesRegex(RuntimeError, r'viewport is \(1024, 712, 2\)'):
            check_viewport(dict(page, height=712), (2048, 1424), 1024, 768, 2)
        with self.assertRaisesRegex(RuntimeError, 'capture is'):
            check_viewport(page, (1024, 768), 1024, 768, 2)

    def test_comparison_reports_medians_rounds_and_the_conservative_reading(self):
        result = compare([400, 420, 410], [500, 430, 415])
        self.assertEqual((result['vox_median_ms'], result['brave_median_ms']), (410, 430))
        self.assertAlmostEqual(result['vox_to_brave'], 410 / 430)
        self.assertEqual(result['rounds_vox_faster'], 3)
        # Vox's slowest launch (420) is not below Brave's fastest (415).
        self.assertFalse(result['slowest_vox_beats_fastest_brave'])
        self.assertTrue(compare([400, 410], [415, 500])['slowest_vox_beats_fastest_brave'])
        self.assertEqual(compare([600, 400], [500, 500])['rounds_vox_faster'], 1)

    def test_brave_launches_a_window_of_the_requested_scale_on_the_replay(self):
        original = measure_load_against_brave.certificate_spki
        measure_load_against_brave.certificate_spki = lambda ca: 'SPKI=' + ca
        try:
            args = SimpleNamespace(brave='/Applications/Brave', position=(40, 30), width=1024,
                                   screenshot_scale=2)
            replay = SimpleNamespace(ready=dict(proxy='socks5h://127.0.0.1:9000', ca='/tmp/ca.pem'))
            command = brave_command(args, '/tmp/profile', replay, 905, 'https://example.test/')
        finally:
            measure_load_against_brave.certificate_spki = original
        self.assertEqual(command[0], '/Applications/Brave')
        self.assertEqual(command[-1], 'https://example.test/')
        for flag in ['--user-data-dir=/tmp/profile', '--window-position=40,30', '--window-size=1024,905',
                     '--force-device-scale-factor=2', '--proxy-server=socks5://127.0.0.1:9000',
                     '--ignore-certificate-errors-spki-list=SPKI=/tmp/ca.pem', '--remote-debugging-port=0']:
            self.assertIn(flag, command)
        # No emulation and no headless mode: the page loads in a normal window.
        self.assertFalse([flag for flag in command if 'headless' in flag])


if __name__ == '__main__':
    unittest.main()
