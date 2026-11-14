import copy
from pathlib import Path
from types import SimpleNamespace
import unittest

import github_hydrated_render as render
import measure_browser_instructions as measurement


def audit():
    return dict(url=render.URL, ready='complete', viewport_width=1024, viewport_height=768,
                selections=[dict(name=name, count=len(elements), elements=elements)
                            for name, elements in {
                                'rows': [dict(text='README.mdFix documentation', attributes={'id': 'folder-row-0'})],
                                'latest': [dict(text='Fix documentation', attributes={'id': ''})],
                                'readme': [dict(text='The complete README', attributes={'id': ''})],
                                'commits': [dict(text='Fix documentation', attributes={'id': '', 'href': '/vlang/v/commit/abc'})],
                            }.items()])


class HydratedRenderTests(unittest.TestCase):
    def test_ssr_names_and_partial_rows_cannot_pass_retained_react_text(self):
        expected = render.content(audit())
        for name, text in [('rows', 'README.md'), ('latest', ''), ('readme', 'The complete')]:
            changed = copy.deepcopy(audit())
            next(g for g in changed['selections'] if g['name'] == name)['elements'][0]['text'] = text
            with self.assertRaises(ValueError):
                render.validate(changed, expected)
        missing = audit()
        next(g for g in missing['selections'] if g['name'] == 'commits')['elements'].clear()
        with self.assertRaises(ValueError):
            render.content(missing)

    def test_readiness_requires_each_pinned_row_without_nested_has(self):
        expected = render.content(audit())
        expected['rows'].append(dict(id='folder-row-1', text='docCommit text'))
        selector = render.ready_selector(expected)
        self.assertIn(':has(#folder-row-0 a[href*="/commit/"])', selector)
        self.assertIn(':has(#folder-row-1 a[href*="/commit/"])', selector)
        self.assertIn('[data-testid=sponsor-button]:not([aria-disabled="true"])', selector)
        self.assertNotIn(':has(tr', selector)

    def test_capture_rejects_errors_wrong_viewport_and_reordered_identity(self):
        expected = render.content(audit())
        for update in [dict(javascript_diagnostics=['author failed']),
                       dict(native_reported_errors=['native failed']),
                       dict(native_reported_error_count=1),
                       dict(native_reported_error_information=['native failed']),
                       dict(url='https://github.com/login'), dict(ready='loading'),
                       dict(viewport_height=700)]:
            with self.assertRaises(ValueError):
                render.validate(dict(audit(), **update), expected)
        changed = audit()
        changed['selections'][0]['elements'][0]['attributes']['id'] = 'folder-row-2'
        with self.assertRaises(ValueError):
            render.validate(changed, expected)
        render.validate(audit(), expected)

    def test_windowed_comparison_and_document_viewport_are_explicit(self):
        args = SimpleNamespace(width=1024, height=768, url=render.URL, vox_chrome_height=112,
                               vox_arg=['--enable-javascript'])
        cmd = measurement.vox_launch_command(args, Path('/Vox'), Path('/out.png'))
        self.assertEqual(cmd[cmd.index('--window-height') + 1], '880')
        self.assertIn('--enable-javascript', cmd)
        args.chrome_windowed = True
        self.assertNotIn('--headless=new', measurement.chrome_launch_command(args, Path('/Brave'), '/profile'))
        args.chrome_windowed = False
        self.assertIn('--headless=new', measurement.chrome_launch_command(args, Path('/Brave'), '/profile'))


if __name__ == '__main__':
    unittest.main()
