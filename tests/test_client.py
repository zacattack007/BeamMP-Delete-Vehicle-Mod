import json
from pathlib import Path
from zipfile import ZipFile
from lupa.luajit21 import LuaRuntime, lua_type
repo=Path(__file__).resolve().parents[1]
l=LuaRuntime(unpack_returned_tuples=True)
checks=0
def check(v,msg):
 global checks
 assert v,msg
 checks+=1
l.execute('''
handlers={}; notices={}; draws={}; entries={}; objects={}; registrations=0
local vector={}
vector.__index=vector
function vector.__add(a,b) return vec3(a.x+b.x,a.y+b.y,a.z+b.z) end
function vector.__sub(a,b) return vec3(a.x-b.x,a.y-b.y,a.z-b.z) end
function vector:length() return math.sqrt(self.x*self.x+self.y*self.y+self.z*self.z) end
function vec3(x,y,z) return setmetatable({x=x,y=y,z=z},vector) end
function ColorF(...) return {...} end
function ColorI(...) return {...} end
function String(s) return s end
function getCameraPosition() return vec3(0,0,0) end
function ui_message(s) table.insert(notices,s) end
function AddEventHandler(name,fn,source) handlers[name]=fn; registrations=registrations+1 end
function RemoveEventHandler(name,source) handlers[name]=nil end
be={getObjectByID=function(self,id) return objects[id] end}
extensions={MPVehicleGE={getVehicleByServerID=function(id) return entries[id] end}}
debugDrawer={
 drawCylinder=function(self,a,b,r,c) table.insert(draws,{'cylinder',a,b}) end,
 drawSphere=function(self,p,r,c) table.insert(draws,{'sphere',p}) end,
 drawTextAdvanced=function(self,p,text,fg,bg,other,color,shadow,useZ) table.insert(draws,{'text',p,text,useZ}) end
}
function spawn()
 entries['2-0']={gameVehicleID=10}
 objects[10]={position=vec3(10,0,0),getPosition=function(self) return self.position end}
end
''')

def decode(raw):
 v=json.loads(raw)
 return l.table_from(v,recursive=True) if isinstance(v,(dict,list)) else v
def native(v):
 if lua_type(v)=='table': return {str(k):native(x) for k,x in v.items()}
 return v
l.globals().jsonDecode=decode
l.globals().jsonEncode=lambda v:json.dumps(native(v))
client=repo/'BeamMP-Delete-Vehicle/ClientSource/lua/ge/extensions/dvLocator.lua'
m=l.execute(client.read_text());m.onExtensionLoaded()
check(l.globals().registrations==4,'four event handlers')
payload=json.dumps({'serverVehicleID':'2-0','label':'Alice | Vehicle ID 0 | pickup'})
def show():l.globals().handlers.DVLocatorShow(payload)
def reset():l.execute('draws={}')
l.globals().spawn();show();m.onUpdate(.1)
check(len(l.globals().draws)==3,'marker drawn')
check('10 m from camera' in l.globals().draws[3][3],'distance shown')
l.execute('objects[10].position=vec3(30,0,0)');reset();m.onUpdate(.1)
check(l.globals().draws[1][2].x==30,'marker follows vehicle')
l.globals().handlers.DVLocatorClear('');reset();m.onUpdate(.1)
check(len(l.globals().draws)==0,'clear marker')
show();reset();m.onUpdate(60);check(len(l.globals().draws)==0,'expiry')
show();m.onUpdate(.1);l.execute("entries['2-0']=nil");reset();m.onUpdate(.1)
check(len(l.globals().draws)==0,'removed vehicle clears')
l.globals().spawn();show();m.onUpdate(.1);l.globals().spawn();reset();m.onUpdate(.1)
check(len(l.globals().draws)==0,'ID reuse does not retarget')
l.execute('objects={};entries={}');show();m.onUpdate(5)
check('not spawned' in l.globals().notices[len(l.globals().notices)],'unspawned vehicle feedback')
l.globals().spawn();show();m.onClientEndMission();reset();m.onUpdate(.1)
check(len(l.globals().draws)==0,'map exit clears')
l.execute("""
hooks={};serverEvents={}
guihooks={trigger=function(event,data) table.insert(hooks,{event,data}) end}
MPCoreNetwork={isMPSession=function() return false end}
function TriggerServerEvent(event,data) table.insert(serverEvents,{event,data}) end
""")
m.uiAction('refresh')
check(len(l.globals().serverEvents)==0 and l.globals().hooks[1][2].connected==False,'offline action stays local')
l.execute('MPCoreNetwork.isMPSession=function() return true end')
m.uiAction('refresh',0)
check(json.loads(l.globals().serverEvents[1][2])=={'action':'refresh','value':0},'player ID zero supported')
m.uiAction('delete','t123')
check(json.loads(l.globals().serverEvents[2][2])=={'action':'delete','value':'t123'},'deletion token serialized')
m.uiAction('grant','t124');m.uiAction('remove','200');m.uiAction('clear')
check(len(l.globals().serverEvents)==5,'permission and locator actions sent')
for action,value in [('delete',0),('delete','t1bad'),('remove','200 bad'),('refresh',-1),('refresh',0.5),('bad','t1')]:
 m.uiAction(action,value)
check(len(l.globals().serverEvents)==5,'invalid UI payloads blocked')
l.globals().handlers.DVUIState('{"connected":true,"allowed":false}')
check(l.globals().hooks[len(l.globals().hooks)][1]=='DVAppState','state forwarded')
l.globals().handlers.DVUINotice('{"text":"Done"}')
check(l.globals().hooks[len(l.globals().hooks)][2].text=='Done','feedback forwarded')
m.onExtensionUnloaded()
check(l.globals().handlers.DVUIState is None and l.globals().handlers.DVLocatorShow is None,'unload unregisters all')
check(json.loads(l.globals().serverEvents[len(l.globals().serverEvents)][2])['action']=='unsubscribe','unsubscribe on unload')
l.execute('savedAdd=AddEventHandler;AddEventHandler=nil');m.onExtensionLoaded()
l.execute('AddEventHandler=savedAdd');m.onUpdate(.1)
check(l.globals().handlers.DVUIState is not None,'delayed registration')
source=repo/'BeamMP-Delete-Vehicle/ClientSource'
with ZipFile(repo/'BeamMP-Delete-Vehicle/Client/BeamMP-Delete-Vehicle-Locator.zip') as z:
 expected={p.relative_to(source).as_posix() for p in source.rglob('*') if p.is_file()}
 check(set(z.namelist())==expected,'all Lua and app assets packaged')
 check(all(z.read(name)==(source/name).read_bytes() for name in expected),'archive matches every source asset')
print(f'Passed {checks} client and packaging checks in LuaJIT.')
