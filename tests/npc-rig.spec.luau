local function harness(failure,cancelAt)
 local destroyed,created,calls=0,{},{}
 local description={}
 for _,k in ipairs(Model.Assets) do description[k]=123 end
 for _,k in ipairs(Model.Scales) do description[k]=.5 end
 for _,k in ipairs(Model.Colors) do description[k]={R=.2,G=.4,B=.6} end
 description.GetAccessories=function() return {{AssetId=777,AccessoryType={Name="Hat"},IsLayered=false}} end
 description.SetAccessories=function(self,a) self.accessories=a end
 description.Destroy=function() destroyed+=1 end
 description.StaticFacialAnimation=true
 local removed=0
 local humanoid={} local rig={Name="",Destroy=function(self) self.destroyed=true end,IsA=function(_,kind) return kind=="Model" end,FindFirstChildOfClass=function() return humanoid end,FindFirstChild=function() return {} end,
  GetDescendants=function() return {{IsA=function(_,k) return k=="LuaSourceContainer" end,Destroy=function() removed+=1 end}} end}
 local players={}
 function players:GetUserIdFromNameAsync(name) table.insert(calls,"resolve:"..name) if failure=="resolve" then error("no user") end return 12345 end
 function players:GetHumanoidDescriptionFromUserIdAsync(id) assert(id==12345) table.insert(calls,"description") if failure=="description" then error("offline") end return description end
 function players:CreateHumanoidModelFromDescriptionAsync(d,kind) table.insert(calls,"build:"..kind) created[1]=d if failure=="build" then error("incompatible asset") end return rig end
 local environment={game={GetService=function() return players end},script={Parent={Model="Model"}},require=function() return Model end,
  Enum={HumanoidRigType={R6="R6",R15="R15"},AccessoryType={Hat="Hat"},HumanoidDisplayDistanceType={Viewer="Viewer",None="None"},HumanoidHealthDisplayType={DisplayWhenDamaged="Damaged",AlwaysOff="Off"}},
  Color3={fromRGB=function(r,g,b) return {R=r/255,G=g/255,B=b/255} end},Instance={new=function(kind) assert(kind=="HumanoidDescription") return Model.Clone(description) end}}
 local chunk=assert(loadstring(RIG_SOURCE)) setfenv(chunk,setmetatable(environment,{__index=getfenv()})) local module=chunk()
 local current=function() return not cancelAt or #calls<cancelAt end
 return module,current,function() return calls,destroyed,removed,rig,humanoid end
end
local a=Model.New("Avatar") a.username="Roblox" a.name="Independent name" a.showName=false
local r,current,stats=harness() local rig,c=r.Build(a,true,current) local calls,destroyed,removed,_,h=stats()
assert(table.concat(calls,",")=="resolve:Roblox,description,build:R15" and c.userId==12345 and c.username=="Roblox")
assert(c.name=="Independent name" and rig.Name==c.name and h.DisplayName=="NPC" and h.Health==100 and h.DisplayDistanceType=="None")
assert(c.appearance.properties.StaticFacialAnimation==true and c.appearance.properties.MoodAnimation==123)
assert(c.appearance.accessories[1].AssetId==777 and destroyed==1 and removed==1 and a.appearance==nil)
local rr,cur,st=harness() local custom=Model.New() custom.rig="R6" local _,cc=rr.Build(custom,false,cur) local log=st() assert(#log==1 and log[1]=="build:R6" and cc.mode=="Custom")
for _,failure in ipairs({"resolve","description","build"}) do local mod,now,inspect=harness(failure) assert(not pcall(mod.Build,a,true,now)) local _,count=inspect() assert(count==(if failure=="build" then 1 else 0)) end
for stage=1,3 do local mod,now,inspect=harness(nil,stage) assert(not pcall(mod.Build,a,true,now)) local log,count,_,built=inspect() assert(#log==stage) if stage==3 then assert(built.destroyed) end assert(count==(if stage>=2 then 1 else 0)) end
local mod,now,inspect=harness() local frozen=Model.Clone(c) frozen.rig="R6" mod.Build(frozen,false,now) assert(#(inspect())==1,"Snapshot must not make another username lookup")
local bad=Model.New() bad.appearance.accessories={{AssetId=123,AccessoryType="Invalid",IsLayered=false}}
assert(not pcall(mod.Build,bad,false,now))
print("PASS NPC rig: independent custom creation, username/description/rig APIs, snapshots, humanoid settings, executable removal, API failures, cancellation at all yield boundaries and cleanup")
