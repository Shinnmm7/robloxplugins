local Http=game:GetService("HttpService")
local History=game:GetService("ChangeHistoryService")
local Model=require(script.Parent.Model)
local G={}
local function new(class,name,parent) local o=Instance.new(class) o.Name=name o.Parent=parent return o end
local function source(class,name,code,parent) local o=new(class,name,parent) o.Source=code return o end
local function edit(label,callback)
 assert(not game:GetService("RunService"):IsRunning(),"Stop Play before modifying the place")
 local id=History:TryBeginRecording("DialogueCraftPro."..Http:GenerateGUID(false),label) assert(id,"Studio is recording another operation")
 local ok,result=pcall(callback) History:FinishRecording(id,if ok then Enum.FinishRecordingOperation.Commit else Enum.FinishRecordingOperation.Cancel)
 if not ok then error(result,0) end return result
end
function G.Export(config)
 return edit("Export DialogueCraft configuration",function()
  local selection=game:GetService("Selection")
  local json=Http:JSONEncode(config)
  local value=new("StringValue","DialogueCraftExport",game:GetService("ServerStorage")) value.Value=json selection:Set({value})
  return "Exported JSON StringValue to ServerStorage; copy Value or select it to import."
 end)
end
function G.Import()
 local selected=game:GetService("Selection"):Get()[1] assert(selected and selected:IsA("StringValue"),"Select an exported configuration StringValue")
 local config=Http:JSONDecode(selected.Value) assert(#Model.Validate(config)==0,table.concat(Model.Validate(config),"\n")) return config
end
function G.Generate(config)
 local errors=Model.Validate(config) assert(#errors==0,table.concat(errors,"\n"))
 local json=Http:JSONEncode(config) assert(#json<3000000,"Configuration exceeds 3 MB")
 return edit("Generate DialogueCraft Pro",function()
  local destinations={{game:GetService("ReplicatedStorage"),"DialogueCraftPro"},{game:GetService("ServerScriptService"),"DialogueCraftPro"},{game:GetService("StarterPlayer").StarterPlayerScripts,"DialogueCraftProClient"}}
  for _,pair in ipairs(destinations) do local old=pair[1]:FindFirstChild(pair[2]) assert(not old or old:GetAttribute("DialogueCraftGenerated"),"Unowned destination: "..pair[2]) end
  local actionsFolder=game:GetService("ServerStorage"):FindFirstChild("DialogueCraftActions")
  assert(not actionsFolder or actionsFolder:IsA("Folder"),"DialogueCraftActions must be a Folder")
  for _,p in ipairs(config.projects) do for _,n in ipairs(p.nodes) do
   if actionsFolder and n.type=="Action" and n.action.type=="Event" then
    local existing=actionsFolder:FindFirstChild(n.action.key)
    assert(not existing or existing:IsA("BindableEvent"),"Action destination must be BindableEvent")
   end
  end end
  local r=new("Folder","DialogueCraftPro") local s=new("Folder","DialogueCraftPro")
  source("ModuleScript","Config",'return game:GetService("HttpService"):JSONDecode('..string.format("%q",json)..')',r)
  new("RemoteEvent","Request",r) new("RemoteEvent","Response",r)
  new("StringValue","ConfigurationData",r).Value=json
  for _,name in ipairs({"Model","Service"}) do source("ModuleScript",name,script.Parent.Templates[name].Value,s) end
  source("Script","Bootstrap",script.Parent.Templates.Runtime.Value,s)
  local c=source("LocalScript","DialogueCraftProClient",script.Parent.Templates.Client.Value)
  for i,o in ipairs({r,s,c}) do o:SetAttribute("DialogueCraftGenerated",true) local pair=destinations[i] local old=pair[1]:FindFirstChild(pair[2]) if old then old:Destroy() end o.Parent=pair[1] end
  local folder=game:GetService("ServerStorage"):FindFirstChild("DialogueCraftActions")
  assert(not folder or folder:IsA("Folder"),"DialogueCraftActions must be a Folder")
  if not folder then folder=new("Folder","DialogueCraftActions",game:GetService("ServerStorage")) end
  for _,p in ipairs(config.projects) do for _,n in ipairs(p.nodes) do if n.type=="Action" and n.action.type=="Event" then
   local existing=folder:FindFirstChild(n.action.key) assert(not existing or existing:IsA("BindableEvent"),"Action destination must be BindableEvent")
   if not existing then new("BindableEvent",n.action.key,folder) end
  end end end
  return "Generated server, client, configuration, remotes, and action events. Undo is available."
 end)
end
function G.Demo(id,npc)
 return edit("Create DialogueCraft NPC",function()
  local p=new("Part","DialogueCraftNPC",workspace) p.Anchored=true p.Size=Vector3.new(3,5,3) p.Position=Vector3.new(-8,3,-12) p.Color=Color3.fromRGB(114,91,220)
  p:SetAttribute("DialogueId",id)
  local prompt=new("ProximityPrompt","Talk",p) prompt.ActionText="Talk" prompt.ObjectText=npc or "Rowan" prompt.MaxActivationDistance=10
  game:GetService("CollectionService"):AddTag(p,"DialogueCraftNPC") return "NPC created near (-8, 3, -12). Play and use its Talk prompt."
 end)
end
return G
