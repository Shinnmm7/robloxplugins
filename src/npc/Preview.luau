local Preview={}
function Preview.New(viewport)
 local self={viewport=viewport,yaw=math.pi,zoom=1,model=nil}
 self.world=Instance.new("WorldModel") self.world.Name="NPCPreviewWorld" self.world.Parent=viewport
 self.camera=Instance.new("Camera") self.camera.FieldOfView=35 self.camera.Parent=viewport viewport.CurrentCamera=self.camera
 viewport.Ambient=Color3.fromRGB(180,180,190) viewport.LightColor=Color3.fromRGB(255,244,230) viewport.LightDirection=Vector3.new(-1,-1,-1)
 function self:Render()
  if not self.model then return end
  local box,size=self.model:GetBoundingBox() local target=box.Position
  local aspect=math.max(.25,self.viewport.AbsoluteSize.X/math.max(1,self.viewport.AbsoluteSize.Y))
  local distance=math.max(size.Y,size.X/aspect,size.Z/aspect)*.65/math.tan(math.rad(self.camera.FieldOfView/2))*self.zoom
  local offset=Vector3.new(math.sin(self.yaw),.12,math.cos(self.yaw))*distance
  self.camera.CFrame=CFrame.lookAt(target+offset,target) self.camera.Focus=CFrame.new(target)
 end
 function self:Clear() if self.model then self.model:Destroy() self.model=nil end end
 function self:Set(model)
  self:Clear() self.model=model
  for _,part in ipairs(model:GetDescendants()) do if part:IsA("BasePart") then part.Anchored=true elseif part:IsA("LuaSourceContainer") then part:Destroy() end end
  model:PivotTo(CFrame.new()) model.Parent=self.world self:Render()
 end
 function self:Rotate(delta) self.yaw+=delta self:Render() end
 function self:Zoom(delta) self.zoom=math.clamp(self.zoom+delta,.4,3) self:Render() end
 function self:Destroy() self:Clear() self.world:Destroy() self.camera:Destroy() end
 self.resize=viewport:GetPropertyChangedSignal("AbsoluteSize"):Connect(function() self:Render() end)
 local destroy=self.Destroy
 function self:Destroy() self.resize:Disconnect() destroy(self) end
 return self
end
return Preview
