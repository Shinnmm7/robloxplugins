local History=game:GetService("ChangeHistoryService")
local Http=game:GetService("HttpService")
local Selection=game:GetService("Selection")
local Model=require(script.Parent.Model)
local Manager={}
local CONFIG="NPCCreatorConfig"
local SCRIPT="NPCCreatorBehavior"
local function own(obj) return obj and obj:IsA("Model") and obj:GetAttribute("NPCCreatorPro")==true end
local function validate(c) local e=Model.Validate(c,true) assert(#e==0,table.concat(e,"\n")) end
local function editable() assert(not game:GetService("RunService"):IsRunning(),"Stop the play test before editing NPCs") end
local function edit(label,fn)
 editable()
 local id=History:TryBeginRecording("NPCCreatorPro."..Http:GenerateGUID(false),label) assert(id,"Another Studio operation is recording. Try again.")
 local ok,result=pcall(fn)
 History:FinishRecording(id,if ok then Enum.FinishRecordingOperation.Commit else Enum.FinishRecordingOperation.Cancel)
 if not ok then error(result,0) end return result
end
function Manager.List()
 local list={}
 for _,obj in ipairs(workspace:GetDescendants()) do if own(obj) then table.insert(list,obj) end end
 table.sort(list,function(a,b) return a.Name:lower()<b.Name:lower() end) return list
end
function Manager.Read(npc)
 assert(own(npc),"Select an NPC Creator model")
 local value=npc:FindFirstChild(CONFIG) assert(value and value:IsA("StringValue") and value:GetAttribute("NPCCreatorPro"),"NPC preset data is missing")
 assert(#value.Value<250000,"NPC preset is too large")
 local c=Http:JSONDecode(value.Value) validate(c)
 local h=npc:FindFirstChildOfClass("Humanoid")
 c.name=npc.Name
 if h then c.displayName=h.DisplayName c.health=h.MaxHealth c.speed=h.WalkSpeed c.jump=h.JumpPower c.showName=h.DisplayDistanceType~=Enum.HumanoidDisplayDistanceType.None end
 return c
end
local function configure(npc,c,newId,resetAnchors)
 local h=npc:FindFirstChildOfClass("Humanoid") assert(h and npc:FindFirstChild("HumanoidRootPart"),"NPC rig is incomplete")
 for _,name in ipairs({CONFIG,SCRIPT}) do local old=npc:FindFirstChild(name) assert(not old or old:GetAttribute("NPCCreatorPro"),"Unowned NPC child: "..name) end
 local json=Http:JSONEncode(c) assert(#json<250000,"NPC preset is too large")
 npc.Name=c.name npc:SetAttribute("NPCCreatorPro",true) npc:SetAttribute("NPCDescription",c.description)
 npc:SetAttribute("NPCSourceUsername",c.username) npc:SetAttribute("NPCSourceUserId",c.userId)
 if newId or not npc:GetAttribute("NPCCreatorId") then npc:SetAttribute("NPCCreatorId",Http:GenerateGUID(false)) end
 h.DisplayName=c.displayName h.MaxHealth=c.health h.Health=if resetAnchors then c.health else math.min(h.Health,c.health) h.WalkSpeed=c.speed h.UseJumpPower=true h.JumpPower=c.jump
 h.DisplayDistanceType=if c.showName then Enum.HumanoidDisplayDistanceType.Viewer else Enum.HumanoidDisplayDistanceType.None
 h.HealthDisplayType=if c.showName then Enum.HumanoidHealthDisplayType.DisplayWhenDamaged else Enum.HumanoidHealthDisplayType.AlwaysOff
 local previous=npc:FindFirstChild(CONFIG)
 local wasStationary=false
 if previous then local ok,data=pcall(Http.JSONDecode,Http,previous.Value) wasStationary=ok and data.behavior and data.behavior.enabled and data.behavior.motion=="Stationary" end
 if resetAnchors then for _,part in ipairs(npc:GetDescendants()) do if part:IsA("BasePart") then part.Anchored=false end end end
 if resetAnchors or c.behavior.enabled or wasStationary then npc.HumanoidRootPart.Anchored=c.behavior.enabled and c.behavior.motion=="Stationary" end
 local value=npc:FindFirstChild(CONFIG) or Instance.new("StringValue") value.Name=CONFIG value:SetAttribute("NPCCreatorPro",true) value.Value=json value.Parent=npc
 local old=npc:FindFirstChild(SCRIPT) if old then old:Destroy() end
 if c.behavior.enabled then
  local behavior=Instance.new("Script") behavior.Name=SCRIPT behavior:SetAttribute("NPCCreatorPro",true)
  behavior.Source=script.Parent.Templates.Behavior.Value behavior.Parent=npc
 end
end
-- Detached rigs are outside Studio's recorded tree; dispose them explicitly if
-- configuration, script permissions or a later world edit fails.
local function cloneEdit(original,c,newId,resetAnchors,label,callback)
 local clone=original:Clone() assert(clone,"NPC is not Archivable")
 local ok,result=pcall(function()
  configure(clone,c,newId,resetAnchors)
  return edit(label,function() return callback(clone) end)
 end)
 if not ok then clone:Destroy() error(result,0) end return result
end
function Manager.Spawn(preview,c,settings)
 validate(c) assert(preview,"Build a preview first") editable()
 local location
 if settings.spawnMode=="Selection" then
  local selected=Selection:Get()[1]
  assert(selected and (selected:IsA("Model") or selected:IsA("BasePart")) and selected:IsDescendantOf(workspace),"Select a Workspace part or model for the spawn location")
  local box,size if selected:IsA("Model") then box,size=selected:GetBoundingBox() else box,size=selected.CFrame,selected.Size end
  location=CFrame.new(box.Position+Vector3.new(0,size.Y/2,0))
 else local camera=workspace.CurrentCamera assert(camera,"Studio has no camera") local point=camera.CFrame.Position+camera.CFrame.LookVector*settings.distance location=CFrame.new(point) end
 return cloneEdit(preview,c,true,true,"Spawn NPC",function(npc)
  local folder=workspace:FindFirstChild(settings.folder)
  assert(not folder or (folder:IsA("Folder") and folder:GetAttribute("NPCCreatorPro")),"An unowned object already uses the NPC folder name")
  if not folder then folder=Instance.new("Folder") folder.Name=settings.folder folder:SetAttribute("NPCCreatorPro",true) folder.Parent=workspace end
  npc:PivotTo(location)
  if settings.spawnMode=="Selection" then local box,size=npc:GetBoundingBox() npc:PivotTo(npc:GetPivot()+Vector3.new(0,location.Position.Y-(box.Position.Y-size.Y/2)+.05,0)) end
  npc.Parent=folder Selection:Set({npc}) return npc
 end)
end
function Manager.Apply(npc,c)
 assert(own(npc) and npc:IsDescendantOf(workspace),"Select a managed NPC in Workspace") validate(c)
 -- Properties/behavior updates must not pretend that an unbuilt appearance was applied.
 local existing=Manager.Read(npc) local actual=Model.Clone(c)
 for _,key in ipairs({"mode","rig","username","userId","appearance"}) do actual[key]=existing[key] end
 return edit("Edit NPC properties and behavior",function() configure(npc,actual,false) return actual end)
end
function Manager.Replace(npc,preview,c)
 assert(own(npc) and npc:IsDescendantOf(workspace),"Select a managed NPC in Workspace") validate(c) assert(preview,"Build a preview first")
 return cloneEdit(preview,c,false,true,"Replace NPC rig",function(replacement)
  for key,value in pairs(npc:GetAttributes()) do if key~="NPCDescription" and key~="NPCSourceUsername" and key~="NPCSourceUserId" then replacement:SetAttribute(key,value) end end
  replacement:PivotTo(npc:GetPivot()) replacement.Parent=npc.Parent npc:Destroy() Selection:Set({replacement}) return replacement
 end)
end
function Manager.Duplicate(npc)
 local c=Manager.Read(npc) c.name=npc.Name:sub(1,75).." Copy"
 return cloneEdit(npc,c,true,false,"Duplicate NPC",function(copy) copy:PivotTo(npc:GetPivot()+Vector3.new(5,0,0)) copy.Parent=npc.Parent Selection:Set({copy}) return copy
 end)
end
function Manager.Delete(npc)
 assert(own(npc) and npc:IsDescendantOf(workspace),"Select a managed NPC in Workspace")
 return edit("Delete NPC",function() npc:Destroy() end)
end
function Manager.Select(npc) assert(own(npc),"NPC no longer exists") Selection:Set({npc}) end
return Manager
