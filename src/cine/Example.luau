local function key(t,x,y,z,fov,fade,blur,depth,subtitle)
 return {time=t,position={x,y,z},rotation={-10,0,0},fov=fov,easing="Smooth",power=2,lookAt="",fade=fade,blur=blur,depth=depth,focus=25,shake=0}
end
return {version=1,projects={{id="village_intro",name="Village introduction",scenes={{name="Arrival",duration=6,letterbox=true,
 keys={key(0,0,12,30,70,1,12,0.2),key(1,0,12,30,70,0,0,0.2),key(5,15,10,14,55,0,0,0.2),key(6,15,10,14,55,1,0,0.2)},
 characters={},subtitles={{start=1,duration=3,text="A new adventure begins."}}}}}}}
