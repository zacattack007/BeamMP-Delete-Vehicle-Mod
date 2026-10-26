import json
import test_permissions as base
s=base.Server(base.ROOT/'gui.json')
check=base.check
events=[]
now=[1000]
s.lua.globals().os.time=lambda:now[0]
def send(pid,event,data):events.append((pid,event,data));return True
s.lua.globals().MP.TriggerClientEvent=send
vehicles={2:{0:'{"jbm":"pickup"}',7:'{"jbm":"miramar"}'},7:{0:'{"jbm":"etk800"}'}}
s.lua.globals().MP.GetPlayerVehicles=lambda pid:s.lua.table_from(vehicles.get(pid,{}))
def remove(pid,vid):s.removed.append((pid,vid));vehicles[pid].pop(vid,None)
s.lua.globals().MP.RemoveVehicle=remove

def ui(pid,action,value=None):
 now[0]+=1;events.clear();s.messages=[];s.removed=[]
 s.lua.globals().DVUIAction(pid,json.dumps({'action':action,'value':value}))
def state(pid):
 rows=[json.loads(raw) for target,event,raw in events if target==pid and event=='DVUIState']
 return rows[-1] if rows else None
def array(value):return list(value.values()) if isinstance(value,dict) else value or []
def player(view,pid):return next(p for p in array(view['players']) if p['id']==pid)
def token(view,vid):return next(v['token'] for v in array(view['vehicles']) if v['id']==vid)
ui(0,'refresh');check(state(0)['allowed']==False and 'players' not in state(0),'unauthorized GUI cannot inspect players')
ui(7,'refresh',2);view=state(7)
check(view['owner'] and view['selectedId']==2,'owner receives selected player')
check(len(array(view['vehicles']))==2 and 'pickup' in array(view['vehicles'])[0]['description'],'vehicle descriptions')
vtoken=token(view,0);ptoken=player(view,2)['token']
ui(7,'refresh',2);check(token(state(7),0)==vtoken,'unchanged refresh preserves selection token')
ui(7,'grant',vtoken);check(not s.removed,'wrong-kind grant cannot delete a vehicle')
ui(7,'delete',ptoken);check(not s.removed,'player token cannot delete')
ui(0,'delete',vtoken);check(not s.removed,'unauthorized direct event blocked')
ui(7,'locate',vtoken);check(any(pid==7 and event=='DVLocatorShow' and json.loads(raw)['serverVehicleID']=='2-0' for pid,event,raw in events),'private exact-target locate')
ui(7,'delete',0);check(not s.removed,'numeric ID cannot bypass snapshot')
s.lua.globals().DVUIVehicleChanged(2,0)
ui(7,'delete',vtoken);check(not s.removed and 'selection changed' in s.text(),'vehicle generation invalidates old selection')
vtoken=token(state(7),0)
vehicles[2][0]='{"jbm":"bus"}'
ui(7,'delete',vtoken);check(not s.removed,'changed vehicle configuration rejected')
vtoken=token(state(7),0)
s.lua.globals().DVUIDisconnect(2)
ui(7,'delete',vtoken);check(not s.removed,'reused player ID invalidates old token even same name/account')
vtoken=token(state(7),0)
ui(7,'delete',vtoken);check(s.removed==[(2,0)] and 7 in vehicles[2],'only chosen vehicle deleted')
ui(7,'delete',vtoken);check(not s.removed,'replayed deletion rejected')
ui(7,'refresh',2);ptoken=player(state(7),2)['token']
ui(7,'grant',ptoken);check('Granted access' in s.text(),'owner can grant')
ui(2,'refresh',2);check(state(2)['allowed'] and not state(2)['owner'] and 'admins' not in state(2),'admin sees vehicles without owner-only database')
admin_token=token(state(2),7)
ui(2,'delete',token(state(7),7) if state(7) else vtoken);check(not s.removed,'snapshot belongs to requesting admin')
ui(2,'reset');check('Only the owner' in s.text(),'added admin cannot reset')
ui(2,'grant',ptoken);check('Only the owner' in s.text(),'added admin cannot grant')
ui(7,'remove','200');check('Removed access' in s.text(),'owner removes saved account')
ui(2,'delete',admin_token);check(not s.removed and state(2)['allowed']==False,'revoked access rechecked on action')
ui(7,'refresh',2);ui(7,'grant',player(state(7),2)['token'])
ui(7,'reset');check('Removed all added admins' in s.text(),'owner reset')
ui(7,'unsubscribe');events.clear();s.chat(7,'/dvhelp');check(not any(event=='DVUIState' and pid==7 for pid,event,_ in events),'closed GUI unsubscribed')
for action,value in [('delete','t999999999'),('remove','200 bad'),('delete',{}),('accept',None)]:
 ui(7,action,value);check(not s.removed,'malformed action safe')
ui(99,'refresh');check(not events,'disconnected UI sender ignored')
print('GUI and regression assertions passed:',base.checks)
