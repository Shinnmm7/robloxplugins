local function eq(a,b) assert(a==b,tostring(a).." ~= "..tostring(b)) end
local function harness()
 local function new(class)
  local object={ClassName=class,_children={},_attributes={}}
  function object:FindFirstChild(name) for _,child in ipairs(self._children) do if child.Name==name then return child end end end
  function object:WaitForChild(name) return assert(self:FindFirstChild(name),name) end
  function object:SetAttribute(k,v) self._attributes[k]=v end
  function object:GetAttribute(k) return self._attributes[k] end
  function object:Destroy() self.Parent=nil self.destroyed=true end
  function object:IsA(className) return self.ClassName==className end
  return setmetatable(object,{__newindex=function(self,key,value)
   if key=="Parent" then local old=rawget(self,"_parent") if old then table.remove(old._children,table.find(old._children,self)) end rawset(self,"_parent",value) if value then table.insert(value._children,self) end
   else rawset(self,key,value) end
  end,__index=function(self,key) return if key=="Parent" then rawget(self,"_parent") else self:FindFirstChild(key) end})
 end
 local replicated,starter,scripts,storage=new("Folder"),new("Folder"),new("Folder"),new("Folder")
 scripts.Name="StarterPlayerScripts" scripts.Parent=starter
 local history={finished={}}
 function history:TryBeginRecording() return "record" end
 function history:FinishRecording(_,op) table.insert(self.finished,op) end
 local selection={Set=function(self,list) self.list=list end,Get=function(self) return self.list or {} end}
 local http={JSONEncode=function() return '{"test":"escaped"}' end,JSONDecode=function() return Model.Clone(Example) end,GenerateGUID=function() return "id" end}
 local services={HttpService=http,ChangeHistoryService=history,RunService={IsRunning=function() return false end},ReplicatedStorage=replicated,StarterPlayer=starter,ServerStorage=storage,Selection=selection}
 local templates={Model={Value="--model"},Player={Value="--player"},Client={Value="--client"}}
 local chunk=assert(loadstring(SOURCE))
 setfenv(chunk,setmetatable({game={GetService=function(_,name) return assert(services[name],name) end},script={Parent={Model="Model",Templates=templates}},require=function() return Model end,Instance={new=new},Enum={FinishRecordingOperation={Commit="commit",Cancel="cancel"}}},{__index=getfenv()}))
 return {generator=chunk(),replicated=replicated,scripts=scripts,history=history,selection=selection,storage=storage,new=new}
end
local passed=0
local function test(name,fn) fn() passed+=1 print("PASS "..name) end
test("generated runtime contains working modules and events",function()
 local h=harness() h.generator.Generate(Example)
 local r=h.replicated.CineForgePro eq(r.Model.ClassName,"ModuleScript") eq(r.Player.ClassName,"ModuleScript") eq(r.Config.ClassName,"ModuleScript")
 eq(r.Model.Source,"--model") eq(r.Player.Source,"--player") assert(loadstring(r.Config.Source))
 eq(r.Play.ClassName,"BindableEvent") eq(r.Stop.ClassName,"BindableEvent") eq(r.Completed.ClassName,"BindableEvent") eq(r.PlayForClient.ClassName,"RemoteEvent") eq(h.scripts.CineForgeProClient.Source,"--client") eq(h.history.finished[1],"commit")
end)
test("regeneration replaces owned output only",function()
 local h=harness() h.generator.Generate(Example) local old=h.replicated.CineForgePro h.generator.Generate(Example)
 assert(old.destroyed) eq(#h.replicated._children,1) eq(#h.scripts._children,1)
end)
test("unowned collisions and invalid projects fail without replacing output",function()
 local h=harness() local existing=h.new("Folder") existing.Name="CineForgePro" existing.Parent=h.replicated
 eq(pcall(h.generator.Generate,Example),false) eq(h.replicated.CineForgePro,existing) eq(h.history.finished[1],"cancel")
 local invalid=Model.Clone(Example) invalid.projects[1].scenes[1].keys={}
 eq(pcall(h.generator.Generate,invalid),false) eq(h.replicated.CineForgePro,existing)
end)
test("JSON export is selected and can be imported",function()
 local h=harness() h.generator.Export(Example) eq(h.selection:Get()[1].ClassName,"StringValue") eq(h.storage.CineForgeExport.Value,'{"test":"escaped"}') eq(#h.generator.Import().projects,1)
end)
print("Passed "..passed.." CineForge generator scenarios")
