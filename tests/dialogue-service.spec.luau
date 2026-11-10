-- Actual service source is injected by tools/check.py.
local function signal() local f={} return {Connect=function(_,c) table.insert(f,c) end,Fire=function(_,...) for _,c in ipairs(f) do c(...) end end} end
local function harness()
 local clock=100
 local players={PlayerRemoving=signal()}
 local function pos(x) return setmetatable({x=x},{__sub=function(a,b) return {Magnitude=math.abs(a.x-b.x)} end}) end
 local player={UserId=1,Parent=players}
 player.Character={FindFirstChildOfClass=function() return {Health=100} end,FindFirstChild=function() return {Position=pos(player.distance or 0)} end}
 function player:GetAttributes() return {} end
 local part={Position=pos(0),IsDescendantOf=function() return true end}
 local response={views={}} function response:FireClient(_,v) table.insert(self.views,Model.Clone(v)) end
 local root={Config="Config",Request={OnServerEvent=signal()},Response=response}
 local store={}
 function store:UpdateAsync(_,f)
  if self.replay then f(Model.Clone(self.record)) end
  local r=f(Model.Clone(self.record)) if r==nil then return nil end self.record=Model.Clone(r)
  if self.lost then self.lost=false error("lost commit response") end
  return Model.Clone(r)
 end
 local guid=0 local collection={GetTagged=function() return {} end,GetInstanceAddedSignal=function() return signal() end}
 local services={Players=players,HttpService={GenerateGUID=function() guid+=1 return "id"..guid end},DataStoreService={GetDataStore=function() return store end},CollectionService=collection,
 ReplicatedStorage={WaitForChild=function() return root end},ServerScriptService={FindFirstChild=function() return nil end},ServerStorage={FindFirstChild=function() return nil end}}
 local chunk=assert(loadstring(SOURCE))
 setfenv(chunk,setmetatable({game={JobId="test",GetService=function(_,k) return assert(services[k],k) end},script={Parent={Model="Model"}},require=function(k) return if k=="Model" then Model else Example end,
 Instance={new=function() local e=signal() e.Event=e return e end},workspace={},os={clock=function() return clock end,time=function() return clock end},task={wait=function() end},warn=function() end},{__index=getfenv()}))
 local service=chunk() service.Start()
 local function choose(choice,token,turn) clock+=1 local v=response.views[#response.views] root.Request.OnServerEvent:Fire(player,token or v.token,turn or v.turn,choice) end
 return {service=service,player=player,part=part,store=store,root=root,choose=choose,tick=function() clock+=1 end}
end
local passed=0
local function test(name,f) f() passed+=1 print("PASS "..name) end
local function eq(a,b) assert(a==b,tostring(a).." ~= "..tostring(b)) end
test("remote cannot start arbitrary nodes or forge actions",function()
 local h=harness() h.root.Request.OnServerEvent:Fire(h.player,"fake",1,"GiveCurrency") eq(h.store.record,nil)
 assert(h.service.Open(h.player,"rowan_welcome",h.part))
 h.choose(1,"fake",1) eq(h.store.record.state.items.village_token,nil)
end)
test("choice tokens prevent replay and grant item once",function()
 local h=harness() assert(h.service.Open(h.player,"rowan_welcome",h.part))
 local v=h.root.Response.views[1] h.choose(1) eq(h.store.record.state.items.village_token,1)
 h.choose(1,v.token,v.turn) eq(h.store.record.state.items.village_token,1)
 h.choose("continue",v.token,2) eq(h.store.record.state.completed.rowan_welcome,true)
end)
test("distance is checked again before choosing",function()
 local h=harness() assert(h.service.Open(h.player,"rowan_welcome",h.part)) h.player.distance=100 h.choose(1)
 eq(h.store.record.state.items.village_token,nil)
end)
test("lost responses and callback replay do not duplicate actions",function()
 local h=harness() assert(h.service.Open(h.player,"rowan_welcome",h.part)) h.store.replay=true h.store.lost=true h.choose(1)
 eq(h.store.record.state.items.village_token,1) eq(h.store.record.session.turn,2)
end)
test("closing prevents further responses and one-time actions survive restart",function()
 local h=harness() assert(h.service.Open(h.player,"rowan_welcome",h.part)) local v=h.root.Response.views[1]
 h.choose(1) h.choose("close") h.choose(1,v.token,1) eq(h.store.record.state.items.village_token,1)
 h.tick() assert(h.service.Open(h.player,"rowan_welcome",h.part)) h.choose(1) eq(h.store.record.state.items.village_token,1)
end)
test("server ledger integration refuses edits during active conversations",function()
 local h=harness()
 assert(h.service.UpdateState(h.player,function(s) s.level=5 s.currency=20 end))
 eq(h.store.record.state.level,5)
 assert(h.service.Open(h.player,"rowan_welcome",h.part))
 eq(h.service.UpdateState(h.player,function(s) s.currency=99 end),false)
 eq(h.store.record.state.currency,20)
end)
print("Passed "..passed.." dialogue server scenarios")
