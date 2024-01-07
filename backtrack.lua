---@type boolean, lnxLib
local libLoaded, lnxLib = pcall(require, "lnxLib");
assert(libLoaded, "lnxLib not found, please install it!");
assert(lnxLib.GetVersion() <= 0.995, "lnxLib version is too old, please update it!");

-- Import required modules from lnxLib
local WPlayer = lnxLib.TF2.WPlayer;
local Helpers = lnxLib.TF2.Helpers;
local Math = lnxLib.Utils.Math;
local Conversion = lnxLib.Utils.Conversion;
local PlayerResource = lnxLib.TF2.PlayerResource;

local arial = draw.CreateFont("Arial Black", 15, 500, FONTFLAG_ANTIALIAS);

--[[ helper functions ]]--
function GetTableLength(t)
    local length = 1;

    for i, v in pairs(t) do
        length = i;
    end

    return length;
end

function ShiftTable(t)
    local temp = {}
    temp[1] = nil;

    local tLen = GetTableLength(t);

    for i, v in pairs(t) do
        if i ~= tLen then
            temp[i + 1] = v;
        end
    end

    return temp;
end

function RemoveLastTableElement(t)
    local temp = {};

    local tLen = GetTableLength(t);

    for i, v in pairs(t) do
        if i ~= tLen then
            temp[i] = v;
        end
    end

    return temp;
end

function TableInsert(t, value)
    local temp = {};

    temp[1] = value;

    for i, v in pairs(t) do
        temp[i + 1] = v;
    end

    return temp;
end

function ternary ( cond , T , F ) --https://stackoverflow.com/questions/5525817/inline-conditions-in-lua-a-b-yes-no
    if cond then return T else return F end
end

function closestPointOnLine(lineStart, lineEnd, areaMin, areaMax) -- too slow // discord user terminator2481 sent this in message: https://discord.com/channels/1055898368968245348/1173553262314663946/1180976136897953812
    local function dot(v1, v2)
        return v1.x * v2.x + v1.y * v2.y
    end
    local function projectPointOnLine(point, lineStart, lineEnd)
        local lineVec = { x = lineEnd.x - lineStart.x, y = lineEnd.y - lineStart.y }
        local pointVec = { x = point.x - lineStart.x, y = point.y - lineStart.y }
        local lineLengthSquared = dot(lineVec, lineVec)
        local projected = dot(pointVec, lineVec) / lineLengthSquared
        return { x = lineStart.x + lineVec.x * projected, y = lineStart.y + lineVec.y * projected }
    end
    local function isPointInArea(point, areaMin, areaMax)
        return point.x >= areaMin.x and point.x <= areaMax.x and point.y >= areaMin.y and point.y <= areaMax.y
    end
    -- Represent the area as a point for simplicity
    local areaCenter = { x = (areaMin.x + areaMax.x) / 2, y = (areaMin.y + areaMax.y) / 2 }
    local closestPoint = projectPointOnLine(areaCenter, lineStart, lineEnd)
    if isPointInArea(closestPoint, areaMin, areaMax) then
        return closestPoint, true
    else
        return closestPoint, false
    end
end
-- Example usage
--[[local lineStart = { x = 0, y = 0 }
local lineEnd = { x = 10, y = 10 }
local areaMin = { x = 3, y = 3 }
local areaMax = { x = 6, y = 6 }
local closestPoint, isInArea = closestPointOnLine(lineStart, lineEnd, areaMin, areaMax)
print("Closest Point: ", closestPoint.x, closestPoint.y, "Is in Area: ", isInArea)]]--

function LineIntersectsAABB(lineStart, lineEnd, aabbMin, aabbMax)
    local dir = {
        lineEnd[1] - lineStart[1],
        lineEnd[2] - lineStart[2],
        lineEnd[3] - lineStart[3]
    }

    local tMin = 0
    local tMax = 1

    for i = 1, 3 do
        if dir[i] ~= 0 then
            local invDir = 1 / dir[i]
            local t1 = (aabbMin[i] - lineStart[i]) * invDir
            local t2 = (aabbMax[i] - lineStart[i]) * invDir

            local tMinTemp = math.min(t1, t2)
            local tMaxTemp = math.max(t1, t2)

            tMin = math.max(tMin, tMinTemp)
            tMax = math.min(tMax, tMaxTemp)

            if tMin > tMax then
                return false
            end
        else
            if lineStart[i] < aabbMin[i] or lineStart[i] > aabbMax[i] then
                return false
            end
        end
    end

    return tMax >= tMin
end

local function vMul(pos1, pos2)
    return Vector3(pos1.x * pos2.x, pos1.y * pos2.y, pos1.z * pos2.z);
end

local function GetDistance(pos1, pos2)
    return math.sqrt((pos1.x * pos1.x + pos1.y * pos1.y + pos1.z * pos1.z) - (pos2.x * pos2.x + pos2.y * pos2.y + pos2.z * pos2.z));
