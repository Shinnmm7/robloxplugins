local function harness()
 local widget=Fixture.New("Frame") widget.Enabled=true
 local stored,encoded,sequence={}, {},0 local queue={}
 local plugin={SetSetting=function(_,k,v) stored[k]=v end,GetSetting=function(_,k) return stored[k] end}
 local http={JSONEncode=function(_,v) sequence+=1 local k="json"..sequence encoded[k]=Model.Clone(v) return k end,JSONDecode=function(_,v) return Model.Clone(assert(encoded[v])) end}
 local input={InputChanged=Fixture.Signal(),InputEnded=Fixture.Signal()}
 local world=Fixture.New("Workspace") local selection={items={},Get=function(self) return self.items end}
 local history={OnUndo=Fixture.Signal(),OnRedo=Fixture.Signal()}
 local spawned={} local applies,replacements,builds=0,0,0 local failBuild=false
 local manager={List=function() local out={} for _,n in ipairs(spawned) do if n.Parent then table.insert(out,n) end end return out end,
  Spawn=function(_,c,s) local n=Fixture.Rig() n.Name=c.name n.Parent=world n.config=Model.Clone(c) n.spawnMode=s.spawnMode table.insert(spawned,n) return n end,
  Read=function(n) return Model.Clone(n.config) end,
  Apply=function(n,c) applies+=1 n.config=Model.Clone(c) n.Name=c.name return Model.Clone(c) end,
  Replace=function(n,_,c) replacements+=1 n.config=Model.Clone(c) return n end,
  Duplicate=function(n) local d=n:Clone() d.Name=n.Name.." Copy" d.config=Model.Clone(n.config) d.Parent=world table.insert(spawned,d) return d end,
  Delete=function(n) n:Destroy() end,Select=function(n) selection.items={n} end}
 local previewObject
 local previewModule={New=function()
  previewObject={yaw=0,zoom=1,Set=function(self,n) if self.model then self.model:Destroy() end self.model=n end,Clear=function(self) if self.model then self.model:Destroy() self.model=nil end end,
   Rotate=function(self,d) self.yaw+=d end,Zoom=function(self,d) self.zoom+=d end,Render=function() end,Destroy=function(self) self:Clear() end}
  return previewObject
 end}
 local rig={Build=function(c,resolve,current)
  builds+=1 if failBuild then error("Avatar service unavailable") end assert(current(),"Cancelled")
  if c.mode=="Avatar" then if resolve or not c.appearance then c.userId=12345 c.appearance=Model.New().appearance end end
  return Fixture.Rig(),c
 end}
 local services={HttpService=http,Selection=selection,UserInputService=input,RunService={PreRender=Fixture.Signal()},ChangeHistoryService=history}
 local chunk=assert(loadstring(EDITOR_SOURCE))
 local modules={Model=Model,Rig=rig,Preview=previewModule,Manager=manager}
 setfenv(chunk,setmetatable({game={GetService=function(_,n) return assert(services[n],n) end},script={Parent={Model="Model",Rig="Rig",Preview="Preview",Manager="Manager"}},require=function(n) return modules[n] end,
  Instance={new=Fixture.New},Enum=Fixture.Enum,UDim=Fixture.Types,UDim2=Fixture.Types,Color3=Fixture.Types,workspace=world,
  task={spawn=function(fn) table.insert(queue,fn) end,delay=function(_,fn) table.insert(queue,fn) end}},{__index=getfenv()}))
 local cleanup=chunk().Mount(plugin,widget)
 local function find(kind,text)
  for _,o in ipairs(widget:GetDescendants()) do if o.ClassName==kind and (o.Text==text or o.Name==text) then return o end end error("Missing "..kind.." "..text)
 end
 return {click=function(text) find("TextButton",text).Activated:Fire() end,edit=function(name,value) local o=find("TextBox",name) o.Text=value o.FocusLost:Fire() end,
 flush=function() local callbacks=queue queue={} for _,fn in ipairs(callbacks) do fn() end end,
 spawned=spawned,stored=stored,preview=function() return previewObject end,counts=function() return applies,replacements,builds end,
 selectPoint=function(x,y,z) local p=Fixture.New("Part") p.Position=Fixture.Vector(x,y,z) p.Parent=world selection.items={p} end,
 status=function() for _,o in ipairs(widget:GetDescendants()) do if o.ClassName=="TextLabel" and type(o.Text)=="string" and o.Text:find("unavailable") then return o.Text end end end,
 fail=function(value) failBuild=value end,cleanup=cleanup}
end
local h=harness()
h.edit("NPC model name","Village Guide") h.edit("Maximum health","250") h.click("Build preview") h.flush() h.click("Spawn NPC")
assert(#h.spawned==1 and h.spawned[1].Name=="Village Guide" and h.spawned[1].config.health==250)
h.edit("NPC model name","Renamed Guide") h.click("Spawn NPC") assert(#h.spawned==1,"Stale preview must not spawn")
h.click("Apply properties + behavior to NPC") assert(h.spawned[1].Name=="Renamed Guide")
h.click("Build preview") h.flush() h.click("Replace NPC rig with preview") local applies,replacements=h.counts() assert(applies==1 and replacements==1)
h.edit("Preset name","Guard") h.click("Save new preset") assert(h.stored["NPCCreatorPro.Presets.v1"])
h.click("Panel: Identity") h.edit("Head asset ID","1234") h.edit("HeadColor RGB","255, 100, 0")
h.click("Panel: Appearance") h.click("☐ Generate server AI template") h.click("Movement: Idle") h.click("Movement: Walking")
h.selectPoint(0,1,2) h.click("Add selected location as patrol point") h.selectPoint(10,1,2) h.click("Add selected location as patrol point")
h.click("Build preview") h.flush() h.click("Spawn NPC") assert(h.spawned[2].config.behavior.motion=="Patrol" and #h.spawned[2].config.behavior.patrol==2 and h.spawned[2].config.appearance.properties.Head==1234)
h.click("NPC Manager") h.click("Duplicate selected NPC") assert(#h.spawned==3) h.click("Delete selected NPC") assert(h.spawned[3].destroyed)
h.click("Saved NPCs") h.click("● Guard") h.edit("Preset name","Saved Guard") h.click("Rename saved preset") h.click("Load saved NPC") h.flush()
h.click("Player Avatar NPC") h.edit("Roblox username","Roblox") h.edit("NPC model name","Avatar copy") h.click("Search username & load avatar") h.flush() h.click("Spawn NPC")
assert(h.spawned[4].config.userId==12345 and h.spawned[4].Name=="Avatar copy")
h.fail(true) h.click("Search username & load avatar") h.flush() assert(h.status() and h.status():find("unavailable")) h.fail(false)
h.click("Search username & load avatar") h.click("Custom NPC") h.flush() h.click("Build preview") h.flush() h.click("Spawn NPC")
assert(h.spawned[5].config.mode=="Custom","Late avatar result must not replace custom configuration")
h.click("Settings") h.click("Spawn location: Camera") h.edit("Camera forward distance (0–200 studs)","20") h.edit("Managed Workspace folder","VillageNPCs") h.click("☐ Automatically rotate preview") h.click("Save settings") assert(h.stored["NPCCreatorPro.Settings.v1"])
h.click("Zoom +") h.click("Zoom −") h.click("↶") h.click("↷") h.click("Reset view") h.cleanup()
assert(h.preview().model==nil)
print("PASS NPC editor: custom and avatar creation, loading/failure/cancellation, stale-preview guard, properties/rebuild, appearance, patrol, manager, presets, settings, preview controls and unload")
