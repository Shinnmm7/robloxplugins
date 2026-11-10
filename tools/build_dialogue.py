#!/usr/bin/env python3
"""Package the Luau DialogueCraft plugin; Python is used only for XML packaging."""
from pathlib import Path
import argparse
import xml.etree.ElementTree as ET
from build import ROOT, item

def build_dialogue(destination):
    source = ROOT / 'src/dialogue'
    root = ET.Element('roblox', {'version': '4'})
    plugin = item(root, 'Script', 'DialogueCraftPro', (source / 'Plugin.server.luau').read_text())
    for name in ('Model', 'Example', 'Generator', 'Editor'):
        item(plugin, 'ModuleScript', name, (source / f'{name}.luau').read_text())
    templates = item(plugin, 'Folder', 'Templates')
    for name, filename in {'Model': 'Model.luau', 'Service': 'Service.luau', 'Runtime': 'Runtime.server.luau', 'Client': 'Client.client.luau'}.items():
        item(templates, 'StringValue', name, value=(source / filename).read_text())
    for index, node in enumerate(root.iter('Item')):
        node.set('referent', f'RBX{index}')
    destination.parent.mkdir(parents=True, exist_ok=True)
    ET.indent(root)
    ET.ElementTree(root).write(destination, encoding='utf-8', xml_declaration=True)
    print(f'Built {destination} ({destination.stat().st_size:,} bytes)')

if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--output', type=Path, default=ROOT / 'dist/DialogueCraftPro.rbxmx')
    build_dialogue(parser.parse_args().output)
