-- Deliberately small Roblox boundary fake; never used by shipped plugin code.
local F={}
function F.Signal()
 local callbacks={}
 return {Connect=function(_,fn) local c={fn=fn,connected=true} table.insert(callbacks,c) return {Disconnect=function() c.connected=false end} end,
 Fire=function(_,...) for _,c in ipairs(table.clone(callbacks)) do if c.connected then c.fn(...) end end end}
end
local vec={}
vec.__index=function(v,k) if k=="Magnitude" then return math.sqrt(v.X*v.X+v.Y*v.Y+v.Z*v.Z) end return vec[k] end
vec.__add=function(a,b) return F.Vector(a.X+b.X,a.Y+b.Y,a.Z+b.Z) end
vec.__sub=function(a,b) return F.Vector(a.X-b.X,a.Y-b.Y,a.Z-b.Z) end
vec.__mul=function(a,b) if type(a)=="number" then a,b=b,a end return F.Vector(a.X*b,a.Y*b,a.Z*b) end
function F.Vector(x,y,z) return setmetatable({X=x,Y=y,Z=z},vec) end
local cf={}
cf.__index=cf
cf.__add=function(a,b) return F.CFrame(a.Position+b) end
function F.CFrame(x,y,z)
 local p=if type(x)=="table" then x else F.Vector(x or 0,y or 0,z or 0)
 return setmetatable({Position=p,LookVector=F.Vector(0,0,-1)},cf)
end
F.Enum=setmetatable({},{__index=function(t,key) local group=setmetatable({},{__index=function(g,k) rawset(g,k,key.."."..k) return g[k] end}) rawset(t,key,group) return group end})
F.Types={new=function(...) return {...} end,fromOffset=function(...) return {...} end,fromScale=function(...) return {...} end,fromRGB=function(...) return {...} end}
local methods={}
function methods:GetChildren() return table.clone(self._children) end
function methods:GetDescendants() local out={} local function walk(o) for _,c in ipairs(o._children) do table.insert(out,c) walk(c) end end walk(self) return out end
function methods:IsA(kind)
 return self.ClassName==kind or (kind=="BasePart" and self.ClassName=="Part") or (kind=="LuaSourceContainer" and table.find({"Script","LocalScript","ModuleScript"},self.ClassName)~=nil)
end
function methods:SetAttribute(k,v) self._attributes[k]=v end
function methods:GetAttribute(k) return self._attributes[k] end
function methods:GetAttributes() return table.clone(self._attributes) end
function methods:FindFirstChild(name) for _,c in ipairs(self._children) do if c.Name==name then return c end end end
function methods:FindFirstChildOfClass(kind) for _,c in ipairs(self._children) do if c:IsA(kind) then return c end end end
function methods:IsDescendantOf(parent) local p=self.Parent while p do if p==parent then return true end p=p.Parent end return false end
function methods:GetPropertyChangedSignal(key) if not self._signals[key] then self._signals[key]=F.Signal() end return self._signals[key] end
function methods:Destroy() for _,c in ipairs(self:GetChildren()) do c:Destroy() end self.Parent=nil self.destroyed=true end
function methods:Clone()
 local c=F.New(self.ClassName)
 for key,value in pairs(self._data) do if key~="Parent" then c[key]=value end end
 c._attributes=table.clone(self._attributes)
 for _,child in ipairs(self._children) do local copy=child:Clone() copy.Parent=c end return c
end
function methods:GetPivot() return self.Pivot or F.CFrame() end
function methods:PivotTo(value) self.Pivot=value end
function methods:GetBoundingBox() return self:GetPivot()+F.Vector(0,2,0),F.Vector(4,6,2) end
function F.New(kind)
 local o={_data={ClassName=kind,Name=kind,CanvasPosition=F.Vector(0,0,0),AbsolutePosition=F.Vector(0,0,0),AbsoluteSize=F.Vector(400,300,0),Size=F.Vector(4,2,2),Position=F.Vector(0,0,0),CFrame=F.CFrame()},_children={},_attributes={},_signals={}}
 for _,key in ipairs({"Activated","InputBegan","FocusLost","MouseEnter","MouseLeave","AncestryChanged","DescendantAdded","DescendantRemoving"}) do o._data[key]=F.Signal() end
 return setmetatable(o,{__index=function(t,key)
  if methods[key] then return methods[key] end
  local value=t._data[key] if value~=nil then return value end
  for _,child in ipairs(t._children) do if child.Name==key then return child end end
 end,__newindex=function(t,key,value)
  if key:sub(1,1)=="_" then rawset(t,key,value) return end
  if key=="Parent" then
   local old=t._data.Parent if old then local i=table.find(old._children,t) if i then table.remove(old._children,i) end end
   if value then table.insert(value._children,t) end
  end
  t._data[key]=value if t._signals[key] then t._signals[key]:Fire() end
 end})
end
function F.Rig()
 local rig=F.New("Model") rig.Name="Rig"
 local h=F.New("Humanoid") h.Health=100 h.MaxHealth=100 h.WalkSpeed=16 h.JumpPower=50 h.DisplayName="NPC" h.DisplayDistanceType=F.Enum.HumanoidDisplayDistanceType.Viewer h.Parent=rig
 local p=F.New("Part") p.Name="HumanoidRootPart" p.Parent=rig
 return rig
end
return F
