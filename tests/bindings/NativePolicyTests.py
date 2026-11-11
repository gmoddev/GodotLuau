"""Adversarial generation checks against real pinned Godot metadata."""
import copy
import importlib.util
import json
from pathlib import Path
import unittest

Root = Path(__file__).resolve().parents[2]
Spec = importlib.util.spec_from_file_location('Generator', Root/'tools/GenerateNativeBindings.py')
Generator = importlib.util.module_from_spec(Spec)
Spec.loader.exec_module(Generator)
Policy = json.loads((Root/'bindings/NativePolicy.json').read_text())
Api = json.loads((Root/'godot-cpp/gdextension/extension_api.json').read_text())


class NativePolicyTests(unittest.TestCase):
    def test_registry_uses_actual_metadata(self):
        Data = Generator.Build(Policy, Api)
        Play = next(M for M in Data['Methods'] if M['Class']=='AudioStreamPlayer' and M['Name']=='Play')
        self.assertEqual((Play['Arguments'],Play['Required']),(1,0))
        self.assertEqual(Data['Arguments'][Play['FirstArgument']]['Default'],'0.0')
        Toggle = next(S for S in Data['Signals'] if S['Name']=='Toggled')
        self.assertEqual(Data['Arguments'][Toggle['FirstArgument']]['Kind'],'Boolean')
        self.assertFalse(next(C for C in Data['Classes'] if C['Name']=='Object')['Construct'])

    def Rejected(self, Change):
        Candidate = copy.deepcopy(Policy)
        Change(Candidate)
        with self.assertRaises(ValueError):
            Generator.Build(Candidate, Api)

    def test_non_scene_constructor_denied(self):
        self.Rejected(lambda P:P['Classes'].append({'Name':'FileAccess','Kind':'Resource','Construct':True}))

    def test_unknown_class_denied(self):
        self.Rejected(lambda P:P['Classes'].append({'Name':'NetworkService','Kind':'Node','Construct':True}))

    def test_structural_property_denied(self):
        self.Rejected(lambda P:P['Properties'].append({'Class':'Node','Name':'Script','Native':'script','Kind':'ResourceValue','ResourceClass':'Script'}))

    def test_arbitrary_dispatch_denied(self):
        self.Rejected(lambda P:P['Methods'].append({'Class':'Object','Name':'Invoke','Native':'call','Mutates':True}))

    def test_structural_method_denied(self):
        self.Rejected(lambda P:P['Methods'].append({'Class':'Node','Name':'MoveParent','Native':'reparent','Mutates':True}))

    def test_unsupported_variant_denied(self):
        self.Rejected(lambda P:P['Methods'].append({'Class':'Node','Name':'Tree','Native':'get_tree','Mutates':False}))

    def test_unknown_property_and_signal_denied(self):
        self.Rejected(lambda P:P['Properties'][0].update(Native='wrong_property'))
        self.Rejected(lambda P:P['Signals'][0].update(Native='wrong_signal'))

    def test_invalid_bounds_and_duplicate_policy_denied(self):
        self.Rejected(lambda P:P['Properties'][0].update(Max=-1))
        self.Rejected(lambda P:P['Properties'][0].update(Max=float('inf')))
        self.Rejected(lambda P:P['Classes'].append(copy.deepcopy(P['Classes'][0])))


if __name__=='__main__':
    unittest.main()
