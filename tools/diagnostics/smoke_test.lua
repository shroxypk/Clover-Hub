-- Read-only Veyra smoke test: no inputs, remotes, or game-state changes.
local player=game:GetService("Players").LocalPlayer
local HttpService=game:GetService("HttpService")
local G=getgenv()
local hub,mg,parry,qa=G.VeyraController,G.VeyraMinigames,G.VeyraParry,G.VeyraQuestAssist
local function summary(module)
 if not module then return {loaded=false} end
 return {loaded=true,alive=module.alive,enabled=module.enabled,status=module.status,activity=module.activity}
end
local function guiState(name)
 local screen=player.PlayerGui:FindFirstChild(name)
 return {exists=screen~=nil,enabled=screen and screen.Enabled or false}
end
local tracked={}
local indicators=player.PlayerGui:FindFirstChild("QuestIndicators")
if indicators then
 for _,indicator in ipairs(indicators:GetChildren()) do
  if indicator:GetAttribute("status")==true then
   table.insert(tracked,{name=indicator.Name,returning=indicator:GetAttribute("Return")==true})
  end
 end
end
local c=player.Character
local report={
 placeId=game.PlaceId,
 hub={loaded=hub~=nil,alive=hub and hub.alive or false,panel=hub and hub.gui and hub.gui.Parent~=nil or false},
 minigames=summary(mg),parry=summary(parry),quest=summary(qa),
 miningUI=guiState("HarvestTiming"),harvestingUI=guiState("HarvestRings"),
 activeQuestIndicators=tracked,flying=c and c:GetAttribute("Flying")==true or false,
}
if mg then
 report.minigames.worker=mg.isWorking and mg.isWorking() or false
 report.minigames.mineSession=mg.mine~=nil
 report.minigames.harvestSession=mg.harvest~=nil
 report.minigames.result=mg.lastResult
end
if parry then
 report.parry.worker=parry.isWorking and parry.isWorking() or false
 report.parry.attempts=parry.attempts
 report.parry.grants=parry.grants
 report.parry.confirmed=parry.confirmed
 report.parry.unobservedGrants=parry.unobservedGrants
 report.parry.lead=parry.lead
 report.parry.calibrated=parry.calibrated
 report.parry.blockedReason=parry.blockedReason
 report.parry.recentLog={}
 for i=math.max(1,#parry.log-14),#parry.log do
  table.insert(report.parry.recentLog,parry.log[i])
 end
end
local json=HttpService:JSONEncode(report)
print("[Veyra smoke test] "..json)
if type(writefile)=="function" then
 local ok,err=pcall(writefile,"Veyra_smoke_test.json",json)
 if ok then print("[Veyra smoke test] saved Veyra_smoke_test.json")
 else warn("[Veyra smoke test] save failed: "..tostring(err)) end
end
return report
