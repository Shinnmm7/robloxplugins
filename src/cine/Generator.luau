local Http=game:GetService("HttpService")
local History=game:GetService("ChangeHistoryService")
local Model=require(script.Parent.Model)
local G={}
local function create(class,name,parent) local obj=Instance.new(class) obj.Name=name obj.Parent=parent return obj end
local function source(class,name,code,parent) local obj=create(class,name,parent) obj.Source=code return obj end
local function edit(label,callback)
 assert(not game:GetService("RunService"):IsRunning(),"Stop the play test before generating")
 local id=History:TryBeginRecording("CineForgePro."..Http:GenerateGUID(false),label) assert(id,"Studio is recording another operation")
 local ok,result=pcall(callback)
 History:FinishRecording(id,if ok then Enum.FinishRecordingOperation.Commit else Enum.FinishRecordingOperation.Cancel)
 if not ok then error(result,0) end return result
end
function G.Export(config)
 return edit("Export CineForge configuration",function()
  local value=create("StringValue","CineForgeExport",game:GetService("ServerStorage")) value.Value=Http:JSONEncode(config)
  game:GetService("Selection"):Set({value}) return "Exported JSON to ServerStorage as a selected StringValue."
 end)
end
function G.Import()
 local value=game:GetService("Selection"):Get()[1]
 assert(value and value:IsA("StringValue"),"Select a CineForge JSON StringValue")
 local config=Http:JSONDecode(value.Value)
 local errors=Model.Validate(config) assert(#errors==0,table.concat(errors,"\n")) return config
end
function G.Generate(config)
 local errors=Model.Validate(config) assert(#errors==0,table.concat(errors,"\n"))
 local json=Http:JSONEncode(config) assert(#json<3000000,"Configuration too large")
 return edit("Generate CineForge runtime",function()
  local destinations={{game:GetService("ReplicatedStorage"),"CineForgePro"},{game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"),"CineForgeProClient"}}
  for _,pair in ipairs(destinations) do local old=pair[1]:FindFirstChild(pair[2]) assert(not old or old:GetAttribute("CineForgeGenerated")==true,"Unowned destination: "..pair[2]) end
  local root=create("Folder","CineForgePro")
  source("ModuleScript","Config",'return game:GetService("HttpService"):JSONDecode('..string.format("%q",json)..')',root)
  create("StringValue","ConfigurationData",root).Value=json
  source("ModuleScript","Model",script.Parent.Templates.Model.Value,root)
  source("ModuleScript","Player",script.Parent.Templates.Player.Value,root)
  create("BindableEvent","Play",root) create("BindableEvent","Stop",root) create("BindableEvent","Completed",root) create("RemoteEvent","PlayForClient",root)
  local client=source("LocalScript","CineForgeProClient",script.Parent.Templates.Client.Value)
  for i,obj in ipairs({root,client}) do
   obj:SetAttribute("CineForgeGenerated",true)
   local pair=destinations[i] local old=pair[1]:FindFirstChild(pair[2]) if old then old:Destroy() end obj.Parent=pair[1]
  end
  return "Generated configuration, reusable player, controls and client script. Undo is available."
 end)
end
return G
