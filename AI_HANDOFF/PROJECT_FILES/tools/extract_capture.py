import pathlib
import xml.etree.ElementTree as ET

source = pathlib.Path(r'C:\Users\Dell\AppData\Local\Madium\Workspace\Fishilizer\CloverRPG_CombatScripts.rbxlx')
out = pathlib.Path(__file__).parent / 'fishilizer'
out.mkdir(exist_ok=True)
root = ET.parse(source).getroot()
count = 0
for item in root.iter('Item'):
    if item.get('class') not in ('Script', 'LocalScript', 'ModuleScript'):
        continue
    props = {p.get('name'): p.text or '' for p in item.find('Properties')}
    text = props.get('Source', '')
    if text:
        count += 1
        name = ''.join(c if c.isalnum() else '_' for c in props.get('Name', 'script'))
        (out / f'{count}_{name}.lua').write_text(text, encoding='utf-8')
print(f'Saved {count} sources')