local Players=game:GetService("Players")
local Model=require(script.Parent.Model)
local Rig={}
function Rig.Encode(description)
 local data={properties={},colors={},accessories={}}
 for _,key in ipairs(Model.Assets) do data.properties[key]=description[key] end
 for _,key in ipairs(Model.Scales) do data.properties[key]=description[key] end
 for _,key in ipairs(Model.Flags) do data.properties[key]=description[key] end
 for _,key in ipairs(Model.Colors) do local c=description[key] data.colors[key]={c.R*255,c.G*255,c.B*255} end
 for _,entry in ipairs(description:GetAccessories(true)) do
  table.insert(data.accessories,{AssetId=entry.AssetId,AccessoryType=entry.AccessoryType.Name,IsLayered=entry.IsLayered==true,Order=entry.Order,Puffiness=entry.Puffiness})
 end
 return data
end
function Rig.Decode(data)
 local d=Instance.new("HumanoidDescription")
 local ok,err=pcall(function()
  for key,value in pairs(data.properties) do d[key]=value end
  for key,value in pairs(data.colors) do d[key]=Color3.fromRGB(value[1],value[2],value[3]) end
  local accessories={}
  for _,entry in ipairs(data.accessories) do
   local kind=Enum.AccessoryType[entry.AccessoryType] assert(kind,"Unsupported accessory type: "..entry.AccessoryType)
   table.insert(accessories,{AssetId=entry.AssetId,AccessoryType=kind,IsLayered=entry.IsLayered,Order=entry.Order,Puffiness=entry.Puffiness})
  end
  d:SetAccessories(accessories,true)
 end)
 if not ok then d:Destroy() error(err,0) end return d
end
-- Called in a task; all yielding Roblox operations are protected by the caller.
-- isCurrent prevents obsolete searches from publishing results or building more assets.
function Rig.Build(config,resolve,isCurrent)
 local c=Model.Clone(config)
 local errors=Model.Validate(c,false) assert(#errors==0,table.concat(errors,"\n"))
 isCurrent=isCurrent or function() return true end
 local description,rig
 local ok,err=pcall(function()
  if c.mode=="Avatar" and (resolve or not c.appearance) then
   local resolved,id=pcall(Players.GetUserIdFromNameAsync,Players,c.username)
   assert(resolved,"Username lookup failed. Check the username and your connection. "..tostring(id))
   assert(isCurrent(),"Cancelled") c.userId=id
   local loaded,result=pcall(Players.GetHumanoidDescriptionFromUserIdAsync,Players,id)
   assert(loaded,"Avatar appearance could not be loaded. "..tostring(result))
   description=result assert(isCurrent(),"Cancelled") c.appearance=Rig.Encode(description)
  else description=Rig.Decode(c.appearance) end
  assert(isCurrent(),"Cancelled")
  rig=Players:CreateHumanoidModelFromDescriptionAsync(description,Enum.HumanoidRigType[c.rig])
  assert(isCurrent(),"Cancelled") assert(rig and rig:IsA("Model"),"Roblox did not return a rig")
  local humanoid=rig:FindFirstChildOfClass("Humanoid") assert(humanoid and rig:FindFirstChild("HumanoidRootPart"),"Avatar is missing a Humanoid or root part")
  -- Imported avatar assets must never supply executable scripts.
  for _,obj in ipairs(rig:GetDescendants()) do if obj:IsA("LuaSourceContainer") then obj:Destroy() end end
  rig.Name=c.name humanoid.DisplayName=c.displayName humanoid.MaxHealth=c.health humanoid.Health=c.health
  humanoid.WalkSpeed=c.speed humanoid.UseJumpPower=true humanoid.JumpPower=c.jump
  humanoid.DisplayDistanceType=if c.showName then Enum.HumanoidDisplayDistanceType.Viewer else Enum.HumanoidDisplayDistanceType.None
  humanoid.HealthDisplayType=if c.showName then Enum.HumanoidHealthDisplayType.DisplayWhenDamaged else Enum.HumanoidHealthDisplayType.AlwaysOff
 end)
 if description then description:Destroy() end
 if not ok then if rig then rig:Destroy() end error(err,0) end
 return rig,c
end
return Rig
