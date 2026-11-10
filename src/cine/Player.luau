-- Client/Studio preview player. Owns and restores every camera and scene resource it changes.
local RunService=game:GetService("RunService")
local Lighting=game:GetService("Lighting")
local Model=require(script.Parent.Model)
local Player={}
local function new(class,parent,props)
 local obj=Instance.new(class) for k,v in pairs(props or {}) do obj[k]=v end obj.Parent=parent return obj
end
local function transform(position,rotation)
 return CFrame.new(position[1],position[2],position[3])*CFrame.Angles(math.rad(rotation[1]),math.rad(rotation[2]),math.rad(rotation[3]))
end
local function findPath(path)
 if path=="" then return nil end
 local current=workspace
 for name in path:gmatch("[^/]+") do
  if name~="Workspace" then current=current and current:FindFirstChild(name) end
 end
 return current
end
local function positionOf(obj)
 if not obj then return nil end
 if obj:IsA("BasePart") then return obj.Position end
 if obj:IsA("Attachment") then return obj.WorldPosition end
 if obj:IsA("Model") then return obj:GetPivot().Position end
 return nil
end
function Player.New(project,overlayParent,preview,onUpdate)
 local errors=Model.Validate({version=1,projects={project}})
 assert(#errors==0,table.concat(errors,"\n"))
 local self={project=Model.Clone(project),time=0,playing=false,disposed=false,preview=preview,actors={},scene=nil}
 local camera=workspace.CurrentCamera assert(camera,"CurrentCamera is unavailable")
 self.camera=camera self.original={cameraType=camera.CameraType,subject=camera.CameraSubject,cframe=camera.CFrame,focus=camera.Focus,fov=camera.FieldOfView}
 self.completed=Instance.new("BindableEvent") self.Completed=self.completed.Event
 self.blur=new("BlurEffect",Lighting,{Name="CineForgePreviewBlur",Size=0})
 self.depth=new("DepthOfFieldEffect",Lighting,{Name="CineForgePreviewDepth",Enabled=true,NearIntensity=0,FarIntensity=0,FocusDistance=20,InFocusRadius=20})
 self.overlay=new("Frame",overlayParent,{Name="CineForgeOverlay",Size=UDim2.fromScale(1,1),BackgroundTransparency=1,BorderSizePixel=0,ZIndex=50,Active=false})
 self.fade=new("Frame",self.overlay,{Size=UDim2.fromScale(1,1),BackgroundColor3=Color3.new(0,0,0),BackgroundTransparency=1,BorderSizePixel=0,ZIndex=51})
 self.top=new("Frame",self.overlay,{Size=UDim2.new(1,0,0.1,0),BackgroundColor3=Color3.new(0,0,0),BorderSizePixel=0,ZIndex=52})
 self.bottom=new("Frame",self.overlay,{Position=UDim2.new(0,0,0.9,0),Size=UDim2.new(1,0,0.1,0),BackgroundColor3=Color3.new(0,0,0),BorderSizePixel=0,ZIndex=52})
 self.subtitle=new("TextLabel",self.overlay,{Position=UDim2.new(0.1,0,0.76,0),Size=UDim2.new(0.8,0,0.12,0),BackgroundTransparency=1,TextColor3=Color3.new(1,1,1),TextStrokeTransparency=0.3,Font=Enum.Font.GothamMedium,TextSize=20,TextWrapped=true,ZIndex=53})
 local function clearActors()
  for _,a in ipairs(self.actors) do
   if a.track then a.track:Stop(0) a.track:Destroy() end
   if a.animation then a.animation:Destroy() end
   if a.createdAnimator then a.createdAnimator:Destroy() end
   if a.clone then a.model:Destroy() elseif a.model and a.model.Parent then a.model:PivotTo(a.original) end
  end
  self.actors={}
 end
 local function sceneChanged(scene)
  clearActors() self.scene=scene
  for _,config in ipairs(scene.characters) do
   local original=findPath(config.path)
   if not original or not original:IsA("Model") then warn("CineForge: character model not found: "..config.path) continue end
   local model=original
   if preview then
    local ok,clone=pcall(function() return original:Clone() end)
    if not ok or not clone then warn("CineForge: could not clone "..config.path) continue end
    model=clone
    local anchor=model:FindFirstChild("HumanoidRootPart") or model.PrimaryPart
    for _,child in ipairs(model:GetDescendants()) do
     if child:IsA("Script") or child:IsA("LocalScript") then child:Destroy()
     elseif child:IsA("BasePart") then child.Anchored=if anchor then child==anchor else true child.CanCollide=false end
    end
    model.Name="CineForgePreview_"..original.Name model.Parent=workspace
   end
   table.insert(self.actors,{model=model,clone=preview,original=model:GetPivot(),config=config})
  end
 end
 function self:Render(time)
  assert(not self.disposed,"Player disposed")
  self.time=math.clamp(time,0,Model.Duration(self.project))
  local scene,localTime=Model.SceneAt(self.project,self.time)
  if self.scene~=scene then sceneChanged(scene) end
  local sampled=Model.Sample(scene.keys,localTime)
  local a,b=sampled.left,sampled.right
  local cf=transform(a.position,a.rotation):Lerp(transform(b.position,b.rotation),sampled.alpha)
  local target=positionOf(findPath(sampled.lookAt))
  if target and (target-cf.Position).Magnitude>0.001 then cf=CFrame.lookAt(cf.Position,target) end
  if sampled.shake>0 then
   local t=self.time*18
   cf=cf*CFrame.new(math.sin(t*1.7)*sampled.shake*0.05,math.sin(t*2.3)*sampled.shake*0.05,0)*CFrame.Angles(0,0,math.sin(t)*sampled.shake*0.005)
  end
  camera.CameraType=Enum.CameraType.Scriptable camera.CFrame=cf camera.FieldOfView=sampled.fov
  self.blur.Size=sampled.blur self.depth.NearIntensity=sampled.depth self.depth.FarIntensity=sampled.depth self.depth.FocusDistance=sampled.focus
  self.fade.BackgroundTransparency=1-sampled.fade self.top.Visible=scene.letterbox self.bottom.Visible=scene.letterbox
  local subtitle=Model.ClipAt(scene.subtitles,localTime) self.subtitle.Text=if subtitle then subtitle.text else ""
  for _,actor in ipairs(self.actors) do
   local left,right,alpha=Model.Movement(actor.config.moves,localTime)
   if left and actor.model.Parent then actor.model:PivotTo(transform(left.position,left.rotation):Lerp(transform(right.position,right.rotation),alpha)) end
   local clip=Model.ClipAt(actor.config.animations,localTime)
   if clip~=actor.clip then
    if actor.track then actor.track:Stop(0) actor.track:Destroy() actor.track=nil end
    if actor.animation then actor.animation:Destroy() actor.animation=nil end
    actor.clip=clip
    if clip then
     local humanoid=actor.model:FindFirstChildOfClass("Humanoid")
     local controller=actor.model:FindFirstChildOfClass("AnimationController")
     local parent=humanoid or controller
     local animator=parent and parent:FindFirstChildOfClass("Animator")
     if not animator and parent then animator=new("Animator",parent,{}) if not actor.clone then actor.createdAnimator=animator end end
     if animator then
      local animation=new("Animation",nil,{AnimationId="rbxassetid://"..clip.asset})
      local ok,track=pcall(function() return animator:LoadAnimation(animation) end)
      if ok then actor.animation=animation actor.track=track track:Play(0) track:AdjustSpeed(0)
      else animation:Destroy() warn("CineForge: animation could not be loaded: "..clip.asset) end
     else warn("CineForge: missing Humanoid or AnimationController in "..actor.config.path) end
    end
   end
   if actor.track and clip then pcall(function() actor.track.TimePosition=math.max(0,localTime-clip.start) end) end
  end
 end
 function self:Pause() self.playing=false end
 function self:Play()
  assert(not self.disposed,"Player disposed")
  if self.time>=Model.Duration(self.project) then self:Render(0) end
  self.playing=true
 end
 function self:Destroy()
  if self.disposed then return end
  self.disposed=true self.playing=false
  if self.connection then self.connection:Disconnect() end
  clearActors() self.overlay:Destroy() self.blur:Destroy() self.depth:Destroy()
  if camera.Parent then camera.CameraType=self.original.cameraType camera.CameraSubject=self.original.subject camera.CFrame=self.original.cframe camera.Focus=self.original.focus camera.FieldOfView=self.original.fov end
  self.completed:Destroy()
 end
 self.connection=RunService.PreRender:Connect(function(dt)
  if not self.playing or self.disposed then return end
  local ok,err=pcall(function()
   self:Render(self.time+dt)
   if onUpdate then onUpdate(self) end
   if self.time>=Model.Duration(self.project) then self.playing=false self.completed:Fire(self.project.id) end
  end)
  if not ok then warn("CineForge playback error: "..tostring(err)) self:Destroy() end
 end)
 local ok,err=pcall(function() self:Render(0) end)
 if not ok then self:Destroy() error(err,0) end
 return self
end
return Player
