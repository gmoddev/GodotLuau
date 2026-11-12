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

    def test_coverage_distinguishes_construction_from_api_parity(self):
        Data = Generator.Build(Policy, Api)
        Data['PolicySHA256'] = 'test'
        Coverage = Generator.Coverage(Policy, Api, Data)
        Classes = {C['Name']: C for C in Coverage['Classes']}
        self.assertEqual(Coverage['Summary']['MetadataClasses'], len(Api['classes']))
        self.assertTrue(Classes['Node3D']['Constructible'])
        self.assertEqual(Classes['Node3D']['Status'], 'Partial')
        self.assertEqual(Classes['OS']['Status'], 'Restricted')
        self.assertEqual(Classes['Tween']['Status'], 'Blocked')
        self.assertIn('get_tree', Classes['Node']['Members']['methods']['Restricted'])
        self.assertEqual(Coverage['Summary']['SelectedMethods'], len(Data['Methods']))

    def Rejected(self, Change):
        Candidate = copy.deepcopy(Policy)
        Change(Candidate)
        with self.assertRaises(ValueError):
            Generator.Build(Candidate, Api)

    def test_non_scene_constructor_denied(self):
        self.Rejected(lambda P:P['Classes'].append({'Name':'FileAccess','Kind':'Resource','Construct':True,'Authority':'OwnedScene'}))

    def test_unknown_class_denied(self):
        self.Rejected(lambda P:P['Classes'].append({'Name':'NetworkService','Kind':'Node','Construct':True,'Authority':'OwnedScene'}))

    def test_structural_property_denied(self):
        self.Rejected(lambda P:P['Properties'].append({'Class':'Node','Name':'Script','Native':'script','Kind':'ResourceValue','ResourceClass':'Script','Authority':'OwnedScene'}))

    def test_arbitrary_dispatch_denied(self):
        self.Rejected(lambda P:P['Methods'].append({'Class':'Object','Name':'Invoke','Native':'call','Mutates':True,'Authority':'OwnedScene'}))

    def test_structural_method_denied(self):
        self.Rejected(lambda P:P['Methods'].append({'Class':'Node','Name':'MoveParent','Native':'reparent','Mutates':True,'Authority':'OwnedScene'}))

    def test_unsupported_variant_denied(self):
        self.Rejected(lambda P:P['Methods'].append({'Class':'Node','Name':'Tree','Native':'get_tree','Mutates':False,'Authority':'OwnedScene'}))

    def test_object_return_requires_explicit_scoped_node_projection(self):
        self.Rejected(lambda P:P['Methods'].append({'Class':'Node','Name':'Parent','Native':'get_parent','Mutates':False,'Authority':'OwnedScene','ReturnNodeClass':'Window'}))
        self.Rejected(lambda P:P['Methods'].append({'Class':'RayCast3D','Name':'RawCollider','Native':'get_collider','Mutates':False,'Authority':'OwnedScene'}))

    def test_unknown_property_and_signal_denied(self):
        self.Rejected(lambda P:P['Properties'][0].update(Native='wrong_property'))
        self.Rejected(lambda P:P['Signals'][0].update(Native='wrong_signal'))

    def test_invalid_bounds_and_duplicate_policy_denied(self):
        self.Rejected(lambda P:P['Properties'][0].update(Max=-1))
        self.Rejected(lambda P:P['Properties'][0].update(Max=float('inf')))
        self.Rejected(lambda P:P['Classes'].append(copy.deepcopy(P['Classes'][0])))

    def test_explicit_authorization_required(self):
        self.Rejected(lambda P:P['Methods'][0].pop('Authority'))
        self.Rejected(lambda P:P['Classes'][0].update(Authority='GlobalEngine'))

    def test_native_window_and_resource_signal_denied(self):
        self.Rejected(lambda P:P['Classes'].append({'Name':'Window','Kind':'Node','Construct':True,'Authority':'OwnedScene'}))
        self.Rejected(lambda P:P['Signals'].append({'Class':'Resource','Name':'Changed','Native':'changed','Authority':'OwnedScene'}))

    def test_defaults_observations_and_collection_rules(self):
        Data=Generator.Build(Policy,Api)
        Play=next(M for M in Data['Methods'] if M['Class']=='AnimatedSprite2D' and M['Name']=='Play')
        self.assertEqual(Data['Arguments'][Play['FirstArgument']]['Default'],'')
        List=next(M for M in Data['Methods'] if M['Class']=='ItemList' and M['Name']=='AddItem')
        self.assertEqual(Data['Arguments'][List['FirstArgument']+1]['Default'],'null')
        self.assertEqual(List['CountLimit'],1024)
        self.assertTrue(next(P for P in Data['Properties'] if P['Class']=='Timer' and P['Name']=='TimeLeft')['ReadOnly'])
        self.Rejected(lambda P:P['Methods'].append({'Class':'ItemList','Name':'Bad','Native':'select','Mutates':True,'Authority':'OwnedScene','Validation':{'Index':{'Argument':'idx','Query':'get_tree'}}}))


if __name__=='__main__':
    unittest.main()
