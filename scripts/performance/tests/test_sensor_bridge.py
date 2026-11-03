import importlib.util
import pathlib
import subprocess
import threading
import unittest

path=pathlib.Path(__file__).resolve().parents[2]/"glass-audit"/"simulator-ready-bridge.py"
spec=importlib.util.spec_from_file_location("sensor_bridge",path)
bridge=importlib.util.module_from_spec(spec);spec.loader.exec_module(bridge)

class SensorBridgeRegressionTests(unittest.TestCase):
    def test_blocked_registration_query_cannot_block_sensor_loop(self):
        entered=threading.Event();release=threading.Event()
        def blocked():
            entered.set();release.wait(2)
            return pathlib.Path("/synthetic/new-runner")
        resolver=bridge.AsyncRunnerContainer(blocked,interval=0.01)
        try:
            self.assertTrue(entered.wait(1))
            completed=threading.Event();observed=[]
            def sensor_loop():
                observed.append(resolver.snapshot())
                state=bridge.SensorReadiness()
                state.observe("2026-10-31 05:09:13.044 DANPERNative[1] [com.apple.LocalAuthentication:Client,Interactive] evaluatePolicy:2 options:")
                state.observe("2026-10-31 05:09:23.162 coreauthd[2] [com.apple.LocalAuthentication:Server,Interactive] Mechanism event 5 MechanismPearl")
                observed.append(state.permits(1));completed.set()
            reader=threading.Thread(target=sensor_loop,daemon=True);reader.start()
            self.assertTrue(completed.wait(1),"A stalled simctl lookup blocked actual sensor readiness")
            self.assertEqual(observed,[(None,None),True])
        finally:
            release.set();resolver.close(timeout=1)

    def test_updated_runner_registration_is_observed(self):
        first=threading.Event();second=threading.Event();allow_second=threading.Event();calls=0
        def lookup():
            nonlocal calls
            calls+=1
            if calls==1:first.set();return pathlib.Path("/synthetic/first")
            allow_second.wait(2);second.set();return pathlib.Path("/synthetic/reinstalled")
        resolver=bridge.AsyncRunnerContainer(lookup,interval=0.01)
        try:
            self.assertTrue(first.wait(1))
            # The resolver lock is never held during the blocked external query.
            def current_is(expected):
                for _ in range(100):
                    if resolver.snapshot()[0]==expected:return True
                    threading.Event().wait(0.01)
                return False
            self.assertTrue(current_is(pathlib.Path("/synthetic/first")))
            allow_second.set();self.assertTrue(second.wait(1))
            self.assertTrue(current_is(pathlib.Path("/synthetic/reinstalled")))
        finally:
            allow_second.set();resolver.close(timeout=1)

    def test_query_timeout_preserves_last_known_registration(self):
        calls=0;failed=threading.Event();hold=threading.Event()
        def lookup():
            nonlocal calls
            calls+=1
            if calls==1:return pathlib.Path("/synthetic/current")
            if calls==2:
                failed.set();raise subprocess.TimeoutExpired(["simctl"],5)
            hold.wait(2);return None
        resolver=bridge.AsyncRunnerContainer(lookup,interval=0.01)
        try:
            self.assertTrue(failed.wait(1))
            for _ in range(100):
                value,error=resolver.snapshot()
                if error:break
                threading.Event().wait(0.01)
            self.assertEqual(value,pathlib.Path("/synthetic/current"))
            self.assertEqual(error[0],"TimeoutExpired")
        finally:
            hold.set();resolver.close(timeout=1)

    def test_close_stops_further_registration_queries(self):
        resolver=bridge.AsyncRunnerContainer(lambda:pathlib.Path("/synthetic/current"),interval=0.01)
        resolver.close(timeout=1)
        self.assertFalse(resolver._thread.is_alive())

    def test_old_generation_does_not_authorize_new_request(self):
        state=bridge.SensorReadiness()
        state.observe("2026-10-31 05:09:13.044 DANPERNative[1] [com.apple.LocalAuthentication:Client,Interactive] evaluatePolicy:2 options:")
        state.observe("2026-10-31 05:09:23.162 coreauthd[2] [com.apple.LocalAuthentication:Server,Interactive] Mechanism event 5 MechanismPearl")
        self.assertTrue(state.permits(1));self.assertFalse(state.permits(2))
        state.observe("2026-10-31 05:09:24.001 DANPERNative[1] [com.apple.LocalAuthentication:Client,Interactive] evaluatePolicy:2 options:")
        self.assertFalse(state.permits(2))
        state.observe("2026-10-31 05:09:23.162 coreauthd[2] [com.apple.LocalAuthentication:Server,Interactive] Mechanism event 5 MechanismPearl")
        self.assertFalse(state.permits(2))

    def test_real_stop_event_revokes_sensor_readiness(self):
        state=bridge.SensorReadiness()
        state.observe("2026-10-31 05:09:13.044 DANPERNative[1] [com.apple.LocalAuthentication:Client,Interactive] evaluatePolicy:2 options:")
        state.observe("2026-10-31 05:09:23.162 coreauthd[2] [com.apple.LocalAuthentication:Server,Interactive] Mechanism event 5 MechanismPearl")
        state.observe("2026-10-31 05:09:25.000 coreauthd[2] will stop biometric operation:")
        self.assertFalse(state.permits(1))