end

local function GetTimeHitbox(id, time, ent)
    local hitbox = ent:GetHitboxes(time)[id];
    if not hitbox then return nil end;

    return (hitbox[1] + hitbox[2]) * 0.5;
end

local dataTable = {data = {}, pos = {}}; -- table containing tables with data for example: {data = {}} the data is filled with tables like this: {tick_count = 0}

local shouldDraw = true;

local lastHitPos = Vector3(0, 0, 0);
local delays = {};

local ping = 0;
local pingTimer = 0;
local pingMaxTimer = 32;

local aimDistance = 3;
local distMod = 0.01;

callbacks.Register("CreateMove", function(cmd)
    local me = WPlayer.GetLocal()
    if not me then return end

    pingTimer = pingTimer + 1;
    if pingTimer >= pingMaxTimer then
        pingTimer = 0;

        ping = PlayerResource.GetPing()[client.GetLocalPlayerIndex() + 1];
    end
    
    local players = entities.FindByClass("CTFPlayer")
    for idx, entity in pairs(players) do
        if idx == me:GetIndex() then goto continue end
        if entity:IsDormant() or not entity:IsAlive() then goto continue end
        if entity:GetTeamNumber() == me:GetTeamNumber() then goto continue end
        if dataTable[idx] == nil then dataTable[idx] = {} end
        if dataTable[idx].data == nil then dataTable[idx].data = {} end
        if dataTable[idx].pos == nil then dataTable[idx].pos = {} end

        local player = WPlayer.FromEntity(entity)
        local pLocal = WPlayer.GetLocal();

        local BacktrackTicks = GetTableLength(dataTable[idx].data);

        if BacktrackTicks == Conversion.Time_to_Ticks(0.200) then
            dataTable[idx].data = RemoveLastTableElement(dataTable[idx].data);
            dataTable[idx].pos = RemoveLastTableElement(dataTable[idx].pos);
        end

        local shiftedTime = cmd.tick_count;

        if ping > 100 then
            local shiftedTime = cmd.tick_count - Conversion.Time_to_Ticks(ping / 1000);
        end

        --dataTable[idx].data = TableInsert(dataTable[idx].data, cmd.tick_count);
        --dataTable[idx].pos = TableInsert(dataTable[idx].pos, player:GetHitboxPos(1));
        dataTable[idx].data = TableInsert(dataTable[idx].data, shiftedTime);
        dataTable[idx].pos = TableInsert(dataTable[idx].pos, GetTimeHitbox(1, shiftedTime, entity));

        --[[
        local delta = source - dest

        local pitch = math.atan(delta.z / delta:Length2D()) * M_RADPI
        local yaw = math.atan(delta.y / delta.x) * M_RADPI

        if delta.x >= 0 then
            yaw = yaw + 180
        end

        if isNaN(pitch) then pitch = 0 end
        if isNaN(yaw) then yaw = 0 end

        return EulerAngles(pitch, yaw, 0)
        ]]--

        --[[local delta = player:GetEyePos() - pLocal:GetEyePos();

        local bYaw = math.atan(delta.y, delta.x) * (180 / math.pi);
        local bPitch = math.atan(delta.z, delta.y) * (180 / math.pi);
        
        local lPitch, lYaw, _ = cmd:GetViewAngles();

        local fov = Math.AngleFov(EulerAngles(bPitch, bYaw, 0), engine.GetViewAngles());]]--

        local entAimpos = player:GetHitboxPos(1);
        local bestAimPos = Math.PositionAngles(pLocal:GetEyePos(), entAimpos);
        local aimDist = Math.AngleFov(bestAimPos, engine.GetViewAngles());

        if aimDist < 30 then
            --shouldDraw = true;
            if (cmd.buttons & IN_ATTACK) ~= 0 then
                cmd.buttons = cmd.buttons & (~IN_ATTACK);
                local hasHit = false;
                for i = 1, GetTableLength(dataTable[idx].data) do
                    local v = dataTable[idx].data[i];
                    local pos = dataTable[idx].pos[i];

                    if v ~= nil then
                        --local bones = entity:SetupBones(0x7FF00, v);
                        --[[local Hitboxes = entity:GetHitboxes(v);
                        

                        local HeadMin = Hitboxes[1][1];
                        local HeadMax = Hitboxes[1][2];

                        print("headMin " .. HeadMin.x)

                        print("min: " .. HeadMin.x .. ", " .. HeadMin.y .. ", " .. HeadMin.z .. "\nmax: " .. HeadMax.x .. ", " .. HeadMax.y .. ", " .. HeadMax.z)

                        local endPoint = pLocal:GetEyeAngles():Forward() * 8192; -- pLocal:GetEyePos() + pLocal:GetEyeAngles():Forward() * 8192;
                        local beginPoint = Vector3(0, 0, 0); -- pLocal:GetEyePos();

                        local lineB = {beginPoint.x, beginPoint.y, beginPoint.z};
                        local lineE = {endPoint.x, endPoint.y, beginPoint.z};

                        local minB = {HeadMin.x + pos.x, HeadMin.y + pos.y, HeadMin.z + pos.z};
                        local maxB = {HeadMax.x + pos.x, HeadMax.y + pos.y, HeadMax.z + pos.z};

                        --print("end: " .. endPoint.x .. ", " .. endPoint.y .. ", " .. endPoint.z .. "\nbegin: " .. beginPoint.x .. ", " .. beginPoint.y .. ", " .. beginPoint.z);

                        local hit = LineIntersectsAABB(lineB, lineE, minB, maxB);
                        print("hit: " .. ternary(hit == true, "true", "false"));

                        if hit then
                            hasHit = true;
                            cmd.tick_count = v;
                            cmd:SetButtons(cmd.buttons | IN_ATTACK);
                        end]]--

                        local angles = Math.PositionAngles(pLocal:GetEyePos(), pos);
                        local dist = Math.AngleFov(angles, engine.GetViewAngles());

                        if dist < aimDistance / (GetDistance(pLocal:GetEyePos(), pos) * distMod) then
                            local trace = engine.TraceLine( pLocal:GetEyePos(), pos, MASK_SHOT_HULL );
                            if trace.entity ~= nil then
                                if trace.entity ~= me or trace.entity ~= entity then
                                    hasHit = true;
                                    cmd.tick_count = v;
                                    cmd:SetButtons(cmd.buttons | IN_ATTACK);
                                end
                            end
                        end
                    end
                end
                if not hasHit then
                    cmd:SetButtons(cmd.buttons | IN_ATTACK);
                end
            end
        else
            --shouldDraw = false;
        end

        ::continue::
    end
end)

