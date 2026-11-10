local Http=game:GetService("HttpService")
local Run=game:GetService("RunService")
local Input=game:GetService("UserInputService")
local Model=require(script.Parent.Model)
local Player=require(script.Parent.Player)
local Example=require(script.Parent.Example)
local Generator=require(script.Parent.Generator)
local E={}
local C={bg=Color3.fromRGB(17,20,29),panel=Color3.fromRGB(27,32,44),field=Color3.fromRGB(42,48,63),text=Color3.fromRGB(235,239,248),muted=Color3.fromRGB(165,175,195),accent=Color3.fromRGB(110,91,232),highlight=Color3.fromRGB(95,218,184)}
local function make(class,parent,props) local o=Instance.new(class) for k,v in pairs(props or {}) do o[k]=v end o.Parent=parent return o end
local function label(parent,value,height)
 return make("TextLabel",parent,{Text=value,Size=UDim2.new(1,-8,0,height or 24),TextWrapped=true,TextXAlignment=Enum.TextXAlignment.Left,BackgroundTransparency=1,TextColor3=C.text,Font=Enum.Font.Gotham,TextSize=12,LayoutOrder=#parent:GetChildren()})
end
local function button(parent,value,callback)
 local b=make("TextButton",parent,{Text=value,Size=UDim2.new(1,-8,0,30),BackgroundColor3=C.field,TextColor3=C.text,Font=Enum.Font.GothamMedium,TextSize=12,BorderSizePixel=0,TextWrapped=true,LayoutOrder=#parent:GetChildren()})
 make("UICorner",b,{CornerRadius=UDim.new(0,5)}) b.Activated:Connect(callback) return b
end
local function clear(parent) for _,child in ipairs(parent:GetChildren()) do if child:IsA("GuiObject") then child:Destroy() end end end
local function list(parent) make("UIListLayout",parent,{Padding=UDim.new(0,5),SortOrder=Enum.SortOrder.LayoutOrder}) end
local function scroll(parent,pos,size)
 local f=make("ScrollingFrame",parent,{Position=pos,Size=size,BackgroundColor3=C.panel,BorderSizePixel=0,ScrollBarThickness=5,AutomaticCanvasSize=Enum.AutomaticSize.Y,CanvasSize=UDim2.new()}) list(f) return f
end
function E.Mount(pluginObject,widget)
 local config=Model.Clone(Example)
 local projectIndex,sceneIndex,keyIndex=1,1,1
 local zoom=80 local time=0 local tab="Camera" local playback=nil local keyDrag=nil local connections={}
 local draw,drawTimeline,inspector,browser,refreshPreview
 local timelineTitle,timelinePlayhead
 local scrubbing=false
 local root=make("Frame",widget,{Size=UDim2.fromScale(1,1),BackgroundColor3=C.bg,BorderSizePixel=0})
 local toolbar=make("Frame",root,{Position=UDim2.fromOffset(8,8),Size=UDim2.new(1,-16,0,66),BackgroundTransparency=1})
 make("UIGridLayout",toolbar,{CellSize=UDim2.new(0.125,-4,0,29),CellPadding=UDim2.fromOffset(4,4),SortOrder=Enum.SortOrder.LayoutOrder})
 local projects=scroll(root,UDim2.new(0,8,0,80),UDim2.new(0.18,-12,1,-145))
 local timeline=make("ScrollingFrame",root,{Position=UDim2.new(0.18,0,0,80),Size=UDim2.new(0.49,-8,0,180),BackgroundColor3=C.panel,BorderSizePixel=0,ScrollBarThickness=7,ScrollingDirection=Enum.ScrollingDirection.X,CanvasSize=UDim2.fromOffset(600,0)})
 local monitor=make("Frame",root,{Position=UDim2.new(0.18,0,0,270),Size=UDim2.new(0.49,-8,1,-335),BackgroundColor3=Color3.fromRGB(8,10,15),BorderSizePixel=0,ClipsDescendants=true})
 local monitorLabel=label(monitor,"PREVIEW MONITOR\n\nThe Studio viewport shows the animated camera.\nThis panel previews fades, subtitles and letterbox bars.",100) monitorLabel.Position=UDim2.fromOffset(12,16) monitorLabel.Size=UDim2.new(1,-24,0,100) monitorLabel.TextColor3=C.muted
 local panel=scroll(root,UDim2.new(0.67,0,0,80),UDim2.new(0.33,-8,1,-145))
 local validation=scroll(monitor,UDim2.fromScale(0,0),UDim2.fromScale(1,1)) validation.Visible=false validation.ZIndex=20
 local status=label(root,"CINEFORGE PRO • Select a scene and keyframe.",48) status.Position=UDim2.new(0,8,1,-56) status.Size=UDim2.new(1,-16,0,48)
 local function notice(value) status.Text=tostring(value) end
 local function protect(f) local ok,result=pcall(f) notice(if ok then result or "Done" else result) end
 local function project() return config.projects[projectIndex] end
 local function scene() local p=project() return p and p.scenes[sceneIndex] end
 local function key() local s=scene() return s and s.keys[keyIndex] end
 local function sceneOffset() local n=0 for i=1,sceneIndex-1 do n+=project().scenes[i].duration end return n end
 local function stop()
  if playback then playback:Destroy() playback=nil end
 end
 local function unique()
  local ids={} for _,p in ipairs(config.projects) do ids[p.id]=true end local i=1 while ids["cutscene_"..i] do i+=1 end return "cutscene_"..i
 end
 local function number(parent,title,object,field)
  label(parent,title)
  local box=make("TextBox",parent,{Text=tostring(object[field]),Size=UDim2.new(1,-8,0,29),BackgroundColor3=C.field,TextColor3=C.text,Font=Enum.Font.Code,TextSize=12,ClearTextOnFocus=false,LayoutOrder=#parent:GetChildren()})
  box.FocusLost:Connect(function() local n=tonumber(box.Text) if n and n==n and math.abs(n)<=1e6 then object[field]=n stop() drawTimeline() else notice("Invalid number") box.Text=tostring(object[field]) end end)
 end
 local function edit(parent,title,object,field,multiline)
  label(parent,title)
  local box=make("TextBox",parent,{Text=tostring(object[field] or ""),Size=UDim2.new(1,-8,0,if multiline then 70 else 29),BackgroundColor3=C.field,TextColor3=C.text,Font=Enum.Font.Code,TextSize=12,TextWrapped=true,MultiLine=multiline==true,ClearTextOnFocus=false,LayoutOrder=#parent:GetChildren()})
  box.FocusLost:Connect(function() object[field]=box.Text stop() browser() drawTimeline() end)
 end
 local function vector(parent,title,values)
  for i,axis in ipairs({"X","Y","Z"}) do number(parent,title.." "..axis,values,i) end
 end
 local function switch(parent,title,object,field,options)
  button(parent,title..": "..tostring(object[field]).." ▸",function() local i=table.find(options,object[field]) or 0 object[field]=options[i%#options+1] stop() inspector() drawTimeline() end)
 end
 browser=function()
  clear(projects) label(projects,"PROJECTS")
  button(projects,"+ Cutscene",function() stop() table.insert(config.projects,Model.Project(unique())) projectIndex=#config.projects sceneIndex=1 keyIndex=1 time=0 draw() end)
  for i,p in ipairs(config.projects) do
   local b=button(projects,p.name.."\n"..p.id,function() stop() projectIndex=i sceneIndex=1 keyIndex=1 time=0 draw() end) b.Size=UDim2.new(1,-8,0,48)
   if i==projectIndex then b.BackgroundColor3=C.accent end
  end
  local p=project() if not p then return end label(projects,"SCENES")
  for i,s in ipairs(p.scenes) do
   local b=button(projects,i.." • "..s.name,function() stop() sceneIndex=i keyIndex=1 time=0 draw() end)
   if i==sceneIndex then b.BackgroundColor3=C.accent end
  end
  button(projects,"+ Scene",function() stop() table.insert(p.scenes,Model.Scene("Scene "..(#p.scenes+1))) sceneIndex=#p.scenes keyIndex=1 time=0 draw() end)
 end
 local function scrub(x)
  local s=scene() if not s then return end
  time=math.clamp((x-timeline.AbsolutePosition.X+timeline.CanvasPosition.X-20)/zoom,0,s.duration)
  if playback then protect(function() playback:Render(sceneOffset()+time) end) end
  drawTimeline()
 end
 drawTimeline=function()
  clear(timeline) local s=scene() if not s then return end
  timeline.CanvasSize=UDim2.fromOffset(math.max(600,s.duration*zoom+50),0)
  local ruler=make("TextButton",timeline,{Position=UDim2.fromOffset(20,35),Size=UDim2.fromOffset(math.max(1,s.duration*zoom),36),Text="",BackgroundColor3=C.field,BorderSizePixel=0})
  ruler.InputBegan:Connect(function(input) if input.UserInputType==Enum.UserInputType.MouseButton1 then scrubbing=true scrub(input.Position.X) end end)
  timelineTitle=label(timeline,string.format("TIMELINE • %.2f / %.2fs    •    %d px/sec",time,s.duration,zoom),25) timelineTitle.Position=UDim2.fromOffset(20,0)
  local step=math.max(1,math.ceil(s.duration/12))
  for n=0,math.floor(s.duration/step) do local tick=label(timeline,tostring(n*step).."s",20) tick.Position=UDim2.fromOffset(20+n*step*zoom,72) tick.Size=UDim2.fromOffset(48,20) end
  timelinePlayhead=make("Frame",timeline,{Position=UDim2.fromOffset(20+time*zoom,26),Size=UDim2.fromOffset(2,120),BackgroundColor3=C.highlight,BorderSizePixel=0,ZIndex=3})
  local subtitleLabel=label(timeline,"SUB",18) subtitleLabel.Position=UDim2.fromOffset(0,133) subtitleLabel.Size=UDim2.fromOffset(20,18)
  local actorLabel=label(timeline,"ACT",18) actorLabel.Position=UDim2.fromOffset(0,151) actorLabel.Size=UDim2.fromOffset(20,18)
  for _,clip in ipairs(s.subtitles) do
   make("Frame",timeline,{Position=UDim2.fromOffset(20+clip.start*zoom,136),Size=UDim2.fromOffset(math.max(2,clip.duration*zoom),10),BackgroundColor3=C.highlight,BorderSizePixel=0})
  end
  for _,actor in ipairs(s.characters) do
   for _,clip in ipairs(actor.animations) do
    make("Frame",timeline,{Position=UDim2.fromOffset(20+clip.start*zoom,154),Size=UDim2.fromOffset(math.max(2,clip.duration*zoom),10),BackgroundColor3=C.accent,BorderSizePixel=0})
   end
   for _,move in ipairs(actor.moves) do
    make("Frame",timeline,{Position=UDim2.fromOffset(20+move.time*zoom,151),Size=UDim2.fromOffset(3,16),BackgroundColor3=C.text,BorderSizePixel=0})
   end
  end
  for i,k in ipairs(s.keys) do
   local b=button(timeline,"◆",function() keyIndex=i time=k.time if playback then playback:Render(sceneOffset()+time) end inspector() drawTimeline() end)
   b.Position=UDim2.fromOffset(12+k.time*zoom,100) b.Size=UDim2.fromOffset(18,28) b.TextSize=18 b.BackgroundColor3=if i==keyIndex then C.accent else C.field b.ZIndex=4
   b.InputBegan:Connect(function(input) if input.UserInputType==Enum.UserInputType.MouseButton1 then keyDrag={key=k,index=i,startX=input.Position.X,startTime=k.time,button=b,moved=false} end end)
  end
 end
 local function updateTime(current)
  local active,localTime=Model.SceneAt(current.project,current.time)
  for i,s in ipairs(current.project.scenes) do
   if s==active then if sceneIndex~=i then sceneIndex=i browser() inspector() drawTimeline() end break end
  end
  time=localTime
  if timelineTitle and timelinePlayhead then
   timelineTitle.Text=string.format("TIMELINE • %.2f / %.2fs    •    %d px/sec",time,active.duration,zoom)
   timelinePlayhead.Position=UDim2.fromOffset(20+time*zoom,26)
  end
 end
 local function maybePreview()
  if playback then playback:Destroy() playback=nil end
  local p=project() assert(p,"Create a project first")
  local errors=Model.Validate({version=1,projects={p}}) assert(#errors==0,table.concat(errors," • "))
  assert(not Run:IsRunning(),"Stop the play test before Studio preview")
  validation.Visible=false
  playback=Player.New(p,monitor,true,updateTime)
  playback:Render(sceneOffset()+time)
 end
 refreshPreview=function() protect(function() maybePreview() return "Preview ready; Studio camera will be restored on Stop." end) end
 inspector=function()
  clear(panel) local p,s,k=project(),scene(),key()
  if not p or not s then label(panel,"Create a project and scene.",40) return end
  for _,name in ipairs({"Camera","Effects","Characters","Subtitles","Project"}) do button(panel,(if tab==name then "● " else "○ ")..name,function() tab=name inspector() end) end
  if tab=="Project" then
   label(panel,"PROJECT & SCENE") edit(panel,"Project name",p,"name") edit(panel,"Unique project ID",p,"id")
   button(panel,"Duplicate project",function() stop() local copy=Model.Clone(p) copy.id=unique() copy.name..=" copy" table.insert(config.projects,copy) projectIndex=#config.projects sceneIndex=1 keyIndex=1 time=0 draw() end)
   button(panel,"Delete project",function() stop() table.remove(config.projects,projectIndex) projectIndex=math.max(1,math.min(projectIndex,#config.projects)) sceneIndex=1 keyIndex=1 time=0 draw() end)
   edit(panel,"Scene name",s,"name") number(panel,"Scene duration (seconds)",s,"duration")
   switch(panel,"Letterbox",s,"letterbox",{true,false})
   button(panel,"Duplicate scene",function() stop() table.insert(p.scenes,sceneIndex+1,Model.Clone(s)) sceneIndex+=1 keyIndex=1 time=0 draw() end)
   button(panel,"Move scene earlier",function() if sceneIndex>1 then stop() p.scenes[sceneIndex],p.scenes[sceneIndex-1]=p.scenes[sceneIndex-1],p.scenes[sceneIndex] sceneIndex-=1 draw() end end)
   button(panel,"Move scene later",function() if sceneIndex<#p.scenes then stop() p.scenes[sceneIndex],p.scenes[sceneIndex+1]=p.scenes[sceneIndex+1],p.scenes[sceneIndex] sceneIndex+=1 draw() end end)
   button(panel,"Delete scene",function() if #p.scenes<=1 then notice("Keep at least one scene") return end stop() table.remove(p.scenes,sceneIndex) sceneIndex=math.min(sceneIndex,#p.scenes) keyIndex=1 time=0 draw() end)
  elseif tab=="Camera" then
   label(panel,"CAMERA KEYFRAMES")
   button(panel,"+ Keyframe at playhead",function() stop() local new=if k then Model.Clone(k) else Model.Key(time) new.time=time table.insert(s.keys,new) keyIndex=#s.keys inspector() drawTimeline() end)
   if not k then return end
   label(panel,"KEYFRAME "..keyIndex)
   number(panel,"Timestamp (seconds)",k,"time")
   button(panel,"Capture Studio camera",function()
    stop() local camera=workspace.CurrentCamera assert(camera,"Camera unavailable") local r1,r2,r3=camera.CFrame:ToEulerAnglesXYZ()
    k.position={camera.CFrame.Position.X,camera.CFrame.Position.Y,camera.CFrame.Position.Z}
    k.rotation={math.deg(r1),math.deg(r2),math.deg(r3)} k.fov=camera.FieldOfView inspector() notice("Captured camera position, rotation, and FOV.")
   end)
   vector(panel,"Position",k.position) vector(panel,"Rotation (degrees)",k.rotation) number(panel,"Field of view",k,"fov")
   switch(panel,"Transition to next key",k,"easing",Model.Easings) number(panel,"Custom easing power",k,"power") edit(panel,"Look-at workspace path (optional)",k,"lookAt")
   button(panel,"Delete keyframe",function() stop() table.remove(s.keys,keyIndex) keyIndex=math.max(1,math.min(keyIndex,#s.keys)) inspector() drawTimeline() end)
  elseif tab=="Effects" then
   if not k then label(panel,"Add a keyframe first") return end
   label(panel,"EFFECTS AT KEYFRAME "..keyIndex)
   number(panel,"Fade to black (0–1)",k,"fade") number(panel,"Blur (0–56)",k,"blur") number(panel,"Depth intensity (0–1)",k,"depth") number(panel,"Focus distance",k,"focus") number(panel,"Shake intensity (0–20)",k,"shake")
  elseif tab=="Subtitles" then
   label(panel,"SUBTITLE TRACK")
   button(panel,"+ Subtitle at playhead",function() table.insert(s.subtitles,{start=time,duration=1,text="New subtitle"}) stop() inspector() end)
   for i,clip in ipairs(s.subtitles) do
    label(panel,"SUBTITLE "..i) number(panel,"Start",clip,"start") number(panel,"Duration",clip,"duration") edit(panel,"Text",clip,"text",true)
    button(panel,"Remove subtitle "..i,function() table.remove(s.subtitles,i) stop() inspector() end)
   end
  elseif tab=="Characters" then
   label(panel,"CHARACTER TRACKS")
   button(panel,"+ Character",function() table.insert(s.characters,{path="Character",moves={},animations={}}) stop() inspector() end)
   for i,actor in ipairs(s.characters) do
    label(panel,"CHARACTER "..i) edit(panel,"Workspace model path (slash-separated)",actor,"path")
    button(panel,"Capture selected model as path",function()
     local obj=game:GetService("Selection"):Get()[1] if not obj or not obj:IsA("Model") or not obj:IsDescendantOf(workspace) then notice("Select a model in Workspace") return end
     local names={} while obj and obj~=workspace do table.insert(names,1,obj.Name) obj=obj.Parent end actor.path=table.concat(names,"/") stop() inspector()
    end)
    button(panel,"+ Movement key at playhead",function() table.insert(actor.moves,{time=time,position={0,0,0},rotation={0,0,0}}) stop() inspector() end)
    for j,move in ipairs(actor.moves) do
     label(panel,"MOVEMENT "..j) number(panel,"Time",move,"time") vector(panel,"Position",move.position) vector(panel,"Rotation",move.rotation)
     button(panel,"Capture selected model transform",function()
      local obj=game:GetService("Selection"):Get()[1] if not obj or not obj:IsA("Model") then notice("Select a model") return end
      local cf=obj:GetPivot() local x,y,z=cf:ToEulerAnglesXYZ() move.position={cf.Position.X,cf.Position.Y,cf.Position.Z} move.rotation={math.deg(x),math.deg(y),math.deg(z)} stop() inspector()
     end)
     button(panel,"Remove movement "..j,function() table.remove(actor.moves,j) stop() inspector() end)
    end
    button(panel,"+ Animation at playhead",function() table.insert(actor.animations,{start=time,duration=1,asset=""}) stop() inspector() end)
    for j,clip in ipairs(actor.animations) do
     label(panel,"ANIMATION "..j) number(panel,"Start",clip,"start") number(panel,"Duration",clip,"duration") edit(panel,"Animation asset ID (digits)",clip,"asset")
     button(panel,"Remove animation "..j,function() table.remove(actor.animations,j) stop() inspector() end)
    end
    button(panel,"Remove character "..i,function() table.remove(s.characters,i) stop() inspector() end)
   end
  end
 end
 draw=function() browser() inspector() drawTimeline() end
 button(toolbar,"Save draft",function() protect(function() pluginObject:SetSetting("CineForgePro.v1",Http:JSONEncode(config)) return "Saved local draft" end) end)
 button(toolbar,"Load draft",function() protect(function() local json=pluginObject:GetSetting("CineForgePro.v1") assert(type(json)=="string","No saved draft") local loaded=Http:JSONDecode(json) assert(type(loaded)=="table" and loaded.version==1 and type(loaded.projects)=="table","Invalid draft") stop() config=loaded projectIndex=1 sceneIndex=1 keyIndex=1 time=0 draw() return "Draft loaded" end) end)
 button(toolbar,"Export JSON",function() protect(function() return Generator.Export(config) end) end)
 button(toolbar,"Import selection",function() protect(function() local loaded=Generator.Import() stop() config=loaded projectIndex=1 sceneIndex=1 keyIndex=1 time=0 draw() return "Imported configuration" end) end)
 button(toolbar,"Generate",function() protect(function() stop() return Generator.Generate(config) end) end)
 button(toolbar,"Validate",function()
  stop() clear(validation) validation.Visible=true
  local errors=Model.Validate(config)
  label(validation,"VALIDATION • "..#errors.." errors",32)
  if #errors==0 then label(validation,"All configuration checks passed.",32) end
  for _,err in ipairs(errors) do label(validation,err,52) end
  notice("Validation: "..#errors.." errors. See the validation panel.")
 end)
 button(toolbar,"Check assets",function()
  stop() clear(validation) validation.Visible=true label(validation,"ANIMATION ASSET CHECK",32)
  local seen={} local count=0
  for _,p in ipairs(config.projects) do for _,s in ipairs(p.scenes) do for _,actor in ipairs(s.characters) do for _,clip in ipairs(actor.animations) do
   if not seen[clip.asset] then
    seen[clip.asset]=true count+=1
    if type(clip.asset)~="string" or not clip.asset:match("^%d+$") then label(validation,"Invalid animation ID: "..tostring(clip.asset),50)
    else
     local ok,info=pcall(function() return game:GetService("MarketplaceService"):GetProductInfoAsync(tonumber(clip.asset),Enum.InfoType.Asset) end)
     if not ok then label(validation,"Unable to verify "..clip.asset.." (missing, private, or service unavailable).",55)
     elseif info.AssetTypeId~=Enum.AssetType.Animation.Value then label(validation,clip.asset.." is not an animation asset.",45)
     else label(validation,clip.asset.." • "..tostring(info.Name).." • Animation",45) end
    end
   end
  end end end end
  if count==0 then label(validation,"No animation assets configured.",32) end
  notice("Checked "..count.." animation IDs. Playback permissions must also be tested in Studio.")
 end)
 button(toolbar,"Zoom +",function() zoom=math.min(400,zoom+20) drawTimeline() end)
 button(toolbar,"Zoom −",function() zoom=math.max(20,zoom-20) drawTimeline() end)
 button(toolbar,"Preview / reset",function() refreshPreview() end)
 button(toolbar,"Play",function() protect(function() if not playback then maybePreview() end playback:Play() return "Preview playing" end) end)
 button(toolbar,"Pause",function() if playback then playback:Pause() notice("Preview paused") end end)
 button(toolbar,"Stop / restore",function() stop() time=0 drawTimeline() notice("Preview stopped and camera restored.") end)
 button(toolbar,"Example",function() stop() local copy=Model.Clone(Example.projects[1]) copy.id=unique() table.insert(config.projects,copy) projectIndex=#config.projects sceneIndex=1 keyIndex=1 time=0 draw() end)
 table.insert(connections,Input.InputChanged:Connect(function(input)
  if scrubbing and input.UserInputType==Enum.UserInputType.MouseMovement then scrub(input.Position.X) return end
  if keyDrag and input.UserInputType==Enum.UserInputType.MouseMovement then
   local delta=input.Position.X-keyDrag.startX
   if math.abs(delta)>3 then keyDrag.moved=true end
   if keyDrag.moved then keyDrag.key.time=math.clamp(keyDrag.startTime+delta/zoom,0,scene().duration) keyDrag.button.Position=UDim2.fromOffset(12+keyDrag.key.time*zoom,100) end
  end
 end))
 table.insert(connections,Input.InputEnded:Connect(function(input)
  if input.UserInputType==Enum.UserInputType.MouseButton1 then scrubbing=false end
  if keyDrag and input.UserInputType==Enum.UserInputType.MouseButton1 then
   local drag=keyDrag keyDrag=nil
   if drag.moved then stop() keyIndex=drag.index time=drag.key.time task.defer(function() inspector() drawTimeline() end) end
  end
 end))
 table.insert(connections,widget:GetPropertyChangedSignal("Enabled"):Connect(function() if not widget.Enabled then stop() end end))
 local ok,saved=pcall(function() return pluginObject:GetSetting("CineForgePro.v1") end)
 if ok and type(saved)=="string" then local good,value=pcall(Http.JSONDecode,Http,saved) if good and type(value)=="table" and value.version==1 and type(value.projects)=="table" then config=value end end
 draw()
 return function() stop() pcall(function() pluginObject:SetSetting("CineForgePro.v1",Http:JSONEncode(config)) end) for _,c in ipairs(connections) do c:Disconnect() end root:Destroy() end
end
return E
