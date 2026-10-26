-- Replay the actual hub Heartbeat with recorded outputs and synthetic attacks.
local G=getgenv()
local source=readfile("CloverRPG/main.lua")
local outputs={}
G.CRLF_DefenseOutput=function(packet) table.insert(outputs,packet.Action) end
source=source:gsub('local BlockPacket = [^\n]+','local BlockPacket = {send=getgenv().CRLF_DefenseOutput}',1)
source=source:gsub('connect%(RS.Heartbeat,function%(%)','H.testStep=function()',1)
source=source:gsub('\nend%)\nfunction H.unload','\nend\nfunction H.unload',1)
source=source:gsub('local armed=tool and [^\n]+','local armed=true',1)
-- Isolate the replay from the live session's keyboard, mouse, and chat focus.
source=source:gsub('H.userF=isInputDown%(boundInput%("Block","F"%)%)','H.userF=false',1)
source=source:gsub('then adoptPlayingAttacks%(%) end','then end',1)
source=source:gsub('UIS:GetFocusedTextBox%(%)~=nil','false',1)
source=source:gsub('now<manualUntil','false',1)
source=source:gsub('return "Clover Hub v4 loaded: automation, cursor, resize, unload"',
  'H.testAttack=onAttack H.testAdopt=adoptPlayingAttacks H.testPending=function() return pendingBlock end return "test ready"')
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
local parryReady=true
local cleanupModel=model
h.stateManager={Model=me,CanParry=function() return parryReady end}
local ok,err=xpcall(function()
 h.parry=false
 h.testAttack(model,track) h.testStep()
 assert(#outputs==0,"Disabled parry sent input")
  h.parry=true
  -- Enabling during a swing adopts its current playhead, without a new event.
  local fakeModel={Parent=true}
  local fakeAnimator={GetPlayingAnimationTracks=function() return {track} end}
  fakeModel.FindFirstChild=function() return part end
  fakeModel.FindFirstChildOfClass=function(_,class)
   if class=="Humanoid" then return {Health=100,FindFirstChildOfClass=function() return fakeAnimator end} end
  end
  local watched=h.watched
  h.watched={[fakeModel]=true}
  h.testAdopt()
  h.watched=watched
  assert(h.stats.markerAttacks+h.stats.estimatedAttacks==1,"Active swing was not adopted on enable")
  model=fakeModel
  h.testAttack(model,track) h.testStep()
 assert(#outputs==1 and outputs[1]=="Block Input","Parry did not engage")
 local pending=assert(h.testPending())
 assert(h.stats.pulses==1)
 assert(pending.until_>os.clock()+0.1,"Session ended before grant latency")
 h.testStep()
  assert(#outputs==1,"Repeated parry request")
  h.testAttack(model,track)
  h.testStep()
  assert(h.stats.markerAttacks+h.stats.estimatedAttacks==1,"Duplicate track scheduled twice")
 -- Opening a menu yields: the assist releases its block immediately.
 G.CRLF_Minigames.paused=true h.testStep()
 assert(outputs[2]=="End Block","Menu interaction did not release the assist block")
 assert(h.testPending()==nil,"Paused session stayed pending")
 -- The swing is retained and re-engages after the menu closes.
 track.TimePosition=0.78
 G.CRLF_Minigames.paused=false h.testStep()
 assert(outputs[3]=="Block Input","Retained swing did not re-engage after menu")
 -- A stopped swing must not hold the session.
 track.IsPlaying=false h.testStep()
 assert(outputs[4]=="End Block","Cancelled swing held session")
 assert(h.testPending()==nil,"Released session stayed pending")
 -- Cooldown-gated attacks never send input while CanParry is false.
 track.IsPlaying=true parryReady=false
 track.TimePosition=0.2
 h.testAttack(model,track) h.testStep()
 assert(#outputs==4,"Defense fired while parry was unavailable")
 -- Inside the sendable window: remaining between 0.075s and 0.225s.
 parryReady=true track.TimePosition=0.75 h.testStep()
 assert(outputs[5]=="Block Input","Eligible swing after cooldown was lost")
 -- Submission deadline is not the acknowledgement deadline.
 local session=assert(h.testPending())
 session.at=os.clock()-1 session.until_=os.clock()-0.5
 h.testStep()
 assert(outputs[6]=="End Block","Contact timeout did not release")
 h.testStep()
  assert(#outputs==6,"Idle frames retriggered defense")
end,tostring)
h.unload()
cleanupModel:Destroy() animation:Destroy()
G.CRLF_DefenseOutput=nil
assert(loadstring(readfile("CloverRPG/main.lua"),"CloverHub"))()
assert(ok,err)
return "PASS: parry-only engage, single request, menu yield/resume, stopped swing, cooldown gate, timeout, idle quiet"
