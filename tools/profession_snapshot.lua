-- Veyra profession XP snapshot (read-only). Run before and after an activity.
-- Reports nearby profession-related numeric values and profession UI text.
local Players=game:GetService("Players")
local Http=game:GetService("HttpService")
local p=Players.LocalPlayer
if not p then warn("[Veyra] No LocalPlayer") return end
local state=getgenv()
state.VeyraProfessionSnapshotCount=(state.VeyraProfessionSnapshotCount or 0)+1
local n=state.VeyraProfessionSnapshotCount
local out={version=1,run=n,placeId=game.PlaceId,time=os.time(),records={},ui={},notes={
 "Snapshot only: compare this file with a second snapshot after repeating ONE activity.",
 "Do not equip or spend anything between snapshots unless that is the activity measured."
}}
local function short(s) s=tostring(s or "") return s:sub(1,180) end
local function relevant(s)
 s=tostring(s or ""):lower()
 for _,k in ipairs({"profession","alchemy","craft","brewing","brew","harvest","mining","combat","broom","experience","progression","mastery","level","exp","xp","tier","essence"}) do
  if s:find(k,1,true) then return true end
 end
 return false
end
local function value(v)
 local t=typeof(v)
 if t=="number" or t=="boolean" then return v end
 if t=="string" then return short(v) end
 return nil
end
local function path(o,root)
 local parts={}
 while o and o~=root and #parts<9 do
  table.insert(parts,1,short(o.Name))
  o=o.Parent
 end
 return table.concat(parts,"/")
end
for _,o in ipairs(p:GetDescendants()) do
 if not o:IsDescendantOf(p.PlayerGui) then
  local parent=o.Parent
  local full=path(o,p)
  if #out.records<650 and (relevant(o.Name) or relevant(parent and parent.Name) or relevant(full)) then
   if o:IsA("ValueBase") then
    table.insert(out.records,{path=full,class=o.ClassName,value=value(o.Value)})
   elseif o:IsA("Folder") or o:IsA("Configuration") then
    local a={}
    for k,v in pairs(o:GetAttributes()) do
     local w=value(v)
     if w~=nil and relevant(k) then a[short(k)]=w end
    end
    if next(a) then table.insert(out.records,{path=full,class=o.ClassName,attributes=a}) end
   end
  end
 end
end
local gui=p:FindFirstChildOfClass("PlayerGui")
if gui then
 for _,o in ipairs(gui:GetDescendants()) do
  if #out.ui>=380 then break end
  if (o:IsA("TextLabel") or o:IsA("TextButton")) and o.Text~="" then
   local full=path(o,gui)
   if relevant(full) and (#o.Text<120) then
    table.insert(out.ui,{path=full,text=short(o.Text),visible=o.Visible})
   end
  end
 end
end
if #out.records==0 then table.insert(out.notes,"No replicated profession numeric values found; UI snapshot may still be useful.") end
local filename="Veyra_profession_snapshot_"..n..".json"
local json=Http:JSONEncode(out)
if type(writefile)=="function" and pcall(writefile,filename,json) then
 print("[Veyra] Saved "..filename.." ("..#out.records.." records, "..#out.ui.." UI labels).")
elseif type(setclipboard)=="function" and pcall(setclipboard,json) then
 print("[Veyra] Copied profession snapshot "..n.." to clipboard. Save to a file.")
else
 for i=1,#json,1600 do print(json:sub(i,i+1599)) end
end
