import json
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

from seal_parallel_compare import capture, compile_plan


@unittest.skipUnless(shutil.which('clang'), 'clang required')
class SealedSplitTest(unittest.TestCase):
    def test_actual_plan_uses_preprocessed_inputs(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            captured = root / 'sealed'
            clang = str(Path(shutil.which('clang')).resolve())
            header = root / 'number.h'
            header.write_text('#define NUMBER 42\n')
            units = []
            for index, text in enumerate([
                '#include "number.h"\nint answer(void) {return NUMBER;}\n',
                'int answer(void); int main(void) {return answer() == 42 ? 0 : 1;}\n',
            ]):
                source = root / f'unit_{index}.c'
                source.write_text(text)
                obj = source.with_suffix('.o')
                self.assertEqual(capture(['-O2', '-x', 'c', '-c', str(source), '-o', str(obj)], captured, clang), 0)
                self.assertIn(b'NOT_COMPILED', obj.read_bytes())
                units.append(obj)
            placeholder = root / 'not-an-executable'
            capture([*map(str, units), '-o', str(placeholder)], captured, clang)
            header.write_text('#error must never be read by optimizing compile\n')
            for index in range(2):
                (root / f'unit_{index}.c').unlink()
            compile_plan(captured, jobs=2)
            subprocess.run([str(captured / 'Vox')], check=True)
            self.assertTrue(json.loads((captured / 'compiled.json').read_text())['complete'])

    def test_changed_sealed_unit_fails_closed(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            captured = root / 'sealed'
            clang = str(Path(shutil.which('clang')).resolve())
            source = root / 'unit_0.c'
            source.write_text('int main(void) { return 0; }\n')
            obj = source.with_suffix('.o')
            capture(['-c', str(source), '-o', str(obj)], captured, clang)
            capture([str(obj), '-o', str(root / 'placeholder')], captured, clang)
            next(captured.glob('*.i')).write_text('invalid\n')
            with self.assertRaisesRegex(RuntimeError, 'Frozen build input changed'):
                compile_plan(captured)


if __name__ == '__main__':
    unittest.main()
