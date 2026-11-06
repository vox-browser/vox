import unittest

import benchmark_hacker_news as benchmark


class HackerNewsGGMeasurementTests(unittest.TestCase):
    def test_coverage_separates_startup_from_scrolling_and_declines(self):
        result = benchmark.coverage('''VOX_GG enabled text=true shapes=true paths=true
VOX_GG text device_clip=1 drawn=1
SCROLL_READY title=Hacker News settle_seconds=4
VOX_GG path stroke=1 drawn=0
SCROLL_START precise=1
VOX_GG text device_clip=1 drawn=1
VOX_GG text device_clip=1 drawn=1
VOX_GG text device_clip=1 drawn=0
VOX_GG shape fill=1 msaa=0 drawn=1
SCROLL_DONE inputs=600 publications=300
VOX_GG text device_clip=1 drawn=1
''')
        self.assertEqual(result['startup'], {
            'text device_clip=1': {'drawn': 1, 'declined': 0},
            'path stroke=1': {'drawn': 0, 'declined': 1}})
        self.assertEqual(result['input_and_final_publication'], {
            'text device_clip=1': {'drawn': 2, 'declined': 1},
            'shape fill=1 msaa=0': {'drawn': 1, 'declined': 0}})

    def test_instruction_statistics_preserve_raw_large_integer_counts(self):
        values = [2**60+11, 2**60+1, 2**60+7]
        result = benchmark.stats(values)
        self.assertEqual(result['median'], 2**60+7)
        self.assertEqual(result['values'], values)

    def test_counter_endpoint_is_exact_and_must_be_unique(self):
        line = f'Vox instructions cumulative: capture_document_encoded {2**60+7}\n'
        self.assertEqual(benchmark.encoded_instructions(line), 2**60+7)
        for invalid in ('', line+line, line.replace(str(2**60+7), '0')):
            with self.subTest(invalid=invalid), self.assertRaises(RuntimeError):
                benchmark.encoded_instructions(invalid)


if __name__ == '__main__':
    unittest.main()
