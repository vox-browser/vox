import copy
import unittest

from optimized_sites_memory import summarize_rows, text_hash, validate_generic


class OptimizedSitesMemoryTests(unittest.TestCase):
    def test_complete_content_is_required_despite_a_successful_browser_exit(self):
        expected = dict(title='Home', body_text_sha256=text_hash('a b'), images=[('avatar.png', '')])
        audit = dict(url='https://example.com/', title='Home', ready='complete',
            viewport_width=1024, viewport_height=768, selections=[
                dict(name='body', count=1, elements=[dict(text=' a\n b ')]),
                dict(name='images', count=1, elements=[dict(attributes=dict(src='avatar.png'))])])
        self.assertTrue(validate_generic(audit, expected, audit['url'])['passed'])
        for mutate in (lambda a:a.update(ready='loading'),
                       lambda a:a['selections'][0]['elements'][0].update(text='error'),
                       lambda a:a['selections'][1].update(count=2)):
            broken = copy.deepcopy(audit)
            mutate(broken)
            with self.assertRaises(RuntimeError):
                validate_generic(broken, expected, audit['url'])

    def test_memory_summary_uses_median_peaks_and_retains_pixel_mismatches(self):
        rows = [dict(site='lobsters', engine=e, pair=i, content_exact=True,
                     kernel_exit_status=0, memory=dict(observed_peak_bytes=v), pixels_exact=False)
                for e in ('vox', 'brave') for i,v in enumerate((100, 200),1)]
        result = summarize_rows(rows, 2)
        self.assertEqual(result['lobsters']['vox']['median_observed_peak_bytes'], 150)
        self.assertFalse(result['lobsters']['vox']['all_reference_pixels_exact'])
        for broken in (rows[:-1], [dict(r, kernel_exit_status=1) for r in rows],
                       [dict(r, content_exact=False) for r in rows],
                       [dict(r, memory_error='denied') for r in rows]):
            with self.assertRaises(RuntimeError):
                summarize_rows(broken, 2)


if __name__ == '__main__':
    unittest.main()