class SensorGatedContainerTests(unittest.TestCase):
    def state(self):
        state=bridge.SensorReadiness()
        state.observe('2026-11-03 20:42:22.651 DANPERNative[1] [com.apple.LocalAuthentication:Client,Interactive] evaluatePolicy:2 options:')
        return state
    def active(self,state,stamp='2026-11-03 20:42:23.000'):
        state.observe(stamp+' coreauthd[2] [com.apple.LocalAuthentication:Server,Interactive] Mechanism event 5 MechanismPearl')
    def settle(self,resolver,state,predicate):
        for _ in range(100):
            result=resolver.snapshot(state)
            if predicate(result):return result
            threading.Event().wait(0.01)
        self.fail('The bounded local registration lookup did not settle')
    def test_no_registration_rpc_before_real_sensor_and_no_background_repoll(self):
        calls=[];state=self.state()
        resolver=bridge.SensorGatedRunnerContainer(lambda:calls.append('lookup') or pathlib.Path('/synthetic/current'))
        try:
            for _ in range(20):self.assertEqual(resolver.snapshot(state),(None,None))
            self.assertEqual(calls,[],'Registration RPC must not run during real UI activation')
            self.active(state)
            self.settle(resolver,state,lambda r:r[0] is not None)
            for _ in range(20):self.assertEqual(resolver.snapshot(state),(pathlib.Path('/synthetic/current'),None))
            self.assertEqual(calls,['lookup'],'One successful resolution per actual context, no2s background poll')
        finally:resolver.close(timeout=1)
    def test_new_client_context_needs_its_own_real_sensor_and_registration(self):
        calls=[];state=self.state()
        resolver=bridge.SensorGatedRunnerContainer(lambda:calls.append(1) or pathlib.Path('/synthetic/runner'+str(len(calls))))
        try:
            self.active(state);self.settle(resolver,state,lambda r:r[0] is not None)
            state.observe('2026-11-03 20:42:24.000 DANPERNative[3] [com.apple.LocalAuthentication:Client,Interactive] evaluatePolicy:2 options:')
            self.assertEqual(resolver.snapshot(state),(None,None));self.assertEqual(len(calls),1)
            self.active(state,'2026-11-03 20:42:25.000')
            result=self.settle(resolver,state,lambda r:r[0] is not None)
            self.assertEqual(result[0],pathlib.Path('/synthetic/runner2'));self.assertEqual(len(calls),2)
        finally:resolver.close(timeout=1)
    def test_blocked_previous_context_cannot_supply_path_or_overlap_new_lookup(self):
        entered=threading.Event();release=threading.Event();calls=[];state=self.state()
        def lookup():
            calls.append(1)
            if len(calls)==1:entered.set();release.wait(2);return pathlib.Path('/synthetic/old')
            return pathlib.Path('/synthetic/new')
        resolver=bridge.SensorGatedRunnerContainer(lookup)
        try:
            self.active(state);resolver.snapshot(state);self.assertTrue(entered.wait(1))
            state.observe('2026-11-03 20:42:24.000 DANPERNative[3] [com.apple.LocalAuthentication:Client,Interactive] evaluatePolicy:2 options:')
            self.active(state,'2026-11-03 20:42:25.000')
            for _ in range(20):self.assertEqual(resolver.snapshot(state),(None,None))
            self.assertEqual(len(calls),1,'The old external query must finish before another is started')
            release.set();result=self.settle(resolver,state,lambda r:r[0] is not None)
            self.assertEqual(result[0],pathlib.Path('/synthetic/new'));self.assertEqual(len(calls),2)
        finally:release.set();resolver.close(timeout=1)
    def test_timeout_fails_closed_and_retries_only_with_current_sensor(self):
        calls=[];clock=[0.0];state=self.state()
        def lookup():
            calls.append(1)
            if len(calls)==1:raise subprocess.TimeoutExpired(['simctl'],5)
            return pathlib.Path('/synthetic/current')
        resolver=bridge.SensorGatedRunnerContainer(lookup,clock=lambda:clock[0])
        try:
            self.active(state);result=self.settle(resolver,state,lambda r:r[1] is not None)
            self.assertIsNone(result[0]);self.assertEqual(result[1][0],'TimeoutExpired')
            for _ in range(20):self.assertIsNone(resolver.snapshot(state)[0])
            self.assertEqual(len(calls),1)
            state.observe('2026-11-03 20:42:26.000 coreauthd[2] will stop biometric operation:')
            clock[0]=10
            self.assertEqual(resolver.snapshot(state),(None,None));self.assertEqual(len(calls),1)
            self.active(state,'2026-11-03 20:42:27.000')
            result=self.settle(resolver,state,lambda r:r[0] is not None)
            self.assertEqual(result[0],pathlib.Path('/synthetic/current'));self.assertEqual(len(calls),2)
        finally:resolver.close(timeout=1)
    def test_real_stop_revokes_even_a_previously_resolved_container(self):
        state=self.state();resolver=bridge.SensorGatedRunnerContainer(lambda:pathlib.Path('/synthetic/current'))
        try:
            self.active(state);self.settle(resolver,state,lambda r:r[0] is not None)
            state.observe('2026-11-03 20:42:26.000 coreauthd[2] will stop biometric operation:')
            self.assertEqual(resolver.snapshot(state),(None,None));self.assertFalse(state.permits(1))
        finally:resolver.close(timeout=1)
