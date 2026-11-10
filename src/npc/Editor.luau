local Http=game:GetService("HttpService")
local Selection=game:GetService("Selection")
local Input=game:GetService("UserInputService")
local Run=game:GetService("RunService")
local Model=require(script.Parent.Model)
local Rig=require(script.Parent.Rig)
local Preview=require(script.Parent.Preview)
local Manager=require(script.Parent.Manager)
local Editor={}
local C={bg=Color3.fromRGB(20,22,28),panel=Color3.fromRGB(30,33,42),input=Color3.fromRGB(40,44,55),text=Color3.fromRGB(231,235,246),muted=Color3.fromRGB(159,170,192),accent=Color3.fromRGB(78,107,227),error=Color3.fromRGB(255,147,147)}
local function ui(kind,parent,props)
 local o=Instance.new(kind) for key,value in pairs(props or {}) do o[key]=value end o.Parent=parent return o
end
function Editor.Mount(plugin,widget)
 local alive=true local serial=0 local busy=false local ready=false local page="Custom" local tab="Identity"
 local configs={Custom=Model.New("Custom"),Avatar=Model.New("Avatar")}
 local mode="Custom" local target=nil local selectedPreset=nil local presetName="My NPC" local search=""
 local settings={spawnMode="Camera",distance=12,folder="NPCCreatorNPCs",autoRotate=false}
 local presets={}
 local function loadSetting(key)
  local ok,v=pcall(plugin.GetSetting,plugin,key)
  if not ok or type(v)~="string" or #v>3000000 then return nil end
  local decoded,value=pcall(Http.JSONDecode,Http,v) return if decoded then value else nil
 end
 local saved=loadSetting("NPCCreatorPro.Settings.v1")
 if type(saved)=="table" then
  if saved.spawnMode=="Camera" or saved.spawnMode=="Selection" then settings.spawnMode=saved.spawnMode end
  if type(saved.distance)=="number" and saved.distance>=0 and saved.distance<=200 then settings.distance=saved.distance end
  if type(saved.folder)=="string" and #saved.folder>0 and #saved.folder<=80 then settings.folder=saved.folder end
  settings.autoRotate=saved.autoRotate==true
 end
 local stored=loadSetting("NPCCreatorPro.Presets.v1")
 if type(stored)=="table" then for _,p in ipairs(stored) do if type(p)=="table" and type(p.name)=="string" and #p.name<=80 and #Model.Validate(p.config,true)==0 then table.insert(presets,p) end end end
 local root=ui("Frame",widget,{Size=UDim2.fromScale(1,1),BackgroundColor3=C.bg,BorderSizePixel=0})
 ui("TextLabel",root,{Text="NPC CREATOR PRO",Font=Enum.Font.GothamBold,TextSize=19,TextColor3=C.text,BackgroundTransparency=1,TextXAlignment=Enum.TextXAlignment.Left,Position=UDim2.fromOffset(18,8),Size=UDim2.new(1,-36,0,36)})
 local status=ui("TextLabel",root,{Text="Create a custom rig or load a Roblox username.",Font=Enum.Font.Gotham,TextSize=13,TextColor3=C.muted,TextWrapped=true,TextXAlignment=Enum.TextXAlignment.Left,Position=UDim2.new(0,168,1,-64),Size=UDim2.new(1,-180,0,56),BackgroundTransparency=1})
 local function message(text,isError) if alive then status.Text=tostring(text) status.TextColor3=if isError then C.error else C.muted end end
 local function safe(fn) return function(...) local ok,err=pcall(fn,...) if not ok then message(err,true) end end end
 local sidebar=ui("Frame",root,{Position=UDim2.fromOffset(8,52),Size=UDim2.new(0,148,1,-62),BackgroundColor3=C.panel,BorderSizePixel=0})
 ui("UIListLayout",sidebar,{Padding=UDim.new(0,8),SortOrder=Enum.SortOrder.LayoutOrder})
 ui("UIPadding",sidebar,{PaddingTop=UDim.new(0,10),PaddingLeft=UDim.new(0,8),PaddingRight=UDim.new(0,8)})
 local content=ui("Frame",root,{Position=UDim2.fromOffset(168,52),Size=UDim2.new(.63,-168,1,-120),BackgroundColor3=C.panel,BorderSizePixel=0})
 local right=ui("Frame",root,{Position=UDim2.new(.63,10,0,52),Size=UDim2.new(.37,-22,1,-120),BackgroundColor3=C.panel,BorderSizePixel=0})
 local previewInfo=ui("TextLabel",right,{Text="NPC preview • R15",Font=Enum.Font.GothamBold,TextSize=14,TextColor3=C.text,BackgroundTransparency=1,TextWrapped=true,Size=UDim2.new(1,-16,0,50),Position=UDim2.fromOffset(8,4)})
 local viewport=ui("ViewportFrame",right,{Position=UDim2.fromOffset(8,58),Size=UDim2.new(1,-16,1,-270),BackgroundColor3=C.bg,BorderSizePixel=0,Active=true})
 local preview=Preview.New(viewport)
 local previewNote=ui("TextLabel",right,{Text="Build a preview to inspect the rig.",Font=Enum.Font.Gotham,TextSize=12,TextColor3=C.muted,TextWrapped=true,BackgroundTransparency=1,Position=UDim2.new(0,8,1,-208),Size=UDim2.new(1,-16,0,40)})
 local rotation=ui("Frame",right,{Position=UDim2.new(0,8,1,-164),Size=UDim2.new(1,-16,0,30),BackgroundTransparency=1})
 ui("UIGridLayout",rotation,{CellSize=UDim2.new(.25,-4,1,0),CellPadding=UDim2.fromOffset(4,0),SortOrder=Enum.SortOrder.LayoutOrder})
 local function button(parent,text,fn,height)
  local o=ui("TextButton",parent,{Text=text,Font=Enum.Font.GothamMedium,TextSize=13,TextColor3=C.text,BackgroundColor3=C.input,BorderSizePixel=0,Size=UDim2.new(1,0,0,height or 32),AutoButtonColor=true,TextWrapped=true})
  ui("UICorner",o,{CornerRadius=UDim.new(0,5)}) o.Activated:Connect(safe(fn)) return o
 end
 button(rotation,"↶",function() preview:Rotate(-.25) end) button(rotation,"↷",function() preview:Rotate(.25) end)
 button(rotation,"Zoom +",function() preview:Zoom(-.15) end) button(rotation,"Zoom −",function() preview:Zoom(.15) end)
 local buildButton,spawnButton
 local function config() return configs[mode] end
 local function invalidate()
  serial+=1 busy=false ready=false
  previewNote.Text="Settings changed. Build preview before spawning."
  if buildButton then buildButton.Text="Build preview" end
 end
 local draw
 local function build(resolve)
  assert(not busy,"Avatar load already in progress")
  local c=Model.Clone(config()) local errors=Model.Validate(c,false) assert(#errors==0,table.concat(errors,"\n"))
  invalidate() busy=true local request=serial
  buildButton.Text="Loading…" previewNote.Text="Loading rig and avatar assets…" message("Loading through Roblox avatar APIs…")
  task.spawn(function()
   local ok,model,result=pcall(Rig.Build,c,resolve,function() return alive and request==serial end)
   if not alive or request~=serial then if ok and model then model:Destroy() end return end
   busy=false buildButton.Text="Build preview"
   if not ok then ready=false previewNote.Text="Preview failed. Check inputs and try again." message(model,true) return end
   configs[mode]=result preview:Set(model) ready=true
   previewInfo.Text=result.rig.." • "..result.name..(if result.mode=="Avatar" then "\n@"..result.username.." • UserId "..tostring(result.userId) else "\nCustom NPC")
   previewNote.Text="Ready • drag to rotate, scroll to zoom" message("Preview ready. NPC has not been spawned.") draw()
  end)
 end
 buildButton=button(right,"Build preview",function() build(false) end) buildButton.Position=UDim2.new(0,8,1,-124) buildButton.Size=UDim2.new(1,-16,0,34)
 spawnButton=button(right,"Spawn NPC",function()
  assert(ready and preview.model,"Build a current preview first")
  local npc=Manager.Spawn(preview.model,config(),settings) target=npc message("Spawned "..npc.Name..". Use Studio Undo to revert.") draw()
 end) spawnButton.Position=UDim2.new(0,8,1,-82) spawnButton.Size=UDim2.new(1,-16,0,34) spawnButton.BackgroundColor3=C.accent
 local reset=button(right,"Reset view",function() preview.yaw=math.pi preview.zoom=1 preview:Render() end) reset.Position=UDim2.new(0,8,1,-40) reset.Size=UDim2.new(1,-16,0,30)
 local dragging=false local lastX=0 local hovering=false
 viewport.MouseEnter:Connect(function() hovering=true end) viewport.MouseLeave:Connect(function() hovering=false end)
 viewport.InputBegan:Connect(function(input) if input.UserInputType==Enum.UserInputType.MouseButton1 then dragging=true lastX=input.Position.X end end)
 local inputChanged=Input.InputChanged:Connect(function(input)
  if input.UserInputType==Enum.UserInputType.MouseMovement and dragging then local x=input.Position.X preview:Rotate((x-lastX)*.012) lastX=x
  elseif input.UserInputType==Enum.UserInputType.MouseWheel and hovering then preview:Zoom(-input.Position.Z*.1) end
 end)
 local inputEnded=Input.InputEnded:Connect(function(input) if input.UserInputType==Enum.UserInputType.MouseButton1 then dragging=false end end)
 local rotating=Run.PreRender:Connect(function(dt) if alive and widget.Enabled and settings.autoRotate and not dragging and preview.model then preview:Rotate(math.min(dt,.1)*.45) end end)
 local order=0 local form
 local function line(text,height)
  order+=1
  return ui("TextLabel",form,{Text=text,LayoutOrder=order,Size=UDim2.new(1,-4,0,height or 28),BackgroundTransparency=1,TextColor3=C.muted,Font=Enum.Font.Gotham,TextSize=13,TextWrapped=true,TextXAlignment=Enum.TextXAlignment.Left})
 end
 local function action(text,fn) order+=1 local b=button(form,text,fn) b.LayoutOrder=order return b end
 local function field(label,value,apply,multiline)
  line(label)
  order+=1
  local box=ui("TextBox",form,{Name=label,Text=tostring(value),LayoutOrder=order,Size=UDim2.new(1,-4,0,if multiline then 72 else 32),BackgroundColor3=C.input,TextColor3=C.text,Font=Enum.Font.Gotham,TextSize=13,ClearTextOnFocus=false,TextWrapped=multiline==true,MultiLine=multiline==true,TextXAlignment=Enum.TextXAlignment.Left})
  ui("UIPadding",box,{PaddingLeft=UDim.new(0,8),PaddingRight=UDim.new(0,8)})
  box.FocusLost:Connect(safe(function() apply(box.Text) end)) return box
 end
 local function textField(label,obj,key,multiline)
  field(label,obj[key],function(text) obj[key]=text invalidate() end,multiline)
 end
 local function numeric(label,obj,key)
  local box
  box=field(label,obj[key],function(text)
   local n=tonumber(text) if not n or n~=n or math.abs(n)==math.huge then box.Text=tostring(obj[key]) error(label.." must be a finite number",0) end
   obj[key]=n invalidate()
  end)
 end
 local function cycle(label,obj,key,options,changed)
  action(label..": "..tostring(obj[key]),function() local index=table.find(options,obj[key]) or 0 obj[key]=options[index%#options+1] if changed then changed() else invalidate() end draw() end)
 end
 local function toggle(label,obj,key,changed)
  action((if obj[key] then "☑ " else "☐ ")..label,function() obj[key]=not obj[key] if changed then changed() else invalidate() end draw() end)
 end
 local function savePresets()
  local json=Http:JSONEncode(presets) assert(#json<=3000000,"Saved presets exceed Studio's local storage budget") plugin:SetSetting("NPCCreatorPro.Presets.v1",json)
 end
 local function saveCurrent(overwrite)
  local errors=Model.Validate(config(),true) assert(#errors==0,table.concat(errors,"\n"))
  assert(#presetName>0 and #presetName<=80,"Preset name must contain 1–80 characters")
  local p={name=presetName,config=Model.Clone(config())}
  local previous=Model.Clone(presets)
  if overwrite then assert(selectedPreset and presets[selectedPreset],"Choose a saved preset") presets[selectedPreset]=p
  else table.insert(presets,p) selectedPreset=#presets end
  local ok,err=pcall(savePresets) if not ok then presets=previous error(err,0) end message("Saved NPC preset in Studio plugin settings.")
 end
 local function loadConfig(c,npc)
  invalidate() mode=c.mode configs[mode]=Model.Clone(c) target=npc page=mode tab="Identity" draw() build(false)
 end
 local function selectedPosition()
  local obj=Selection:Get()[1] assert(obj and obj:IsDescendantOf(workspace),"Select a Workspace part or model")
  if obj:IsA("BasePart") then return obj.Position elseif obj:IsA("Model") then return obj:GetPivot().Position end
  error("Select a Workspace part or model",0)
 end
 draw=function()
  if not alive then return end
  for _,o in ipairs(content:GetChildren()) do o:Destroy() end order=0
  form=ui("ScrollingFrame",content,{Name="Properties",Position=UDim2.fromOffset(10,8),Size=UDim2.new(1,-20,1,-16),BackgroundTransparency=1,BorderSizePixel=0,ScrollBarThickness=5,CanvasSize=UDim2.new(),AutomaticCanvasSize=Enum.AutomaticSize.Y})
  ui("UIListLayout",form,{Padding=UDim.new(0,6),SortOrder=Enum.SortOrder.LayoutOrder})
  local c=config()
  if page=="Custom" or page=="Avatar" then
   line(if mode=="Custom" then "CUSTOM NPC" else "PLAYER AVATAR NPC",32)
   if target and target.Parent then line("Editing: "..target.Name.." • properties apply to this NPC",44)
    action("Detach / create another NPC",function() target=nil draw() end)
   end
   if mode=="Avatar" then
    field("Roblox username",c.username,function(text) c.username=text:match("^%s*(.-)%s*$") c.userId=0 c.appearance=nil invalidate() end)
    action("Search username & load avatar",function() build(true) end)
    line(if c.userId>0 then "@"..c.username.." • UserId "..tostring(c.userId) else "Enter an account username, not a display name.",40)
   end
   cycle("Panel",{value=tab},"value",{"Identity","Appearance","Behavior"},function() tab=if tab=="Identity" then "Appearance" elseif tab=="Appearance" then "Behavior" else "Identity" end)
   if tab=="Identity" then
    textField("NPC model name",c,"name") textField("Display name",c,"displayName") textField("Description",c,"description",true)
    cycle("Rig",c,"rig",{"R15","R6"})
    line("R6 cannot reproduce all R15 bodies or layered clothing. Roblox may adapt or reject incompatible assets.",56)
    numeric("Maximum health",c,"health") numeric("Walking speed",c,"speed") numeric("Jump power",c,"jump") toggle("Show name and health",c,"showName")
   elseif tab=="Appearance" then
    if not c.appearance then line("Load an avatar before editing its appearance.",44) else
     line("Body asset IDs • 0 uses Roblox's default part. Scales affect R15 rigs.",48)
     for _,key in ipairs(Model.Assets) do if not key:find("Animation") then numeric(key.." asset ID",c.appearance.properties,key) end end
     for _,key in ipairs(Model.Scales) do numeric(key,c.appearance.properties,key) end
     for _,key in ipairs(Model.Colors) do
      local color=c.appearance.colors[key]
      field(key.." RGB",string.format("%d, %d, %d",math.round(color[1]),math.round(color[2]),math.round(color[3])),function(value)
       local r,g,b=value:match("^%s*(%d+)%s*,%s*(%d+)%s*,%s*(%d+)%s*$") r,g,b=tonumber(r),tonumber(g),tonumber(b)
       assert(r and g and b and r<=255 and g<=255 and b<=255,"Enter three RGB values from 0 to 255") c.appearance.colors[key]={r,g,b} invalidate()
      end)
     end
     line(tostring(#c.appearance.accessories).." accessories in this appearance",30)
     action("Remove all accessories",function() c.appearance.accessories={} invalidate() draw() end)
    end
   else
    local b=c.behavior toggle("Generate server AI template",b,"enabled") cycle("Movement",b,"motion",Model.Motions) cycle("Disposition",b,"disposition",{"Friendly","Enemy"})
    line("Enemy NPCs chase nearby players and deal server damage. Stationary NPCs remain anchored. Friendly NPCs never attack.",64)
    numeric("Detection range",b,"range") numeric("Stopping / attack distance",b,"stopDistance") numeric("Enemy damage",b,"damage") numeric("Attack interval (seconds)",b,"attackInterval") numeric("Walking distance from spawn",b,"walkDistance")
    numeric("Idle animation asset ID (0 disables)",b,"idleAnimation") numeric("Walk animation asset ID (0 disables)",b,"walkAnimation")
    line("Patrol points (world positions)",30)
    for index,point in ipairs(b.patrol) do
     field("Waypoint "..index,table.concat(point,", "),function(value)
      local values={} for part in value:gmatch("[^,]+") do table.insert(values,tonumber(part) or false) end
      assert(#values==3 and type(values[1])=="number" and type(values[2])=="number" and type(values[3])=="number","Enter X, Y, Z coordinates") b.patrol[index]=values invalidate()
     end)
     action("Remove waypoint "..index,function() table.remove(b.patrol,index) invalidate() draw() end)
    end
    action("Add selected location as patrol point",function() local p=selectedPosition() table.insert(b.patrol,{p.X,p.Y,p.Z}) invalidate() draw() end)
    action("Clear patrol points",function() b.patrol={} invalidate() draw() end)
   end
   line("SAVED PRESET",30)
   field("Preset name",presetName,function(text) presetName=text end)
   action("Save new preset",function() saveCurrent(false) end)
   if target and target.Parent then
    action("Apply properties + behavior to NPC",function() local actual=Manager.Apply(target,c) configs[mode]=actual invalidate() message("Properties and behavior applied. Appearance was not rebuilt.") draw() end)
    line("Replace rig rebuilds all descendants. Use properties above to preserve manual rig edits.",54)
    action("Replace NPC rig with preview",function() assert(ready and preview.model,"Build a current preview first") target=Manager.Replace(target,preview.model,c) message("NPC rig replaced at its original pivot. Undo is available.") draw() end)
   end
  elseif page=="Manager" then
   line("NPC MANAGER",32)
   field("Search NPCs",search,function(text) search=text draw() end)
   action("Refresh NPC list",draw)
   local all=Manager.List() line(tostring(#all).." managed NPCs in Workspace",30)
   for _,npc in ipairs(all) do
    if search=="" or npc.Name:lower():find(search:lower(),1,true) then
     action((if target==npc then "● " else "○ ")..npc.Name,function() target=npc Manager.Select(npc) draw() end)
    end
   end
   if target and target.Parent then
    line("SELECTED: "..target.Name,32)
    action("Select in Explorer",function() Manager.Select(target) end)
    action("Edit properties / appearance / behavior",function() loadConfig(Manager.Read(target),target) end)
    action("Preview selected NPC",function()
     invalidate() local c2=Manager.Read(target) mode=c2.mode configs[mode]=c2
     preview:Set(target:Clone()) ready=true previewInfo.Text=c2.rig.." • "..c2.name previewNote.Text="Existing NPC preview • configuration loaded" message("Previewing selected NPC.")
    end)
    action("Duplicate selected NPC",function() target=Manager.Duplicate(target) message("NPC duplicated.") draw() end)
    action("Save selected NPC preset",function() local c2=Manager.Read(target) mode=c2.mode configs[mode]=c2 presetName=target.Name saveCurrent(false) end)
    action("Delete selected NPC",function() Manager.Delete(target) target=nil message("NPC deleted. Studio Undo can restore it.") draw() end)
   end
  elseif page=="Saved" then
   line("SAVED NPC PRESETS",32) line("Presets are local to this Studio plugin installation. Avatar snapshots retain the loaded appearance.",60)
   for index,p in ipairs(presets) do action((if selectedPreset==index then "● " else "○ ")..p.name,function() selectedPreset=index presetName=p.name draw() end) end
   if selectedPreset and presets[selectedPreset] then
    field("Preset name",presetName,function(text) presetName=text end)
    action("Load saved NPC",function() loadConfig(presets[selectedPreset].config,nil) end)
    action("Rename saved preset",function()
     assert(#presetName>0 and #presetName<=80,"Preset name must contain 1–80 characters") local previous=presets[selectedPreset].name presets[selectedPreset].name=presetName
     local ok,err=pcall(savePresets) if not ok then presets[selectedPreset].name=previous error(err,0) end draw()
    end)
    action("Overwrite with current editor NPC",function() saveCurrent(true) draw() end)
    action("Delete saved preset",function()
     local old=Model.Clone(presets) table.remove(presets,selectedPreset) local ok,err=pcall(savePresets) if not ok then presets=old error(err,0) end selectedPreset=nil draw()
    end)
   end
  else
   line("SETTINGS",32)
   cycle("Spawn location",settings,"spawnMode",{"Camera","Selection"},function() end)
   field("Camera forward distance (0–200 studs)",settings.distance,function(text) local n=tonumber(text) assert(n and n>=0 and n<=200,"Distance must be 0–200") settings.distance=n end)
   field("Managed Workspace folder",settings.folder,function(text) assert(#text>0 and #text<=80 and text:find("%S"),"Enter a folder name of 1–80 characters") settings.folder=text end)
   toggle("Automatically rotate preview",settings,"autoRotate",function() end)
   action("Save settings",function() plugin:SetSetting("NPCCreatorPro.Settings.v1",Http:JSONEncode(settings)) message("Settings saved.") end)
   line("Camera spawning places the rig pivot at the camera position plus its forward distance. Selection spawning aligns the NPC's feet with the top of a selected part/model.",100)
   line("World edits support Studio Undo/Redo. Plugin settings and saved presets use local plugin storage; they are not part of Studio's world undo history.",90)
  end
 end
 for _,entry in ipairs({{"Custom NPC","Custom"},{"Player Avatar NPC","Avatar"},{"NPC Manager","Manager"},{"Saved NPCs","Saved"},{"Settings","Settings"}}) do
  button(sidebar,entry[1],function()
   if entry[2]=="Custom" or entry[2]=="Avatar" then if mode~=entry[2] then invalidate() mode=entry[2] target=nil preview:Clear() previewInfo.Text="NPC preview • "..configs[mode].rig end end
   page=entry[2] draw()
  end,44)
 end
 local pending=false
 local function scheduleRefresh(obj)
  if pending or not alive or page~="Manager" then return end
  if not obj:IsA("Model") and obj.Name~="NPCCreatorConfig" then return end
  pending=true task.delay(.15,function() pending=false if alive and page=="Manager" then draw() end end)
 end
 local added=workspace.DescendantAdded:Connect(scheduleRefresh) local removing=workspace.DescendantRemoving:Connect(scheduleRefresh)
 local undo=game:GetService("ChangeHistoryService").OnUndo:Connect(function() if alive then draw() end end)
 local redo=game:GetService("ChangeHistoryService").OnRedo:Connect(function() if alive then draw() end end)
 draw()
 return function()
  alive=false serial+=1 inputChanged:Disconnect() inputEnded:Disconnect() rotating:Disconnect() added:Disconnect() removing:Disconnect() undo:Disconnect() redo:Disconnect() preview:Destroy() root:Destroy()
 end
end
return Editor
