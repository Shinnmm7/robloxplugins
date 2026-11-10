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
subprocess.run([args.luau, 'tests/dialogue.spec.luau'], cwd=ROOT, check=True)
subprocess.run([args.luau, 'tests/cine.spec.luau'], cwd=ROOT, check=True)
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

from build_dialogue import build_dialogue
with tempfile.TemporaryDirectory() as temporary:
    output = Path(temporary) / 'DialogueCraftPro.rbxmx'
    build_dialogue(output)
    xml = ET.parse(output).getroot()
    refs = [n.attrib['referent'] for n in xml.iter('Item')]
    assert len(refs) == len(set(refs))
    for prop in xml.iter('ProtectedString'):
        assert prop.text in [p.read_text() for p in (ROOT / 'src/dialogue').glob('*.luau')]
    plugin = xml.find('Item')
    names = {n.find('Properties/string').text for n in plugin.findall('Item')}
    assert names == {'Model', 'Example', 'Generator', 'Editor', 'Templates'}
    templates = next(n for n in plugin.findall('Item') if n.attrib['class'] == 'Folder')
    mapping = {'Model': 'Model.luau', 'Service': 'Service.luau', 'Runtime': 'Runtime.server.luau', 'Client': 'Client.client.luau'}
    for node in templates.findall('Item'):
        name = node.find('Properties/string').text
        assert node.find('Properties/string[@name="Value"]').text == (ROOT / 'src/dialogue' / mapping[name]).read_text()
print('PASS DialogueCraft packaging hierarchy, references, and runtime template equality')

with tempfile.TemporaryDirectory() as temporary:
    test = Path(temporary) / 'dialogue-service.luau'
    test.write_text('local Model=(function()\n'+(ROOT/'src/dialogue/Model.luau').read_text()+'\nend)()\n'
        +'local Example=(function()\n'+(ROOT/'src/dialogue/Example.luau').read_text()+'\nend)()\n'
        +'local SOURCE=[====[\n'+(ROOT/'src/dialogue/Service.luau').read_text()+'\n]====]\n'
        +(ROOT/'tests/dialogue-service.spec.luau').read_text())
    subprocess.run([args.luau, str(test)], check=True)

from build_cine import build_cine
with tempfile.TemporaryDirectory() as temporary:
    output = Path(temporary) / 'CineForgePro.rbxmx'
    build_cine(output)
    root = ET.parse(output).getroot()
    refs = [n.attrib['referent'] for n in root.iter('Item')]
    assert len(refs) == len(set(refs))
    plugin = root.find('Item')
    assert plugin.find('Properties/ProtectedString').text == (ROOT / 'src/cine/Plugin.server.luau').read_text()
    children = {n.find('Properties/string').text: n for n in plugin.findall('Item')}
    assert set(children) == {'Model', 'Player', 'Example', 'Generator', 'Editor', 'Templates'}
    for name in ('Model', 'Player', 'Example', 'Generator', 'Editor'):
        assert children[name].find('Properties/ProtectedString').text == (ROOT / 'src/cine' / (name + '.luau')).read_text()
    mapping = {'Model':'Model.luau', 'Player':'Player.luau', 'Client':'Client.client.luau'}
    templates = {n.find('Properties/string').text:n for n in children['Templates'].findall('Item')}
    assert set(templates) == set(mapping)
    for name, filename in mapping.items():
        assert templates[name].find('Properties/string[@name="Value"]').text == (ROOT / 'src/cine' / filename).read_text()
    test = Path(temporary) / 'cine-player.luau'
    test.write_text('local Model=(function()\n'+(ROOT/'src/cine/Model.luau').read_text()+'\nend)()\n'
        +'local Example=(function()\n'+(ROOT/'src/cine/Example.luau').read_text()+'\nend)()\n'
        +'local PLAYER_SOURCE=[====[\n'+(ROOT/'src/cine/Player.luau').read_text()+'\n]====]\n'
        +(ROOT/'tests/cine-player.spec.luau').read_text())
    subprocess.run([args.luau, str(test)], check=True)
print('PASS CineForge package hierarchy, source, and runtime templates')

with tempfile.TemporaryDirectory() as temporary:
    test = Path(temporary) / 'cine-editor.luau'
    test.write_text('local Model=(function()\n'+(ROOT/'src/cine/Model.luau').read_text()+'\nend)()\n'
        +'local Example=(function()\n'+(ROOT/'src/cine/Example.luau').read_text()+'\nend)()\n'
        +'local EDITOR_SOURCE=[====[\n'+(ROOT/'src/cine/Editor.luau').read_text()+'\n]====]\n'
        +(ROOT/'tests/cine-editor.spec.luau').read_text())
    subprocess.run([args.luau, str(test)], check=True)

with tempfile.TemporaryDirectory() as temporary:
    test = Path(temporary) / 'cine-generator.luau'
    test.write_text('local Model=(function()\n'+(ROOT/'src/cine/Model.luau').read_text()+'\nend)()\n'
        +'local Example=(function()\n'+(ROOT/'src/cine/Example.luau').read_text()+'\nend)()\n'
        +'local SOURCE=[====[\n'+(ROOT/'src/cine/Generator.luau').read_text()+'\n]====]\n'
        +(ROOT/'tests/cine-generator.spec.luau').read_text())
    subprocess.run([args.luau, str(test)], check=True)

with tempfile.TemporaryDirectory() as temporary:
    test = Path(temporary) / 'cine-client.luau'
    test.write_text('local Example=(function()\n'+(ROOT/'src/cine/Example.luau').read_text()+'\nend)()\n'
        +'local CLIENT_SOURCE=[====[\n'+(ROOT/'src/cine/Client.client.luau').read_text()+'\n]====]\n'
        +(ROOT/'tests/cine-client.spec.luau').read_text())
    subprocess.run([args.luau, str(test)], check=True)
