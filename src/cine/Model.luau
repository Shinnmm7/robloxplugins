-- Pure data validation and timeline sampling shared by editor and runtime.
local M = {}
M.Easings = {"Linear", "Smooth", "EaseIn", "EaseOut", "EaseInOut", "Custom"}
function M.Clone(value)
 if type(value)~="table" then return value end
 local result={} for k,v in pairs(value) do result[k]=M.Clone(v) end return result
end
local function num(v,min,max) return type(v)=="number" and v==v and v>=min and v<=max end
local function text(v) return type(v)=="string" and #v<=1000 end
local function id(v) return type(v)=="string" and #v>0 and #v<=100 and v:match("^[%w_%-%.]+$")~=nil end
local function vec(v) return type(v)=="table" and #v==3 and num(v[1],-1e6,1e6) and num(v[2],-1e6,1e6) and num(v[3],-1e6,1e6) end
function M.Key(time)
 return {time=time,position={0,8,20},rotation={0,0,0},fov=70,easing="Smooth",power=2,lookAt="",fade=0,blur=0,depth=0,focus=20,shake=0}
end
function M.Scene(name)
 local a,b=M.Key(0),M.Key(5) b.position={10,8,10}
 return {name=name,duration=5,letterbox=true,keys={a,b},characters={},subtitles={}}
end
function M.Project(id) return {id=id,name="New cutscene",scenes={M.Scene("Scene 1")}} end
function M.Ease(kind,t,power)
 t=math.clamp(t,0,1)
 if kind=="Smooth" then return t*t*(3-2*t) end
 if kind=="EaseIn" then return t*t end
 if kind=="EaseOut" then return 1-(1-t)*(1-t) end
 if kind=="EaseInOut" then return if t<0.5 then 2*t*t else 1-((-2*t+2)^2)/2 end
 if kind=="Custom" then return t^(power or 2) end
 return t
end
function M.Sample(keys,time)
 local first,last,left,right=keys[1],keys[1],nil,nil
 for _,key in ipairs(keys) do
  if key.time<first.time then first=key end
  if key.time>last.time then last=key end
  if key.time<=time and (not left or key.time>left.time) then left=key end
  if key.time>=time and (not right or key.time<right.time) then right=key end
 end
 left=left or first right=right or last
 local t=if right.time==left.time then 0 else M.Ease(left.easing,(time-left.time)/(right.time-left.time),left.power)
 local result={alpha=t,left=left,right=right,lookAt=if t<1 then left.lookAt else right.lookAt}
 for _,field in ipairs({"fov","fade","blur","depth","focus","shake"}) do result[field]=left[field]+(right[field]-left[field])*t end
 return result
end
function M.ClipAt(clips,time)
 for _,clip in ipairs(clips) do if clip.start<=time and time<clip.start+clip.duration then return clip end end
 return nil
