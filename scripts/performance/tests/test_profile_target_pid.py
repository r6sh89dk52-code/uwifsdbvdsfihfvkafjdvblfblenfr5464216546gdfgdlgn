import importlib.util,os,subprocess,sys,tempfile,threading,time,unittest
from pathlib import Path

spec=importlib.util.spec_from_file_location('profile_target_pid',Path(__file__).parents[1]/'profile_target_pid.py')
target=importlib.util.module_from_spec(spec);spec.loader.exec_module(target)

class ProfileTargetTests(unittest.TestCase):
    sim='11111111-2222-3333-4444-555555555555'
    prefix='/Users/runner/Library/Developer/CoreSimulator/Devices/'+sim+'/data/Containers/Bundle/Application/AAA/'
    ui="""Test Case '-[DANPERInteractionTests.N2AllergySaveInteractionTests testEmptyRosterSearchAndConfirmedAllergySaveSurviveDraftAndReopen]' started.
    t = 0.00s Start Test at 2026-11-02 23:59:58.000
    t = 0.20s Open pe.danper.saludmovil.native.iloaderpreview
    t = 0.30s Launch pe.danper.saludmovil.native.iloaderpreview
    t = 8.00s Wait for pe.danper.saludmovil.native.iloaderpreview to idle
"""
    def event(self,pid,stamp='2026-11-03 00:00:02.000'):
        return stamp+' Df DANPERNative['+str(pid)+':ab12] [com.apple.UIKit:Application] lifecycle'
    def test_selects_actual_owned_process_after_explicit_launch_across_midnight(self):
        paths={40:self.prefix+'DANPERNative.app/DANPERNative'}
        self.assertEqual(target.select_owned_pid(self.ui,self.event(40),self.sim,paths.get),'40')
    def test_native_fixture_before_ui_launch_is_not_eligible(self):
        calls=[]
        def query(pid):calls.append(pid);return self.prefix+'DANPERNative.app/DANPERNative'
        self.assertIsNone(target.select_owned_pid(self.ui,self.event(20,'2026-11-02 23:59:57.000'),self.sim,query))
        self.assertEqual(calls,[])
    def test_does_not_probe_any_process_until_explicit_launch_is_ready(self):
        def forbidden(_):self.fail('Process lookup before actual UI launch')
        self.assertIsNone(target.select_owned_pid('Waiting for tests',self.event(40),self.sim,forbidden))
        self.assertIsNone(target.select_owned_pid(self.ui.replace('to idle','unrelated marker'),self.event(40),self.sim,forbidden))
    def test_foreign_simulator_and_test_runner_are_rejected(self):
        paths={40:self.prefix.replace(self.sim,'OTHER-DEVICE')+'DANPERNative.app/DANPERNative',
               41:self.prefix+'DANPERInteractionTests-Runner.app/Runner'}
        self.assertIsNone(target.select_owned_pid(self.ui,self.event(40)+'\n'+self.event(41),self.sim,paths.get))
    def test_dead_transient_process_is_not_reused(self):
        paths={42:self.prefix+'DANPERNative.app/DANPERNative'}
        self.assertEqual(target.select_owned_pid(self.ui,self.event(42)+'\n'+self.event(43),self.sim,paths.get),'42')
    def test_path_inside_an_argument_cannot_spoof_kernel_executable(self):
        paths={40:'/usr/bin/python3 --fake '+self.prefix+'DANPERNative.app/DANPERNative'}
        # Kernel paths cannot contain command-line arguments; reject whitespace
        # rather than treating a command string as executable-path evidence.
        self.assertIsNone(target.select_owned_pid(self.ui,self.event(40),self.sim,paths.get))

class OwnedRecorderTests(unittest.TestCase):
    def setUp(self):
        spec=importlib.util.spec_from_file_location('profile_preparation',Path(__file__).parents[1]/'prepare_active_profile.py')
        module=importlib.util.module_from_spec(spec);spec.loader.exec_module(module)
        self.entry={}
        namespace={'Path':Path,'os':os,'subprocess':subprocess,'time':time,'signal':__import__('signal'),'entry':self.entry}
        exec(module.SUPERVISOR,namespace)
        self.record=namespace['record_until_workload_done']
    def test_finished_workload_stops_only_owned_recorder_and_preserves_its_exit(self):
        with tempfile.TemporaryDirectory() as folder:
            ready=Path(folder)/'ready';done=Path(folder)/'done'
            old=os.environ.get('DANPER_PROFILE_WORKLOAD_DONE');os.environ['DANPER_PROFILE_WORKLOAD_DONE']=str(done)
            def finish():
                deadline=time.monotonic()+5
                while not ready.exists() and time.monotonic()<deadline:time.sleep(.01)
                done.write_text('0')
            thread=threading.Thread(target=finish);thread.start()
            try:
                code="import signal,time,pathlib,sys;signal.signal(signal.SIGINT,lambda *_:sys.exit(0));pathlib.Path(sys.argv[1]).write_text('ready');time.sleep(20)"
                result=self.record([sys.executable,'-c',code,str(ready)],subprocess.DEVNULL,subprocess.STDOUT,8)
                self.assertEqual(result.returncode,0)
                self.assertTrue(self.entry['stoppedAfterWorkload'])
            finally:
                thread.join(timeout=6)
                if old is None:os.environ.pop('DANPER_PROFILE_WORKLOAD_DONE',None)
                else:os.environ['DANPER_PROFILE_WORKLOAD_DONE']=old
    def test_natural_recorder_failure_is_not_relabelled_as_success(self):
        with tempfile.TemporaryDirectory() as folder:
            old=os.environ.get('DANPER_PROFILE_WORKLOAD_DONE');os.environ['DANPER_PROFILE_WORKLOAD_DONE']=str(Path(folder)/'absent')
            try:
                result=self.record([sys.executable,'-c','raise SystemExit(7)'],subprocess.DEVNULL,subprocess.STDOUT,3)
                self.assertEqual(result.returncode,7)
                self.assertNotIn('stoppedAfterWorkload',self.entry)
            finally:
                if old is None:os.environ.pop('DANPER_PROFILE_WORKLOAD_DONE',None)
                else:os.environ['DANPER_PROFILE_WORKLOAD_DONE']=old

if __name__=='__main__':unittest.main()
