import json, os, sys, tempfile
from pathlib import Path
from lupa.lua53 import LuaRuntime, lua_type
SOURCE = (Path(__file__).resolve().parents[1]/'BeamMP-Delete-Vehicle/Server/Main.lua').read_text()
temporary = tempfile.TemporaryDirectory(prefix='dv-permissions-')
ROOT = Path(temporary.name)
checks = 0

def check(value, message):
 global checks
 assert value, message
 checks += 1

class Server:
 def __init__(self, path, owner='Owner'):
  self.path = path
  self.users = {0:('Other','900',False), 7:('Owner','100',False), 2:('Alice','200',False), 3:('Bob','300',False), 4:('Player Name','400',False), 5:('Guest','500',True), 6:('NoIdentity',None,False), 8:('Dup','800',False), 9:('DUP','801',False), 11:('set','1100',False)}
  self.messages, self.removed = [], []
  self.fail_rename = False
  self.lua = LuaRuntime(unpack_returned_tuples=True)
  l = self.lua
  def decode(raw):
   v = json.loads(raw)
   return l.table_from(v, recursive=True) if isinstance(v,(dict,list)) else v
  def native(v):
   if lua_type(v) == 'table': return {str(k):native(x) for k,x in v.items()}
   return v
  def rename(a,b):
   if self.fail_rename: return False, 'simulated rename failure'
   try: os.replace(a,b); return True, ''
   except OSError as e: return False,str(e)
  def ids(pid):
   user = self.users.get(pid)
   return l.table_from({'beammp': user[1]} if user and user[1] is not None else {})
  def vehicles(pid):
   return l.table_from({0:json.dumps({'jbm':'pickup','vcf':{'partConfigFilename':'vehicles/pickup/base.pc'}}),7:'broken'})
  l.globals().MP = l.table_from({
   'RegisterEvent':lambda *args: None,
   'GetPlayerName':lambda pid: self.users[pid][0] if pid in self.users else None,
   'IsPlayerGuest':lambda pid: self.users.get(pid,('',None,True))[2],
   'GetPlayerIdentifiers':ids,
   'GetPlayers':lambda: l.table_from({pid:v[0] for pid,v in self.users.items()}),
   'GetPlayerVehicles':vehicles,
   'SendChatMessage':lambda pid,msg: self.messages.append((pid,msg)),
   'RemoveVehicle':lambda pid,vid: self.removed.append((pid,vid))})
  l.globals().FS = l.table_from({'Exists':lambda p: Path(p).exists(),'Rename':rename})
  l.globals().Util = l.table_from({'JsonEncode':lambda v: json.dumps(native(v)), 'JsonDecode':decode})
  l.globals().print = lambda *args: None
  source = SOURCE.replace('local ALLOWED_USERNAME = ""','local ALLOWED_USERNAME = '+json.dumps(owner),1)
  source = source.replace('"BeamMP-Delete-Vehicle-permissions.json"',json.dumps(str(path).replace('\\','/')),1)
  l.execute(source)
 def chat(self,pid,text):
  self.messages,self.removed=[],[]
  result=self.lua.globals().OnChatHandler(pid,'Owner',text) # supplied name must not authorize
  check(all(p == pid for p,_ in self.messages),'responses must be private')
  return result
 def text(self): return '\n'.join(m for _,m in self.messages)

p=ROOT/'admins.json'
s=Server(p)
s.chat(0,'/dv set add 2'); check(not p.exists(),'ID 0 cannot grant')
s.chat(2,'/dv 0 0'); check(not s.removed,'non-admin denied')
s.chat(7,'/dv set add 2 3 "Player Name"')
check('3 player(s)' in s.text(),'batch grants')
check(json.loads(p.read_text())['admins']=={'200':'Alice','300':'Bob','400':'Player Name'},'saved permanent IDs')
s.chat(2,'/dv 0 0'); check(s.removed==[(0,0)],'added admin deletion')
s.chat(2,'/dv list 0'); check('pickup (config: base)' in s.text() and not s.removed,'added admin listing')
before=p.read_bytes()
for cmd in ['/dv set add 0','/dv set remove 3','/dv set reset','/dv set list']:
 s.chat(2,cmd); check(p.read_bytes()==before and 'Only the configured owner' in s.text(),'admin cannot manage permissions')
