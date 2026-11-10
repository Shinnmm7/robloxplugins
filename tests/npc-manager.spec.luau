local world=Fixture.New("Workspace") local camera=Fixture.New("Camera") camera.CFrame=Fixture.CFrame(0,10,0) world.CurrentCamera=camera
local history={records={},OnUndo=Fixture.Signal(),OnRedo=Fixture.Signal()}
function history:TryBeginRecording(_,label) table.insert(self.records,{label=label}) return #self.records end
function history:FinishRecording(id,result) self.records[id].result=result end
local data={} local count=0 local http={}
function http:GenerateGUID() count+=1 return "guid"..count end
function http:JSONEncode(c) count+=1 local key="json"..count data[key]=Model.Clone(c) return key end
function http:JSONDecode(key) return Model.Clone(assert(data[key])) end
local selection={value={},Get=function(self) return self.value end,Set=function(self,list) self.value=list end}
local running=false
local services={ChangeHistoryService=history,HttpService=http,Selection=selection,RunService={IsRunning=function() return running end}}
local env={game={GetService=function(_,key) return assert(services[key],key) end},workspace=world,script={Parent={Model="Model",Templates={Behavior={Value="server ai"}}}},require=function() return Model end,
 Instance={new=Fixture.New},Enum=Fixture.Enum,Vector3={new=Fixture.Vector},CFrame={new=Fixture.CFrame}}
local chunk=assert(loadstring(MANAGER_SOURCE)) setfenv(chunk,setmetatable(env,{__index=getfenv()})) local m=chunk()
local preview=Fixture.Rig() preview.HumanoidRootPart.Anchored=true
local c=Model.New() c.name="Guide" c.behavior.enabled=true
local settings={spawnMode="Camera",distance=12,folder="NPCs"}
local npc=m.Spawn(preview,c,settings)
assert(npc.Parent==world.NPCs and npc.Name=="Guide" and npc:GetAttribute("NPCCreatorId"))
assert(not npc.HumanoidRootPart.Anchored and npc:GetPivot().Position.Z==-12 and preview.Parent==nil)
assert(npc.NPCCreatorBehavior.Source=="server ai" and npc.NPCCreatorConfig and selection.value[1]==npc)
assert(#m.List()==1 and history.records[1].result==Fixture.Enum.FinishRecordingOperation.Commit)
local originalId=npc:GetAttribute("NPCCreatorId")
local properties=Model.Clone(c) properties.name="New name" properties.health=250 properties.rig="R6" properties.appearance.properties.Head=999 properties.behavior.motion="Stationary"
local actual=m.Apply(npc,properties)
assert(npc.Name=="New name" and npc.Humanoid.MaxHealth==250 and npc.HumanoidRootPart.Anchored)
assert(actual.rig=="R15" and actual.appearance.properties.Head==0,"Properties must not claim an unapplied appearance")
local manual=Fixture.New("Folder") manual.Name="User edits" manual.Parent=npc
local duplicate=m.Duplicate(npc) assert(duplicate:GetAttribute("NPCCreatorId")~=originalId and duplicate:FindFirstChild("User edits") and #m.List()==2)
local replacement=m.Replace(npc,preview,properties) assert(npc.destroyed and replacement:GetAttribute("NPCCreatorId")==originalId and replacement:GetPivot().Position.Z==-12)
assert(m.Read(replacement).rig=="R6" and replacement:GetAttribute("NPCDescription")==c.description)
m.Delete(duplicate) assert(#m.List()==1)
local point=Fixture.New("Part") point.Position=Fixture.Vector(10,5,10) point.CFrame=Fixture.CFrame(point.Position) point.Size=Fixture.Vector(4,2,4) point.Parent=world selection.value={point}
settings.spawnMode="Selection" local located=m.Spawn(preview,c,settings) local box,size=located:GetBoundingBox() assert(math.abs((box.Position.Y-size.Y/2)-6.05)<.001)
selection.value={} assert(not pcall(m.Spawn,preview,c,settings))
local occupied=Fixture.New("Folder") occupied.Name="Unowned" occupied.Parent=world settings.folder="Unowned" settings.spawnMode="Camera"
local cloneForFailure
local trackedPreview={Clone=function() cloneForFailure=preview:Clone() return cloneForFailure end}
assert(not pcall(m.Spawn,trackedPreview,c,settings)) assert(cloneForFailure.destroyed,"Failed edits must dispose detached clones")
assert(history.records[#history.records].result==Fixture.Enum.FinishRecordingOperation.Cancel)
running=true assert(not pcall(m.Delete,replacement)) running=false
local unowned=Fixture.Rig() unowned.Parent=world assert(not pcall(m.Delete,unowned))
local bad=Model.Clone(c) bad.health=-1 assert(not pcall(m.Apply,replacement,bad))
local mine=Fixture.New("Script") mine.Name="NPCCreatorBehavior" mine.Parent=unowned unowned:SetAttribute("NPCCreatorPro",true)
assert(not pcall(m.Apply,unowned,c))
print("PASS NPC manager: camera/selection placement, identity, ownership, server script, properties versus appearance, stationary anchoring, duplicate, replacement, deletion, invalid input, play-mode guard and history commit/cancel")
