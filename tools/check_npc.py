#!/usr/bin/env python3
"""Compile and exercise NPC Creator's pure and mocked Roblox boundaries."""
from pathlib import Path
import argparse
import subprocess
import tempfile
import xml.etree.ElementTree as ET
from build import ROOT
from build_npc import build_npc


def check_npc(luau, compiler):
    for path in sorted([*ROOT.glob('src/npc/*.luau'), *ROOT.glob('tests/npc*.luau')]):
        subprocess.run([compiler, str(path)], check=True, stdout=subprocess.DEVNULL)
    subprocess.run([luau, 'tests/npc.spec.luau'], cwd=ROOT, check=True)
    with tempfile.TemporaryDirectory() as temporary:
        for kind, modules in {'rig': ['Model'], 'manager': ['Model'], 'preview': [], 'editor': ['Model'], 'behavior': []}.items():
            spec = ROOT / f'tests/npc-{kind}.spec.luau'
            assert spec.is_file(), f"Missing required NPC harness: {spec}"
            sources = 'local Fixture=(function()\n' + (ROOT / 'tests/npc-fixture.luau').read_text() + '\nend)()\n' + ''.join('local ' + name + '=(function()\n' + (ROOT / 'src/npc' / (name + '.luau')).read_text() + '\nend)()\n' for name in modules)
            filename = 'Behavior.server.luau' if kind == 'behavior' else kind.title() + '.luau'
            test = Path(temporary) / (kind + '.luau')
            test.write_text(sources + 'local ' + kind.upper() + '_SOURCE=[====[\n' + (ROOT / 'src/npc' / filename).read_text() + '\n]====]\n' + spec.read_text())
            subprocess.run([luau, str(test)], cwd=ROOT, check=True)
        output = Path(temporary) / 'NPCCreatorPro.rbxmx'
        build_npc(output)
        xml = ET.parse(output).getroot()
        refs = [n.attrib['referent'] for n in xml.iter('Item')]
        assert len(refs) == len(set(refs))
        plugin = xml.find('Item')
        assert plugin.find('Properties/ProtectedString').text == (ROOT / 'src/npc/Plugin.server.luau').read_text()
        children = {n.find('Properties/string').text: n for n in plugin.findall('Item')}
        assert set(children) == {'Model', 'Rig', 'Preview', 'Manager', 'Editor', 'Templates'}
        for name in ('Model', 'Rig', 'Preview', 'Manager', 'Editor'):
            assert children[name].find('Properties/ProtectedString').text == (ROOT / 'src/npc' / (name + '.luau')).read_text()
        templates = children['Templates'].findall('Item')
        assert len(templates) == 1 and templates[0].find('Properties/string').text == 'Behavior'
        assert templates[0].find('Properties/string[@name="Value"]').text == (ROOT / 'src/npc/Behavior.server.luau').read_text()
    print('PASS NPC Creator native package hierarchy, unique references and exact source/template equality')


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--luau', default='luau')
    parser.add_argument('--compiler', default='luau-compile')
    args = parser.parse_args()
    check_npc(args.luau, args.compiler)
