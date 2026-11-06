import json
from pathlib import Path
import subprocess
import re
import sys
import tempfile
import unittest

from measure_precise_scroll import instruction_counters


def counter_log(publication_first=False):
    base = 2**60
    rows = {'start': (0, 0), 'input_end': (50, 100000),
            'publication_end': (70, 120000), 'complete': (70, 120000)}
    if publication_first:
        rows['input_end'], rows['publication_end'] = rows['publication_end'], rows['input_end']
    return '\n'.join(f'SCROLL_COUNTER {phase} pid=42 start_ticks=123 instructions={base+delta} '
                     f'cycles={base+2*delta} user_ns={1000000+delta*1000} system_ns={500000+delta*100} t_us={time}'
                     for phase, (delta, time) in rows.items())


class ScrollInstructionTests(unittest.TestCase):
    def test_preserves_large_integer_counts_and_both_publication_orders(self):
        for publication_first in (False, True):
            measured = instruction_counters(counter_log(publication_first), 10)
            self.assertEqual(measured['instructions'], 70)
            self.assertEqual(measured['cycles'], 140)
            self.assertEqual(measured['instructions_per_input'], 7)
            self.assertEqual(measured['cpu_ms'], .077)
            self.assertEqual(measured['wall_ms'], 120)
            self.assertTrue(measured['diagnostic_only'])
        self.assertIsNone(instruction_counters('SCROLL_DONE inputs=10', 10))

    def test_rejects_missing_duplicate_changed_identity_and_regressing_samples(self):
        log = counter_log()
        invalid = [log.rsplit('\n', 1)[0], log+'\n'+log.splitlines()[0],
                   log.replace('SCROLL_COUNTER complete pid=42', 'SCROLL_COUNTER complete pid=43'),
                   log.replace('SCROLL_COUNTER complete', 'SCROLL_COUNTER unexpected'),
                   log.replace(f'instructions={2**60+70}', f'instructions={2**60-1}'),
                   log.replace('t_us=120000', 't_us=-1'),
                   log.replace('t_us=120000', 't_us=NaN'),
                   log.replace(' t_us=0', ''),
                   log.replace('pid=42', 'pid=0')]
        for source in invalid:
            with self.subTest(source=source), self.assertRaises(ValueError):
                instruction_counters(source, 10)

    @unittest.skipUnless(sys.platform == 'darwin', 'macOS native hardware counter')
    def test_native_reader_uses_live_hardware_counter_and_fails_closed(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            source = root/'counter.m'
            observer = Path(__file__).with_name('measure_precise_scroll_darwin.m')
            source.write_text('#include "'+str(observer)+'"\n'+r'''
int main(int argc, char **argv) {
    count_instructions=YES;
    if (argc==1) {
        void *library=dlopen("/usr/lib/libproc.dylib",RTLD_LAZY|RTLD_LOCAL);
        read_process_usage=dlsym(library,"proc_pid_rusage");
    }
    started=CACurrentMediaTime();
    struct timespec cpu_start,cpu_end;
    clock_gettime(CLOCK_PROCESS_CPUTIME_ID,&cpu_start);
    read_counter(&counter_start);
    volatile unsigned long long work=0;
    for(unsigned i=0;i<10000000;++i)work+=i;
    read_counter(&counter_input_end);
    read_counter(&counter_publication_end);counter_complete=counter_publication_end;
    clock_gettime(CLOCK_PROCESS_CPUTIME_ID,&cpu_end);
    fprintf(stderr,"REFERENCE_CPU_NS %llu\n",(unsigned long long)(
        (cpu_end.tv_sec-cpu_start.tv_sec)*1000000000ll+cpu_end.tv_nsec-cpu_start.tv_nsec));
    print_counter("start",&counter_start);print_counter("input_end",&counter_input_end);
    print_counter("publication_end",&counter_publication_end);print_counter("complete",&counter_complete);
    return work==0;
}
''')
            binary = root/'counter'
            subprocess.run(['clang','-O2','-fobjc-arc',str(source),'-framework','Cocoa',
                            '-framework','QuartzCore','-Wl,-undefined,dynamic_lookup','-o',str(binary)],check=True)
            result = subprocess.run([str(binary)],capture_output=True,text=True,check=True)
            measured = instruction_counters(result.stderr, 10)
            self.assertGreater(measured['instructions'], 100000)
            self.assertGreater(measured['cpu_ms'], 0)
            reference_ms = int(re.search(r'REFERENCE_CPU_NS (\d+)', result.stderr)[1]) / 1e6
            self.assertGreater(measured['cpu_ms'] / reference_ms, .8)
            self.assertLess(measured['cpu_ms'] / reference_ms, 1.2)
            failed = subprocess.run([str(binary),'missing-reader'],capture_output=True,text=True)
            self.assertEqual(failed.returncode, 2)
            self.assertIn('SCROLL_ERROR hardware instruction counter failed',failed.stderr)


if __name__ == '__main__':
    unittest.main()
