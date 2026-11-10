local worldCamera=Fixture.New("Camera") local original=Fixture.CFrame(99,50,20) worldCamera.CFrame=original
local chunk=assert(loadstring(PREVIEW_SOURCE))
setfenv(chunk,setmetatable({Instance={new=Fixture.New},Color3=Fixture.Types,Vector3={new=Fixture.Vector},CFrame={new=Fixture.CFrame,lookAt=function(p) return Fixture.CFrame(p) end},workspace={CurrentCamera=worldCamera}},{__index=getfenv()}))
local viewport=Fixture.New("ViewportFrame") viewport.AbsoluteSize=Fixture.Vector(300,500,0)
local p=chunk().New(viewport) local rig=Fixture.Rig() local s=Fixture.New("Script") s.Parent=rig
p:Set(rig) assert(rig.Parent.ClassName=="WorldModel" and rig.HumanoidRootPart.Anchored and s.destroyed)
assert(viewport.CurrentCamera~=worldCamera and worldCamera.CFrame==original)
local position=p.camera.CFrame.Position p:Zoom(-.2) assert(p.camera.CFrame.Position.Z~=position.Z)
p:Rotate(.4) assert(p.camera.CFrame.Position.X~=position.X)
for _=1,100 do p:Zoom(-1) end assert(p.zoom==.4)
viewport.AbsoluteSize=Fixture.Vector(800,200,0) assert(worldCamera.CFrame==original)
local other=Fixture.Rig() p:Set(other) assert(rig.destroyed)
p:Destroy() assert(other.destroyed and p.camera.destroyed and p.world.destroyed and worldCamera.CFrame==original)
print("PASS NPC preview: isolated WorldModel/camera, anchoring, script stripping, fit on resize, rotate, zoom bounds, replacement and cleanup")
