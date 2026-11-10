local function signal()
 local handlers={}
 return {Connect=function(_,fn) table.insert(handlers,fn) return {Disconnect=function() end} end,Fire=function(_,...) for _,fn in ipairs(table.clone(handlers)) do fn(...) end end}
end
local function harness()
 local function new(class)
  local obj={ClassName=class,children={},Activated=signal(),InputBegan=signal(),FocusLost=signal(),CanvasPosition={X=0,Y=0},AbsolutePosition={X=0,Y=0}}
  function obj:GetChildren() return table.clone(self.children) end
  function obj:GetPropertyChangedSignal() return signal() end
  function obj:IsA(kind) return self.ClassName==kind or (kind=="GuiObject" and table.find({"Frame","ScrollingFrame","TextLabel","TextButton","TextBox"},self.ClassName)~=nil) end
  function obj:Destroy() if self.Parent then local i=table.find(self.Parent.children,self) if i then table.remove(self.Parent.children,i) end end self.Parent=nil end
  return setmetatable(obj,{__newindex=function(t,k,v) rawset(t,k,v) if k=="Parent" and v then table.insert(v.children,t) end end})
 end
 local widget,settings,encoded,serial,generated=new("Frame"),{},{},0,nil
 local plugin={SetSetting=function(_,k,v) settings[k]=v end,GetSetting=function(_,k) return settings[k] end}
 local http={JSONEncode=function(_,v) serial+=1 local key="json"..serial encoded[key]=Model.Clone(v) return key end,JSONDecode=function(_,v) return Model.Clone(assert(encoded[v])) end}
 local input={InputChanged=signal(),InputEnded=signal()} local run={PreRender=signal(),IsRunning=function() return false end}
 local generator={Generate=function(c) generated=Model.Clone(c) return "Generated" end,Export=function() return "Exported" end,Import=function() return Model.Clone(Example) end}
 local active,destroyed=0,0
 local player={New=function(project)
  active+=1
  return {time=0,project=Model.Clone(project),disposed=false,playing=false,Render=function(self,t) self.time=t end,
   Play=function(self) self.playing=true end,Pause=function(self) self.playing=false end,
   Destroy=function(self) self.disposed=true destroyed+=1 end}
 end}
 local services={HttpService=http,RunService=run,UserInputService=input}
 local enum=setmetatable({},{__index=function(_,key) return setmetatable({},{__index=function(_,value) return key.."."..value end}) end})
 local types={new=function(...) return {...} end,fromOffset=function(...) return {...} end,fromScale=function(...) return {...} end,fromRGB=function(...) return {...} end}
 local chunk=assert(loadstring(EDITOR_SOURCE))
 setfenv(chunk,setmetatable({game={GetService=function(_,name) return assert(services[name],name) end},script={Parent={Model="Model",Example="Example",Player="Player",Generator="Generator"}},
  require=function(name) return ({Model=Model,Example=Example,Player=player,Generator=generator})[name] end,
  Instance={new=new},Color3=types,UDim=types,UDim2=types,Vector2=types,Enum=enum,workspace={},task={defer=function(fn) fn() end}},{__index=getfenv()}))
 local cleanup=chunk().Mount(plugin,widget)
 local function descendants(o,out) for _,c in ipairs(o.children) do table.insert(out,c) descendants(c,out) end return out end
 local function find(class,text) for _,o in ipairs(descendants(widget,{})) do if o.ClassName==class and o.Text==text then return o end end error("Missing "..class.." "..text) end
 local function click(text) find("TextButton",text).Activated:Fire() end
 local function edit(title,value)
  local heading=find("TextLabel",title)
  for _,o in ipairs(heading.Parent.children) do if o.ClassName=="TextBox" and o.LayoutOrder==heading.LayoutOrder+1 then o.Text=value o.FocusLost:Fire() return end end error("Missing input: "..title)
 end
 return {click=click,edit=edit,get=function() return generated end,cleanup=cleanup,active=function() return active end,destroyed=function() return destroyed end}
end
local h=harness()
h.click("+ Cutscene")
h.click("○ Project") h.edit("Project name","Opening scene") h.edit("Unique project ID","opening")
h.click("+ Scene") h.edit("Scene name","Second scene")
h.click("○ Camera") h.click("+ Keyframe at playhead") h.edit("Timestamp (seconds)","2") h.edit("Position X","12")
h.click("○ Effects") h.edit("Blur (0–56)","6")
h.click("○ Subtitles") h.click("+ Subtitle at playhead") h.edit("Text","A new day")
h.click("○ Characters") h.click("+ Character") h.edit("Workspace model path (slash-separated)","NPCs/Guide") h.click("+ Movement key at playhead") h.edit("Position X","25") h.click("+ Animation at playhead") h.edit("Animation asset ID (digits)","12345")
h.click("Save draft") h.click("Generate")
local config=h.get() assert(#config.projects==2) local p=config.projects[2] assert(p.id=="opening" and p.name=="Opening scene" and #p.scenes==2)
local s=p.scenes[2] assert(s.name=="Second scene" and #s.keys==3 and s.keys[3].time==2 and s.keys[3].position[1]==12 and s.keys[3].blur==6)
assert(s.subtitles[1].text=="A new day" and s.characters[1].path=="NPCs/Guide" and s.characters[1].moves[1].position[1]==25 and s.characters[1].animations[1].asset=="12345")
h.click("Preview / reset") assert(h.active()==1) h.click("Play") h.click("Pause") h.click("Stop / restore") assert(h.destroyed()==1)
h.click("Load draft") h.click("Export JSON") h.click("Import selection") h.click("Example") h.click("Zoom +") h.click("Zoom −") h.click("Validate") h.cleanup()
print("PASS CineForge editor interactions: projects, scenes, tracks, keyframes, effects, preview, save, load, import and export")