callbacks.Register("Draw", function()
    if shouldDraw then
        local lastDrawPos = Vector3(25, 25); -- ignore z

        local me = WPlayer.GetLocal()
        if not me then return end

        local pLocal = WPlayer.GetLocal();

        local players = entities.FindByClass("CTFPlayer")
        for idx, entity in pairs(players) do
            if idx == me:GetIndex() then goto continue end
            if entity:IsDormant() or not entity:IsAlive() then goto continue end
            if entity:GetTeamNumber() == me:GetTeamNumber() then goto continue end
            if dataTable[idx] == nil then dataTable[idx] = {} end
            if dataTable[idx].data == nil then dataTable[idx].data = {} end
            if dataTable[idx].pos == nil then dataTable[idx].pos = {} end

            --[[if delays[idx] == nil then
                delays[idx] = 1;
            else
                delays[idx] = delays[idx] + 1;
            end

            for i = 1, GetTableLength(dataTable[idx].data) do
                local v = dataTable[idx].data[i];
                local pos = dataTable[idx].pos[i];

                --print(v);

                --local bones = entity:SetupBones(0x7FF00, v);
                local Hitboxes = entity:GetHitboxes(v);
                local HeadMin = Hitboxes[1][1] + pos;
                local HeadMax = Hitboxes[1][2] + pos;
                --local HeadMin = Hitboxes[1][1];
                --local HeadMax = Hitboxes[1][2]

                local screenPos = client.WorldToScreen(lastHitPos);

                if screenPos ~= nil then
                    draw.Color(255, 255, 255, 255);
                    draw.OutlinedCircle(screenPos[1], screenPos[2], 5, 4);

                    delays[idx] = 0;
                    draw.Color(255, 255, 255, 255);
                    draw.SetFont(arial);
                    
                    draw.Text(screenPos[1] + lastDrawPos.x, screenPos[2] + lastDrawPos.y, string.format("%d", v));

                    lastDrawPos.y = lastDrawPos.y + 25;
                end
            end]]--

            --[[for i = 1, GetTableLength(dataTable[idx].data) do
                local v = dataTable[idx].data[i];
                local pos = dataTable[idx].pos[i];

                local angles = Math.PositionAngles(pLocal:GetEyePos(), pos);
                local dist = Math.AngleFov(angles, engine.GetViewAngles());

                local screenPos = client.WorldToScreen(pos);

                if screenPos ~= nil then
                    draw.Color(255, 255, 255, 255);

                    if dist < aimDistance / (GetDistance(pLocal:GetEyePos(), pos) * distMod) then
                        draw.Color(0, 255, 0, 255);
                    end

                    draw.OutlinedCircle(screenPos[1], screenPos[2], 5, 4);
                end
            end]]--

            ::continue::
        end
        --[[draw.Color(255, 255, 255, 255);
        draw.SetFont(arial);
        
        draw.Text(100, 100, string.format("%d", Conversion.Time_to_Ticks(0.200)));]]--
    end
end)