s.chat(7,'/dv set list'); check('account:200' in s.text() and 'Owner: Owner' in s.text(),'list includes offline removal syntax')
# Fresh Lua state, new session and username; account identity retains access.
s=Server(p)
del s.users[2]
s.users[12]=('AliceRenamed','200',False)
s.users[2]=('Imposter','999',False)
s.chat(12,'/dv 0 0'); check(s.removed==[(0,0)],'access survives reload and ID/name change')
s.chat(2,'/dv 0 0'); check(not s.removed,'reused session ID does not gain access')
s.chat(7,'/dv set remove account:200')
s.chat(12,'/dv 0 0'); check(not s.removed,'offline-account removal revokes immediately')
s=Server(p)
s.chat(2,'/dv 0 0'); check(not s.removed,'revocation survives restart')
# Reject entire malformed batch without changing disk.
for cmd in ['/dv set add 2 Missing','/dv set add 2 5','/dv set add 2 6','/dv set add Dup','/dv set add "Player Name','/dv set add "Alice"3','/dv set add account:200','/dv set add 7','/dv set remove 7','/dv set reset extra','/dv set list extra','/dv set add','/dv set']:
 before=p.read_bytes(); s.chat(7,cmd)
 check(p.read_bytes()==before and not s.removed,'invalid batch must not mutate: '+cmd)
s.chat(7,'/dv set add 2 2'); check('1 player(s)' in s.text(),'duplicates counted once')
s.chat(7,'/dv set add 2'); check('0 player(s)' in s.text(),'repeat add harmless')
s.chat(7,'/dv set remove 2 3'); check('2 player(s)' in s.text(),'batch remove')
# Guests cannot impersonate the owner or use saved account permissions.
s.users[15]=('Owner','100',True)
s.chat(15,'/dv set add 0'); check('privileges' in s.text(),'guest owner impersonation denied')
s.users[16]=('Player Name','400',True)
s.chat(16,'/dv 0 0'); check(not s.removed,'guest saved identity denied')
# File commit failure keeps both current permissions and saved file unchanged.
before=p.read_bytes(); s.fail_rename=True
s.chat(7,'/dv set add 2'); check('not changed' in s.text() and p.read_bytes()==before,'failed save reported')
s.chat(2,'/dv 0 0'); check(not s.removed,'failed grant is not applied')
s.chat(7,'/dv set remove 4'); check('not changed' in s.text(),'failed revoke reported')
s.chat(4,'/dv 0 0'); check(s.removed==[(0,0)],'failed revoke retains existing access')
s.fail_rename=False
s.chat(7,'/dv set reset'); check(json.loads(p.read_text())=={'version':1},'reset clears all saved admins')
s.chat(4,'/dv 0 0'); check(not s.removed,'reset revokes added admin')
s.chat(7,'/dv 0 0'); check(s.removed==[(0,0)],'reset preserves owner')
s=Server(p); s.chat(7,'/dv set list'); check('No added admins' in s.text(),'empty saved list reloads')
# Corruption fails closed, does not silently overwrite file; explicit reset repairs it.
for contents in ['{bad', '{"version":1,"admins":{"200":true}}', '{"version":99}', '{"version":1,"admins":false}']:
 p.write_text(contents); s=Server(p)
 s.chat(2,'/dv 0 0'); check(not s.removed,'corrupt store denies admins')
 s.chat(7,'/dv set add 2'); check(p.read_text()==contents,'corrupt store preserved')
 s.chat(7,'/dv set reset'); check(json.loads(p.read_text())=={'version':1},'explicit reset recovers corrupt store')
# Public default remains disabled even with saved grants.
s=Server(p); s.chat(7,'/dv set add 2')
s=Server(p,owner=''); s.chat(2,'/dv 0 0'); check(not s.removed,'blank owner disables saved grants')
s.chat(7,'/dv set reset'); check('privileges' in s.text(),'blank owner disables management')
s.chat(0,'/dvhelp'); check('/dv set' in s.text(),'public help documents permissions')
check(s.chat(0,'/help')==0,'generic help passes through')
# Existing deletion parser and quoted reserved usernames.
s=Server(p)
for command in ['/dv 0 bad','/dv 0 -1','/dv 0 1.5','/dv 0 0 extra','/dv list 0 0']:
 s.chat(7,command); check(not s.removed,'malformed deletion safe')
s.chat(7,'/dv "set" 0'); check(s.removed==[(11,0)],'quoted reserved username can be targeted')
s.chat(7,'/dv 0'); check(sorted(s.removed)==[(0,0),(0,7)],'bulk deletion preserved')
print(f'Passed {checks} assertions using Lua 5.3, JSON serialization, actual temporary files, and mocked BeamMP APIs.')
print('Test data: '+str(ROOT))
