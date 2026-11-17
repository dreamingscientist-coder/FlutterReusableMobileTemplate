import importlib.util,tempfile,json
from pathlib import Path
p=str(Path(__file__).resolve().parents[1] / 'setup/setup_project.py')
s=importlib.util.spec_from_file_location('setup_project',p);m=importlib.util.module_from_spec(s);s.loader.exec_module(m)
with tempfile.TemporaryDirectory(prefix='template-update-setup-',dir='/tmp') as d:
 m.ROOT=d
 Path(d,'pubspec.yaml').write_text('name: sample\nversion: 2.3.0+1\n')
 answers={'bundle_id':'com.example.newapp','slug':'newapp'}
 m.write_update_policy(answers)
 file=Path(d,'legal/newapp/app-update.json');v=json.loads(file.read_text())
 assert v['appId']=='com.example.newapp'
 assert v['ios']['enabled'] is False and v['ios']['storeAvailable'] is False
 assert v['ios']['latestVersion']=='2.3.0' and v['ios']['storeUrl']==''
 assert v['android']['storeUrl'].endswith('com.example.newapp')
 file.write_text('preserve-existing-policy')
 m.write_update_policy(answers)
 assert file.read_text()=='preserve-existing-policy'
 print('Setup generates per-app disabled policy and preserves existing policies: passed')
