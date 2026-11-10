#!/usr/bin/env python3
"""Compile every Luau source, run state-machine tests, verify the XML payload."""
import argparse
from pathlib import Path
import subprocess
import tempfile
import xml.etree.ElementTree as ET
from build import ROOT, build

parser = argparse.ArgumentParser()
parser.add_argument('--luau', default='luau')
parser.add_argument('--compiler', default='luau-compile')
args = parser.parse_args()
for path in sorted([*ROOT.glob('src/**/*.luau'), *ROOT.glob('tests/**/*.luau')]):
    subprocess.run([args.compiler, str(path)], check=True, stdout=subprocess.DEVNULL)
print('PASS: all Luau sources compile')
subprocess.run([args.luau, 'tests/engine.spec.luau'], cwd=ROOT, check=True)
with tempfile.TemporaryDirectory() as temporary:
    harness_path = Path(temporary) / 'service.spec.luau'
    harness_path.write_text(
        'local Schema = (function()\n' + (ROOT / 'src/shared/Schema.luau').read_text() + '\nend)()\n'
        + 'local Engine = (function()\n' + (ROOT / 'src/runtime/Engine.luau').read_text() + '\nend)()\n'
        + 'local Example = (function()\n' + (ROOT / 'src/shared/Example.luau').read_text() + '\nend)()\n'
        + 'local SERVICE_SOURCE = [====[\n' + (ROOT / 'src/runtime/QuestService.luau').read_text() + '\n]====]\n'
        + (ROOT / 'tests/service.spec.luau').read_text()
    )
    subprocess.run([args.luau, str(harness_path)], cwd=ROOT, check=True)
    generator_path = Path(temporary) / 'generator.spec.luau'
    generator_path.write_text(
        'local Schema = (function()\n' + (ROOT / 'src/shared/Schema.luau').read_text() + '\nend)()\n'
        + 'local Example = (function()\n' + (ROOT / 'src/shared/Example.luau').read_text() + '\nend)()\n'
        + 'local GENERATOR_SOURCE = [====[\n' + (ROOT / 'src/plugin/Generator.luau').read_text() + '\n]====]\n'
        + (ROOT / 'tests/generator.spec.luau').read_text()
    )
    subprocess.run([args.luau, str(generator_path)], cwd=ROOT, check=True)
    editor_path = Path(temporary) / 'editor.spec.luau'
    editor_path.write_text(
        'local Schema = (function()\n' + (ROOT / 'src/shared/Schema.luau').read_text() + '\nend)()\n'
        + 'local Example = (function()\n' + (ROOT / 'src/shared/Example.luau').read_text() + '\nend)()\n'
        + 'local EDITOR_SOURCE = [====[\n' + (ROOT / 'src/plugin/Editor.luau').read_text() + '\n]====]\n'
        + (ROOT / 'tests/editor.spec.luau').read_text()
    )
    subprocess.run([args.luau, str(editor_path)], cwd=ROOT, check=True)
    plugin_path = Path(temporary) / 'QuestForgePro.rbxmx'
    build(plugin_path)
    root = ET.parse(plugin_path).getroot()
    referents = [node.attrib['referent'] for node in root.iter('Item')]
    assert len(referents) == len(set(referents)), 'Duplicate Roblox instance referents'
    plugin = root.find('Item')
    assert plugin.attrib['class'] == 'Script'
    assert plugin.find('Properties/ProtectedString').text == (ROOT / 'src/plugin/Bootstrap.server.luau').read_text()
    children = {node.find('Properties/string').text: node for node in plugin.findall('Item')}
    assert set(children) == {'Editor', 'Generator', 'Schema', 'Example', 'Templates'}
    for name, relative in {'Editor': 'plugin/Editor.luau', 'Generator': 'plugin/Generator.luau', 'Schema': 'shared/Schema.luau', 'Example': 'shared/Example.luau'}.items():
        assert children[name].find('Properties/ProtectedString').text == (ROOT / 'src' / relative).read_text()
    templates = {node.find('Properties/string').text: node for node in children['Templates'].findall('Item')}
    assert set(templates) == {'Engine', 'Schema', 'QuestService', 'Bootstrap', 'Client'}
    for name, relative in {'Engine': 'runtime/Engine.luau', 'Schema': 'shared/Schema.luau', 'QuestService': 'runtime/QuestService.luau', 'Bootstrap': 'runtime/Bootstrap.server.luau', 'Client': 'runtime/Client.client.luau'}.items():
        assert templates[name].find('Properties/string[@name="Value"]').text == (ROOT / 'src' / relative).read_text()
print('PASS: installable XML module hierarchy and every embedded source match the repository')
