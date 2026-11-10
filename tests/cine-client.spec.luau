local function signal()
 local handlers={}
 local event={Connect=function(_,fn) table.insert(handlers,fn) end,Fire=function(_,...) for _,fn in ipairs(table.clone(handlers)) do fn(...) end end}
 return event
end
local function bindable()
 local e=signal() return {Event=e,Fire=function(_,...) e:Fire(...) end}
end
local root={Config="Config",Player="Player",Play=bindable(),Stop=bindable(),Completed=bindable(),PlayForClient={OnClientEvent=signal()}}
function root:SetAttribute(k,v) self[k]=v end
local parent={}
local gui={}
local playerGui={WaitForChild=function() return parent end}
local instances={}
local Player={New=function(project)
 local e=signal() local obj={id=project.id,Completed=e,playing=false,destroyed=false}
 function obj:Play() self.playing=true end
 function obj:Destroy() self.destroyed=true end
 table.insert(instances,obj) return obj
end}
local services={ReplicatedStorage={WaitForChild=function() return root end},Players={LocalPlayer=playerGui}}
local chunk=assert(loadstring(CLIENT_SOURCE))
setfenv(chunk,setmetatable({game={GetService=function(_,n) return services[n] end},require=function(n) return if n=="Config" then Example else Player end,Instance={new=function() return gui end},warn=function() end},{__index=getfenv()}))
chunk()
assert(root.ClientReady==true)
local completed=0 root.Completed.Event:Connect(function(id) assert(id=="village_intro") completed+=1 end)
root.Play:Fire("village_intro") assert(instances[1].playing)
root.PlayForClient.OnClientEvent:Fire("village_intro") assert(instances[1].destroyed and instances[2].playing)
instances[2].Completed:Fire("village_intro") assert(completed==1 and instances[2].destroyed)
root.Play:Fire("village_intro") root.Stop:Fire() assert(instances[3].destroyed)
root.Play:Fire("nonexistent") assert(#instances==3)
print("PASS CineForge client readiness, local/server triggers, completion and stop")