end
function M.SceneAt(project,time)
 local start=0
 for _,scene in ipairs(project.scenes) do if time<start+scene.duration then return scene,time-start end start+=scene.duration end
 local scene=project.scenes[#project.scenes] return scene,scene and scene.duration or 0
end
function M.Duration(project) local n=0 for _,s in ipairs(project.scenes) do n+=s.duration end return n end
function M.Validate(config)
 local errors,ids={},{}
 local function check(value,message) if not value then table.insert(errors,message) end return value end
 if not check(type(config)=="table" and config.version==1 and type(config.projects)=="table","Invalid version or projects") then return errors end
 for i,project in ipairs(config.projects) do
  local prefix="Project "..i..": "
  if not check(type(project)=="table",prefix.."invalid project") then continue end
  if not check(id(project.id) and not ids[project.id],prefix.."invalid or duplicate project ID") then else ids[project.id]=true end
  check(text(project.name) and #project.name>0,prefix.."name is required")
  if not check(type(project.scenes)=="table" and #project.scenes>0,prefix.."at least one scene required") then continue end
  for si,scene in ipairs(project.scenes) do
   local sp=prefix.."scene "..si..": "
   if not check(type(scene)=="table",sp.."invalid scene") then continue end
   check(text(scene.name) and #scene.name>0,sp.."name is required")
   local durationOk=check(num(scene.duration,0.01,3600),sp.."duration must be 0.01–3600 seconds")
   check(type(scene.letterbox)=="boolean",sp.."invalid letterbox setting")
   if not check(type(scene.keys)=="table" and #scene.keys>0,sp.."missing camera keyframes") then continue end
   local times={}
   for ki,k in ipairs(scene.keys) do
    local kp=sp.."key "..ki..": "
    if not check(type(k)=="table",kp.."invalid keyframe") then continue end
    if check(durationOk and num(k.time,0,scene.duration),kp.."timestamp outside scene") then
     check(not times[k.time],kp.."conflicting keyframe timestamp") times[k.time]=true
    end
    check(vec(k.position) and vec(k.rotation),kp.."invalid position or rotation")
    check(num(k.fov,1,120),kp.."FOV must be 1–120")
    check(table.find(M.Easings,k.easing)~=nil and num(k.power,0.1,10),kp.."invalid easing or custom power")
    check(text(k.lookAt),kp.."invalid look-at path")
    check(num(k.fade,0,1) and num(k.blur,0,56) and num(k.depth,0,1) and num(k.focus,0,100000) and num(k.shake,0,20),kp.."invalid effects")
   end
   local function clips(list,label,extra)
    if not check(type(list)=="table",sp..label.." list is invalid") then return end
    for ci,clip in ipairs(list) do
     local cp=sp..label.." "..ci..": "
     if not check(type(clip)=="table",cp.."invalid clip") then continue end
     local valid=durationOk and num(clip.start,0,scene.duration) and num(clip.duration,0.01,scene.duration) and clip.start+clip.duration<=scene.duration
     check(valid,cp.."timestamp or duration outside scene") extra(clip,cp)
     if valid then for j=1,ci-1 do local prev=list[j] if type(prev)=="table" and num(prev.start,0,scene.duration) and num(prev.duration,0.01,scene.duration) and clip.start<prev.start+prev.duration and prev.start<clip.start+clip.duration then check(false,cp.."conflicting overlapping clips") end end end
    end
   end
   clips(scene.subtitles,"subtitle",function(c,cp) check(text(c.text) and #c.text>0,cp.."text is required") end)
   if check(type(scene.characters)=="table",sp.."characters must be a list") then
    local paths={}
    for ai,actor in ipairs(scene.characters) do
     local ap=sp.."character "..ai..": "
     if not check(type(actor)=="table" and text(actor.path) and #actor.path>0,ap.."workspace path is required") then continue end
     check(not paths[actor.path],ap.."duplicate character path") paths[actor.path]=true
     clips(actor.animations,"animation",function(c,cp) check(type(c.asset)=="string" and c.asset:match("^%d+$")~=nil and c.asset~="0",cp.."missing or invalid animation asset ID") end)
     if check(type(actor.moves)=="table",ap.."moves must be a list") then
      local seen={}
      for _,m in ipairs(actor.moves) do
       if check(type(m)=="table" and durationOk and num(m.time,0,scene.duration) and vec(m.position) and vec(m.rotation),ap.."invalid movement key") then
        check(not seen[m.time],ap.."conflicting movement timestamp") seen[m.time]=true
       end
      end
     end
    end
   end
  end
 end
 return errors
end
function M.Movement(keys,time)
 if #keys==0 then return nil end
 local first,last,a,b=keys[1],keys[1],nil,nil
 for _,k in ipairs(keys) do
  if k.time<first.time then first=k end if k.time>last.time then last=k end
  if k.time<=time and (not a or k.time>a.time) then a=k end
  if k.time>=time and (not b or k.time<b.time) then b=k end
 end
 a=a or first b=b or last
 return a,b,if a.time==b.time then 0 else math.clamp((time-a.time)/(b.time-a.time),0,1)
end
return M
