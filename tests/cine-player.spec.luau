-- Actual player source is injected by tools/check.py.
local function eq(a,b) assert(a==b,tostring(a).." ~= "..tostring(b)) end
local function signal()
 local callbacks={}
 return {Connect=function(_,callback) table.insert(callbacks,callback) return {Disconnect=function() local i=table.find(callbacks,callback) if i then table.remove(callbacks,i) end end} end,
  Fire=function(_,...) for _,callback in ipairs(table.clone(callbacks)) do callback(...) end end}
end
local function harness()
 local vmt={}
 vmt.__sub=function(a,b) local d=a.X-b.X return {Magnitude=math.abs(d)} end
 local function vec(x,y,z) return setmetatable({X=x,Y=y,Z=z},vmt) end
 local cmt={}
 cmt.__mul=function(a,b) return setmetatable({Position=vec(a.Position.X+b.Position.X,a.Position.Y+b.Position.Y,a.Position.Z+b.Position.Z)},cmt) end
 cmt.__index={Lerp=function(a,b,t) return setmetatable({Position=vec(a.Position.X+(b.Position.X-a.Position.X)*t,a.Position.Y+(b.Position.Y-a.Position.Y)*t,a.Position.Z+(b.Position.Z-a.Position.Z)*t)},cmt) end}
 local cf={new=function(x,y,z) return setmetatable({Position=vec(x or 0,y or 0,z or 0)},cmt) end,Angles=function() return setmetatable({Position=vec(0,0,0)},cmt) end}
 cf.lookAt=function(p) return setmetatable({Position=p},cmt) end
 local all={}
 local function new(class)
  local obj={ClassName=class,children={},destroyed=false}
  if class=="BindableEvent" then local s=signal() obj.Event=s obj.Fire=function(_,...) s:Fire(...) end end
  function obj:Destroy() self.destroyed=true if self.Parent and self.Parent.children then local i=table.find(self.Parent.children,self) if i then table.remove(self.Parent.children,i) end end end
  function obj:IsA(name) return self.ClassName==name end
  function obj:FindFirstChild(name) for _,child in ipairs(self.children) do if child.Name==name then return child end end end
  function obj:FindFirstChildOfClass(name) for _,child in ipairs(self.children) do if child.ClassName==name then return child end end end
  function obj:GetPivot() return self.pivot end
  function obj:PivotTo(value) self.pivot=value end
  function obj:GetDescendants() return self.children end
  function obj:Clone() local clone=new(self.ClassName) clone.Name=self.Name clone.pivot=self.pivot return clone end
  setmetatable(obj,{__newindex=function(t,k,v) rawset(t,k,v) if k=="Parent" and v and v.children then table.insert(v.children,t) end end})
  table.insert(all,obj) return obj
 end
 local camera=new("Camera") camera.CameraType="Custom" camera.CameraSubject="subject" camera.CFrame=cf.new(99,1,2) camera.Focus=cf.new(3,4,5) camera.FieldOfView=75 camera.Parent={}
 local world=new("Workspace") world.CurrentCamera=camera
 local lighting=new("Lighting") local gui=new("Frame") local step=signal()
 local env=setmetatable({game={GetService=function(_,name) if name=="RunService" then return {PreRender=step} elseif name=="Lighting" then return lighting end error(name) end},workspace=world,
  script={Parent={Model="Model"}},require=function() return Model end,Instance={new=new},CFrame=cf,
  UDim2={fromScale=function(...) return {...} end,new=function(...) return {...} end},Color3={new=function(...) return {...} end},
  Enum={CameraType={Scriptable="Scriptable"},Font={GothamMedium="GothamMedium"}},warn=function() end},{__index=getfenv()})
 local chunk=assert(loadstring(PLAYER_SOURCE)) setfenv(chunk,env)
 return {player=chunk(),camera=camera,world=world,gui=gui,lighting=lighting,step=step,new=new,cf=cf,all=all}
end
local passed=0
local function test(name,fn) fn() passed+=1 print("PASS "..name) end
local project=Model.Clone(Example.projects[1])
test("render interpolates and restores camera, effects, and overlay on stop",function()
 local h=harness() local p=h.player.New(project,h.gui,true)
 eq(h.camera.CameraType,"Scriptable") eq(h.camera.FieldOfView,70) eq(#h.lighting.children,2) eq(#h.gui.children,1)
 p:Render(3) assert(h.camera.CFrame.Position.X>0 and h.camera.CFrame.Position.X<15) assert(h.camera.FieldOfView<70)
 p:Destroy() eq(h.camera.CameraType,"Custom") eq(h.camera.CameraSubject,"subject") eq(h.camera.CFrame.Position.X,99) eq(h.camera.FieldOfView,75) eq(#h.lighting.children,0) eq(#h.gui.children,0)
end)
test("play, pause, resume and completion fire once",function()
 local h=harness() local p=h.player.New(project,h.gui,true) local completed=0 p.Completed:Connect(function(id) eq(id,project.id) completed+=1 end)
 p:Play() h.step:Fire(1) eq(p.time,1) p:Pause() h.step:Fire(1) eq(p.time,1) p:Play() h.step:Fire(5)
 eq(p.time,6) eq(completed,1) h.step:Fire(1) eq(completed,1) p:Destroy()
end)
test("preview clones characters and removes clones without moving originals",function()
 local h=harness() local rig=h.new("Model") rig.Name="Rig" rig.pivot=h.cf.new(99,0,0) rig.Parent=h.world
 local p=Model.Clone(project) p.scenes[1].characters={{path="Rig",animations={},moves={{time=0,position={0,0,0},rotation={0,0,0}},{time=6,position={12,0,0},rotation={0,0,0}}}}}
 local player=h.player.New(p,h.gui,true) player:Render(3) eq(rig.pivot.Position.X,99) eq(player.actors[1].model.pivot.Position.X,6)
 local clone=player.actors[1].model player:Destroy() eq(clone.destroyed,true) eq(rig.pivot.Position.X,99)
end)
test("runtime restores character position after local playback",function()
 local h=harness() local rig=h.new("Model") rig.Name="Rig" rig.pivot=h.cf.new(99,0,0) rig.Parent=h.world
 local p=Model.Clone(project) p.scenes[1].characters={{path="Rig",animations={},moves={{time=0,position={0,0,0},rotation={0,0,0}}}}}
 local player=h.player.New(p,h.gui,false) eq(rig.pivot.Position.X,0) player:Destroy() eq(rig.pivot.Position.X,99)
end)
test("invalid project fails before changing camera",function()
 local h=harness() local p=Model.Clone(project) p.scenes[1].keys={}
 eq(pcall(h.player.New,p,h.gui,true),false) eq(h.camera.CameraType,"Custom") eq(#h.lighting.children,0)
end)
print("Passed "..passed.." CineForge player scenarios")
