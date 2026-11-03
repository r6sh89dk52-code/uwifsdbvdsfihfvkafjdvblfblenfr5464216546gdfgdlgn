import importlib.util,json,pathlib,subprocess,sys,tempfile,threading,time,unittest
from types import SimpleNamespace
from unittest.mock import patch
ROOT=pathlib.Path(__file__).resolve().parents[1];sys.path.insert(0,str(ROOT))
import coordinated_capture as m
from verify_diagnostic_products import manifest
from make_coordinated_ui import instrument
SIM='D2899314-285E-4785-A590-1AFF54ED4A34'
CONTROL='danper-profile-3E380B51-8D4D-4A18-AD00-A4E28A4D5266.json'
OWN='/Users/runner/Library/Developer/CoreSimulator/Devices/'+SIM+'/data/Containers/Bundle/Application/UUID/DANPERNative.app/DANPERNative'
REAL_POPEN=subprocess.Popen
class CoordinatedProtocolTests(unittest.TestCase):
 def test_only_owned_actual_app_executable_is_accepted(self):
  self.assertTrue(m.owned_executable(OWN,SIM))
  for p in [None,OWN.replace(SIM,'FOREIGN'),OWN.replace('DANPERNative.app/DANPERNative','Runner.app/Runner'),'python --argument='+OWN]:self.assertFalse(m.owned_executable(p,SIM))
 def test_ack_is_confined_to_owned_runner_tmp(self):
  with tempfile.TemporaryDirectory() as d:
   root=pathlib.Path(d);(root/'tmp').mkdir();p=root/'tmp'/CONTROL
   self.assertEqual(m.completion_path('DANPER_PROFILE_COMPLETED_ACK '+str(p),root),p)
   for p in [root/CONTROL,root/'tmp/..'/CONTROL,pathlib.Path('/another/runner/tmp')/CONTROL,root/'tmp/clinical.json']:
    with self.assertRaises(ValueError):m.completion_path('DANPER_PROFILE_COMPLETED_ACK '+str(p),root)
 def test_ambiguous_completion_and_replaced_process_are_rejected(self):
  with self.assertRaises(ValueError):m.completion_path('DANPER_PROFILE_COMPLETED_ACK /a\nDANPER_PROFILE_COMPLETED_ACK /b',pathlib.Path('/'))
  with self.assertRaises(ValueError):m.activated_pid('DANPER_PROFILE_ACTIVATED_APPLICATION Attributes: pid: 1\nDANPER_PROFILE_ACTIVATED_APPLICATION Attributes: pid: 2')
 def test_substituted_tmp_is_rejected(self):
  with tempfile.TemporaryDirectory() as d:
   root=pathlib.Path(d);(root/'foreign').mkdir();(root/'tmp').symlink_to(root/'foreign',target_is_directory=True)
   with self.assertRaises(ValueError):m.completion_path('DANPER_PROFILE_COMPLETED_ACK '+str(root/'tmp'/CONTROL),root)
 def test_ack_never_overwrites_existing_file_or_link(self):
  with tempfile.TemporaryDirectory() as d:
   root=pathlib.Path(d);p=root/CONTROL;m.write_ack(p,0)
   with self.assertRaises(FileExistsError):m.write_ack(p,1)
   self.assertEqual(json.loads(p.read_text()),{'recorderExit':0})
   link=root/'link';link.symlink_to(p)
   with self.assertRaises(FileExistsError):m.write_ack(link,7)
   self.assertEqual(json.loads(p.read_text())['recorderExit'],0)
 def test_product_manifest_rejects_escape_from_compiled_root(self):
  with tempfile.TemporaryDirectory() as d:
   root=pathlib.Path(d);(root/'products').mkdir();(root/'private').write_text('outside')
   (root/'products/link').symlink_to(root/'private')
   with self.assertRaises(AssertionError):manifest(root/'products')
 def test_diagnostic_hooks_preserve_every_original_clinical_assertion(self):
  source=(ROOT.parents[1]/'native-ios/InteractionTests/N2AllergySaveInteractionTests.swift').read_text()
  generated=instrument(source)
  original=[line.strip() for line in source.splitlines() if 'XCTAssert' in line]
  self.assertTrue(all(line in generated for line in original))
  self.assertEqual(generated.count('func test'),source.count('func test'))
 def test_diagnostic_hooks_cannot_be_applied_twice(self):
  source=(ROOT.parents[1]/'native-ios/InteractionTests/N2AllergySaveInteractionTests.swift').read_text()
  with self.assertRaises(AssertionError):instrument(instrument(source))
 def test_current_runner_reinstall_is_resolved_with_scoped_public_lookup(self):
  data='/Users/runner/Library/Developer/CoreSimulator/Devices/'+SIM+'/data/Containers/Data/Application/7F172BD7-F7C2-43ED-9C14-72AF9ECBD948'
  with patch.object(m.subprocess,'check_output',return_value=data) as query:
   self.assertEqual(str(m.current_runner_data(SIM,OWN)),data)
   self.assertEqual(query.call_args.args[0],['xcrun','simctl','get_app_container',SIM,m.BUNDLE+'.interactiontests.xctrunner','data'])
 def test_actual_lookup_cannot_redirect_to_another_device(self):
  foreign='/Users/runner/Library/Developer/CoreSimulator/Devices/FOREIGN/data/Containers/Data/Application/7F172BD7-F7C2-43ED-9C14-72AF9ECBD948'
  with patch.object(m.subprocess,'check_output',return_value=foreign):
   with self.assertRaises(ValueError):m.current_runner_data(SIM,OWN)
 def run_recorder_protocol(self,exit_code):
  # Real owned Python recorder child + real SIGINT + on-disk acknowledgment.
  # Tool exports are explicit fictitious protocol inputs, NOT Xcode evidence.
  with tempfile.TemporaryDirectory() as d:
   root=pathlib.Path(d);(root/'tmp').mkdir();out=root/'capture';out.mkdir();ready=root/'ready';ui=root/'ui.log';ack=root/'tmp'/CONTROL
   a=SimpleNamespace(output=out,sim=SIM,pid=123,template='Time Profiler',ready=ready,ui_log=ui,runner_data=root)
   def tool(args,log,timeout):
    log.write_text('--instrument os_signpost')
    if '--output' in args:
     target=pathlib.Path(args[args.index('--output')+1])
     if '--toc' in args:target.write_text('<trace-toc><run><data><table schema="time-profile"/><table schema="os-signpost-interval"/></data></run></trace-toc>')
     elif 'os-signpost-interval' in target.name:target.write_text('<trace-query-result><row><start-time>1</start-time><duration>1200000</duration><layout-id/><string>Confirmed allergy save</string><category/><subsystem>pe.danper.saludmovil.performance</subsystem><id/><process/><process/></row></trace-query-result>')
     else:target.write_text('<trace-query-result><row/></trace-query-result>')
    return 0
   def recorder(args,stdout,stderr):
    pathlib.Path(args[args.index('--output')+1]).mkdir()
    code='import signal,time,sys\nsignal.signal(signal.SIGINT,lambda *_:sys.exit('+str(exit_code)+'))\nprint("Starting recording with the actual test child",flush=True)\nwhile True:time.sleep(.1)'
    return REAL_POPEN([sys.executable,'-u','-c',code],stdout=stdout,stderr=stderr)
   def workload():
    until=time.monotonic()+12
    while not ready.exists() and time.monotonic()<until:time.sleep(.02)
    ui.write_text('DANPER_PROFILE_ACTIVATED_APPLICATION Attributes: Application, pid: 123\nDANPER_PROFILE_SAVE_INTERVAL_MS 25.5\nDANPER_PROFILE_COMPLETED_ACK '+str(ack)+'\n')
   t=threading.Thread(target=workload);t.start()
   devices={'devices':{'iOS':[{'udid':SIM,'name':'DANPER-SYNTHETIC-test','state':'Booted'}]}}
   with patch.object(m,'current_runner_data',return_value=root),patch.object(m,'kernel_path',return_value=OWN),patch.object(m,'command',side_effect=tool),patch.object(m.subprocess,'check_output',return_value=json.dumps(devices)),patch.object(m.subprocess,'Popen',side_effect=recorder):result=m.capture(a)
   t.join();response=json.loads(ack.read_text())
   self.assertEqual(response['recorderExit'],exit_code)
   self.assertEqual(result['successful'],exit_code==0)
   self.assertTrue(result['singleStopRequested'])
   if exit_code==0:self.assertEqual(result['confirmedAllergySaveMS'],[1.2])
 def test_real_recorder_stop_acknowledges_only_success(self):self.run_recorder_protocol(0)
 def test_real_nonzero_recorder_is_not_approved(self):self.run_recorder_protocol(7)
if __name__=='__main__':unittest.main()
