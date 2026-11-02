import copy
from pathlib import Path
import unittest

import lobsters_browser_instructions as benchmark


class LobstersInstructionTests(unittest.TestCase):
    def test_pinned_fixture_contains_every_story_and_filter_provenance(self):
        expected = benchmark.fixture_expectations(
            Path(__file__).resolve().parents[1] / 'Tests/Browser/Brave/sites/lobsters')
        self.assertEqual(len(expected['story_ids']), 25)
        self.assertEqual(len(expected['images']), 25)
        self.assertEqual(expected['title'], 'Lobsters')

    def expected(self):
        return dict(title='Lobsters', story_ids=['story_a', 'story_b'], story_shortids=['a', 'b'],
                    titles=['First story', 'Second story'], links=['https://a/', 'https://b/'],
                    images=[('/avatar.png', '')])

    def audit(self):
        return dict(url=benchmark.URL, title='Lobsters', ready='complete',
            viewport_width=1024, viewport_height=768, fonts_status='loaded',
            selections=[dict(name='body', count=1, elements=[dict(text='story ' * 1000)]),
                dict(name='stories', count=2, elements=[dict(attributes=dict(id='story_a', **{'data-shortid': 'a'})),
                    dict(attributes=dict(id='story_b', **{'data-shortid': 'b'}))]),
                dict(name='titles', count=2, elements=[dict(text=' First\n story ', attributes=dict(href='https://a/')),
                    dict(text='Second story', attributes=dict(href='https://b/'))]),
                dict(name='images', count=1, elements=[dict(attributes=dict(src='/avatar.png', srcset=''),
                    rect=dict(x=20, y=120, width=16, height=16),
                    image=dict(complete=True, natural_width=16))]),
                dict(name='all', count=1000, elements=[])])

    def test_incomplete_reordered_or_changed_content_cannot_pass(self):
        self.assertTrue(benchmark.validate_document(self.audit(), self.expected())['passed'])
        for mutate in (
            lambda a: a.update(url='https://example.com/'),
            lambda a: a.update(ready='loading'),
            lambda a: a.update(viewport_height=740),
            lambda a: a['selections'][1]['elements'].reverse(),
            lambda a: a['selections'][1]['elements'][0]['attributes'].update({'data-shortid': 'wrong'}),
            lambda a: a['selections'][2]['elements'][0].update(text='Other story'),
            lambda a: a['selections'][2]['elements'][0]['attributes'].update(href='https://wrong/'),
            lambda a: a['selections'][3]['elements'][0]['attributes'].update(srcset='other.png 2x'),
            lambda a: a['selections'][3]['elements'][0]['image'].update(complete=False),
            lambda a: a['selections'][0]['elements'][0].update(text='error page'),
            lambda a: a['selections'][4].update(count=10),
        ):
            audit = copy.deepcopy(self.audit())
            mutate(audit)
            with self.subTest(audit=audit), self.assertRaises(RuntimeError):
                benchmark.validate_document(audit, self.expected())


if __name__ == '__main__':
    unittest.main()
