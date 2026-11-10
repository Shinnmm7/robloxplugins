#!/usr/bin/env python3
"""Package NPC Creator Pro's Luau source as a native Studio plugin."""
from pathlib import Path
import argparse
import xml.etree.ElementTree as ET
from build import ROOT, item


def build_npc(destination):
    source = ROOT / 'src/npc'
    root = ET.Element('roblox', {'version': '4'})
    plugin = item(root, 'Script', 'NPCCreatorPro', (source / 'Plugin.server.luau').read_text())
    for name in ('Model', 'Rig', 'Preview', 'Manager', 'Editor'):
        item(plugin, 'ModuleScript', name, (source / f'{name}.luau').read_text())
    templates = item(plugin, 'Folder', 'Templates')
    item(templates, 'StringValue', 'Behavior', value=(source / 'Behavior.server.luau').read_text())
    for index, node in enumerate(root.iter('Item')):
        node.set('referent', f'RBX{index}')
    destination.parent.mkdir(parents=True, exist_ok=True)
    ET.indent(root)
    ET.ElementTree(root).write(destination, encoding='utf-8', xml_declaration=True)
    print(f'Built {destination} ({destination.stat().st_size:,} bytes)')


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--output', type=Path, default=ROOT / 'dist/NPCCreatorPro.rbxmx')
    build_npc(parser.parse_args().output)
