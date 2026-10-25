-- Replay the actual hub Heartbeat with recorded outputs and synthetic attacks.
local G=getgenv()
local source=readfile("CloverRPG/main.lua")
local outputs={}
G.CRLF_DefenseOutput=function(packet) table.insert(outputs,packet.Action) end
source=source:gsub('local BlockPacket = [^\n]+','local BlockPacket = {send=getgenv().CRLF_DefenseOutput}',1)
source=source:gsub('connect%(RS.Heartbeat,function%(%)','H.testStep=function()',1)
source=source:gsub('\nend%)\nfunction H.unload','\nend\nfunction H.unload',1)
source=source:gsub('local armed=tool and [^\n]+','local armed=true',1)
source=source:gsub('return "Clover Hub v4 loaded: automation, cursor, resize, unload"',
 'H.testAttack=onAttack H.testPending=function() return pendingBlock end return "test ready"')
assert(loadstring(source,"CloverHub_DefenseReplay"))()
local h=G.CRLF_HubController
G.CRLF_Minigames.paused=false
local me=game.Players.LocalPlayer.Character
local root=assert(me:FindFirstChild("HumanoidRootPart"))
local model=Instance.new("Model")
local part=Instance.new("Part") part.Name="HumanoidRootPart" part.Anchored=true
part.CFrame=root.CFrame*CFrame.new(0,0,-2) part.Parent=model
local hum=Instance.new("Humanoid") hum.Parent=model
local animation=Instance.new("Animation") animation.AnimationId="rbxassetid://125957249913572"
local track={Animation=animation,Length=1.23,Looped=false,Speed=1,TimePosition=0.75,IsPlaying=true,Priority=Enum.AnimationPriority.Action}
local parryReady=false
h.stateManager={Model=me,CanParry=function() return parryReady end,CanBlock=function() return true end}
local catalogRequest=h.catalog.request
local ok,err=xpcall(function()
 h.parry=false h.block=false h.dodge=false
 h.testAttack(model,track) h.testStep()
 assert(#outputs==0,"Disabled defense sent input")
 h.block=true
 h.testAttack(model,track) h.testStep()
 assert(#outputs==1 and outputs[1]=="Block Input","Block-only did not engage")
 local pending=assert(h.testPending())
 assert(pending.plain and h.stats.blocks==1 and h.stats.pulses==0)
 assert(pending.until_>os.clock()+0.15,"Block ended before contact")
 h.testStep()
 assert(#outputs==1,"Repeated block request")
 h.block=false h.testStep()
 assert(outputs[2]=="End Block","Block toggle did not release")
 h.block=true h.parry=true parryReady=true
 h.testAttack(model,track) h.testStep()
 assert(outputs[3]=="Block Input" and not h.testPending().plain,"Parry priority lost")
 assert(h.stats.pulses==1 and h.stats.blocks==1)
 track.IsPlaying=false h.testStep()
 assert(outputs[4]=="End Block","Cancelled swing held block")
 h.parry=false track.IsPlaying=true
 h.testAttack(model,track) h.testStep()
 assert(outputs[5]=="Block Input")
  track.TimePosition=1.2
  h.testStep()
  assert(outputs[6]=="End Block","Contact timeout did not release")
  track.TimePosition=0.75
 h.testAttack(model,track)
 G.CRLF_Minigames.paused=true
 h.testStep()
 assert(#outputs==6,"Defense fired during menu interaction")
 G.CRLF_Minigames.paused=false
 h.testStep()
 assert(outputs[7]=="Block Input","Paused incoming swing was discarded")
 G.CRLF_Minigames.paused=true
 h.testStep()
  assert(outputs[8]=="End Block","Menu interaction did not release assist block")
  G.CRLF_Minigames.paused=false
  part.CFrame=root.CFrame*CFrame.new(0,0,2)
  h.testAttack(model,track) h.testStep()
  assert(#outputs==8,"Plain block incorrectly defended a rear attack")
  h.parry=true parryReady=true
  h.testStep()
  assert(outputs[9]=="Block Input" and not h.testPending().plain,"Facing gate incorrectly disabled parry")
  track.IsPlaying=false h.testStep()
  assert(outputs[10]=="End Block")
  track.IsPlaying=true h.parry=false
  part.CFrame=root.CFrame*CFrame.new(0,0,-2)
  h.testAttack(model,track) h.testStep()
  assert(outputs[11]=="Block Input")
  track.Speed=0 h.testStep()
  assert(outputs[12]=="End Block","Paused attack left block held")
  h.testStep()
  assert(#outputs==12,"Paused attack retriggered defense")
  track.Speed=1 h.testStep()
  assert(outputs[13]=="Block Input","Resumed attack was lost")
  part.CFrame=root.CFrame*CFrame.new(0,0,2)
  h.testStep()
  assert(outputs[14]=="End Block","Guard held after threat left facing arc")
  h.parry=false h.block=false h.testStep()
  h.parry=true
  part.CFrame=root.CFrame*CFrame.new(0,0,-2)
  h.catalog.request=function() end
  animation.AnimationId="rbxassetid://0" track.TimePosition=0.1
  h.testAttack(model,track) h.testStep()
  assert(h.testPending().windup==0.4,"Missing provisional timing")
  h.catalog.records["0"]={hits={0.8,1.2},length=1.3,source="HitWindow"}
  h.testStep()
  assert(h.testPending().windup==0.8 and h.testPending().known,"Loaded markers did not replace provisional timing")
  assert(#outputs==14,"Early defense fired on stale estimate")
  track.TimePosition=0.65 h.testStep()
  assert(outputs[15]=="Block Input","Upgraded timing did not defend")
  track.IsPlaying=false h.testStep()
  assert(outputs[16]=="End Block")
  track.IsPlaying=true track.TimePosition=0.6 animation.AnimationId="rbxassetid://00"
  h.testAttack(model,track)
  h.catalog.records["00"]={hits={0.5,0.9},length=1.3,source="HitWindow"}
  h.testStep()
  assert(h.testPending().windup==0.9,"Late catalog promotion lost later hit or revived past hit")
  assert(#outputs==16,"Past marker triggered late pulse")
  track.TimePosition=0.75 h.testStep()
  assert(outputs[17]=="Block Input","Later marker did not schedule")
end,tostring)
h.catalog.records["0"]=nil h.catalog.records["00"]=nil
h.catalog.request=catalogRequest
h.unload()
model:Destroy() animation:Destroy()
G.CRLF_DefenseOutput=nil
assert(loadstring(readfile("CloverRPG/main.lua"),"CloverHub"))()
assert(ok,err)
return "PASS: defense gates, facing, pause/resume, live catalog promotion, stale estimate rejection, late multi-hit discovery"
