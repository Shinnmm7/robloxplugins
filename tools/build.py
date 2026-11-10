#!/usr/bin/env python3
"""Build an installable Roblox XML plugin using only Python's standard library."""
import argparse
from pathlib import Path
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]

def item(parent, class_name, name, source=None, value=None):
    node = ET.SubElement(parent, 'Item', {'class': class_name})
    properties = ET.SubElement(node, 'Properties')
    ET.SubElement(properties, 'string', {'name': 'Name'}).text = name
    if source is not None:
        ET.SubElement(properties, 'ProtectedString', {'name': 'Source'}).text = source
    if value is not None:
        ET.SubElement(properties, 'string', {'name': 'Value'}).text = value
    return node


def build(destination):
    root = ET.Element('roblox', {'version': '4'})
    plugin = item(root, 'Script', 'QuestForgePro', (ROOT / 'src/plugin/Bootstrap.server.luau').read_text())
    for name, relative in {
        'Editor': 'plugin/Editor.luau', 'Generator': 'plugin/Generator.luau',
        'Schema': 'shared/Schema.luau', 'Example': 'shared/Example.luau',
    }.items():
        item(plugin, 'ModuleScript', name, (ROOT / 'src' / relative).read_text())
    templates = item(plugin, 'Folder', 'Templates')
    for name, relative in {
        'Engine': 'runtime/Engine.luau', 'Schema': 'shared/Schema.luau',
        'QuestService': 'runtime/QuestService.luau', 'Bootstrap': 'runtime/Bootstrap.server.luau',
        'Client': 'runtime/Client.client.luau',
    }.items():
        item(templates, 'StringValue', name, value=(ROOT / 'src' / relative).read_text())
    for index, node in enumerate(root.iter('Item')):
        node.set('referent', f'RBX{index}')
    destination.parent.mkdir(parents=True, exist_ok=True)
    ET.indent(root)
    ET.ElementTree(root).write(destination, encoding='utf-8', xml_declaration=True)
    print(f'Built {destination} ({destination.stat().st_size:,} bytes)')

if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--output', type=Path, default=ROOT / 'dist/QuestForgePro.rbxmx')
    build(parser.parse_args().output)
