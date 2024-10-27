---@type boolean, lnxLib
local libLoaded, lnxLib = pcall(require, "lnxLib");
assert(libLoaded, "lnxLib not found, please install it!");
assert(lnxLib.GetVersion() <= 0.995, "lnxLib version is too old, please update it!");

-- Import required modules from lnxLib
local WPlayer = lnxLib.TF2.WPlayer;
local WWeapon = lnxLib.TF2.WWeapon;
local Helpers = lnxLib.TF2.Helpers;
local Math = lnxLib.Utils.Math;
local Conversion = lnxLib.Utils.Conversion;
local PlayerResource = lnxLib.TF2.PlayerResource;
local Prediction = lnxLib.TF2.Prediction;

local headshotWeapons = {[17] = true, [43] = true};

local Config = {
    Enabled = true,
    Silent = true,
    FOV = 60,
    HitBoxes = {false, true, false}, -- head, body, legs
    BodyIfNotHS = true;
    Autoshoot = true,
    Keybind = MOUSE_4,
    EnableKeybind = true,
    Multipoint = true,
    PointScale = 0.3,
    Multipoints = 4, -- 4 is probably a pretty low amount but eh, if it doesnt fuck up my fps or make the aimbot dogshit its fine
    Doubletap = true,
};

local dting = false;
local dtshots = 0;
local dtpoint = Vector3(0, 0, 0);

local function GetHitboxPosition(ent, id)
    local hitbox = ent:GetHitboxes()[id];
    if not hitbox then return nil end;

    return (hitbox[1] + hitbox[2]) * 0.5;
end

function GenerateRandomVec3(min, max)
    return Vector3(
        engine.RandomFloat(min.x, max.x),
        engine.RandomFloat(min.y, max.y),
        engine.RandomFloat(min.z, max.z)
    );
end

-- returns a list of hitboxes to shoot at
function GetHitboxes(pWeaponId)
    local hitboxes = {};

    if Config.HitBoxes[1] == true then
        if Config.BodyIfNotHS then -- might not work correctly
            if headshotWeapons[pWeaponId] == true then
                print("headshot weapon");
                --hitboxes[#hitboxes+1] = HITBOX_HEAD;
                hitboxes[#hitboxes+1] = 0;
            end
        end
    end

    if Config.HitBoxes[2] == true then
        --[[hitboxes[#hitboxes+1] = HITBOX_PELVIS;
        hitboxes[#hitboxes+1] = HITBOX_SPINE_0;
        hitboxes[#hitboxes+1] = HITBOX_SPINE_1;
        hitboxes[#hitboxes+1] = HITBOX_SPINE_2;
        hitboxes[#hitboxes+1] = HITBOX_SPINE_3;]]--
        hitboxes[#hitboxes+1] = 1;
        hitboxes[#hitboxes+1] = 2;
        hitboxes[#hitboxes+1] = 3;
        hitboxes[#hitboxes+1] = 4;
        hitboxes[#hitboxes+1] = 5;
    end

    if Config.HitBoxes[3] == true then
        --[[hitboxes[#hitboxes+1] = HITBOX_HIP_L;
        hitboxes[#hitboxes+1] = HITBOX_HIP_R;
        hitboxes[#hitboxes+1] = HITBOX_KNEE_L;
        hitboxes[#hitboxes+1] = HITBOX_KNEE_R;]]--
        hitboxes[#hitboxes+1] = 12;
        hitboxes[#hitboxes+1] = 15;
        hitboxes[#hitboxes+1] = 13;
        hitboxes[#hitboxes+1] = 16;
        --hitboxes[#hitboxes+1] = HITBOX_FOOT_L;
        --hitboxes[#hitboxes+1] = HITBOX_FOOT_R;
    end

    return hitboxes;
end

function VectorTransform(input, matrix)
    local output1 = {};
    for i=1, 4 do
        --output[i] = input.Dot(matrix[1]) + matrix[1][3];
        local bonepos = Vector3(matrix[1][4], matrix[2][4], matrix[3][4]);
        output1[i] = input:Dot(bonepos);-- + matrix[1][3];
    end
    local output = Vector3(output1[1], output1[2], output1[3]);
    --print("input: " .. input.x .. " " .. input.y .. " " .. input.z .. " output: " .. output.x .. " " .. output.y .. " " .. output.z);
    return output;
end

function GetMultiPoints(bbox, matrices)
    local mins = bbox:GetBBMin() * Config.PointScale;
    local maxs = bbox:GetBBMax() * Config.PointScale;

    local matrix = matrices[bbox:GetBone() + 1];
    --print("bone: " .. bbox:GetBone() + 1);
    local bonepos = Vector3(matrix[1][4], matrix[2][4], matrix[3][4]);

    --[[local minsU = (mins - maxs) * 0.5;
    local maxsU = (maxs - mins) * 0.5;

    mins = minsU * Config.PointScale;
    maxs = maxsU * Config.PointScale;

    local offset, origin, center;
    local bone = bbox:GetBone() + 1;
    origin = VectorTransform(Vector3(0, 0, 0), matrices[bone])
    center = VectorTransform((mins + maxs) * 0.5, matrices[bone]);
    offset = center - origin;

    local points = {};
    for i=1, Config.Multipoints do
        local point = GenerateRandomVec3(mins, maxs);
        local transformed = VectorTransform(point, matrices[bone]);
        points[i] = transformed + offset;
    end]]--

    local points = {};
    for i=1, Config.Multipoints do
        points[i] = GenerateRandomVec3(mins, maxs) + bonepos;
        --print("pos: " .. points[i].x .. " " .. points[i].y .. " " .. points[i].z);
    end

    return points;
end

function IsHitboxVisible(pTarget, hitbox, from, to)
    local trace = engine.TraceLine(from, to, MASK_SHOT | CONTENTS_GRATE);
    return (trace.entity == target and trace.hitbox == hitbox) or (trace.fraction > 0.99);
    --return (trace.entity == target) or (trace.fraction > 0.99);
end

--[[Target = player]]--
function GetBestTarget(pLocal, pWeapon)
    local players = entities.FindByClass("CTFPlayer");
    local bestTarget = nil;
    local bestFov = Config.FOV; -- without any extra checks check if player is within fov

    local wLocal = WPlayer.FromEntity(pLocal);
    local pView = wLocal:GetEyePos();

    local wWeapon = WWeapon.FromEntity(pWeapon);

    for idx, entity in pairs(players) do
        if idx == pLocal:GetIndex() then goto continue end
        if entity:IsDormant() or not entity:IsAlive() then goto continue end
        if entity:GetTeamNumber() == pLocal:GetTeamNumber() then goto continue end

        --local wTarget = WPlayer.FromEntity(entity);
        local pBody = GetHitboxPosition(entity, 1);

        local ang = Math.PositionAngles(pView, pBody);
        local dist = Math.AngleFov(engine.GetViewAngles(), ang);

        if dist < bestFov then
            bestTarget = entity;
            bestFov = dist;
        end

        ::continue::
    end

    return bestTarget;
end

function canshoot(pLocal, pWeapon)
    return Conversion.Time_to_Ticks(pWeapon:GetPropFloat("m_flNextPrimaryAttack")) <= pLocal:GetPropInt("m_nTickBase");
end

function CM(cmd)
    local pLocal = entities.GetLocalPlayer();
    if not pLocal or not pLocal:IsAlive() then return end;
    local wLocal = WPlayer.GetLocal();
    local pLocalEye = wLocal:GetEyePos();

    local pWeapon = pLocal:GetPropEntity("m_hActiveWeapon");
    if not pWeapon or not pWeapon:IsValid() or not pWeapon:IsShootingWeapon() then return end;
    local pWeaponId = pWeapon:GetPropInt( "m_iItemDefinitionIndex" );

    if not Config.Autoshoot and (cmd.buttons & IN_ATTACK) == 0 then return end;

    if not input.IsButtonDown(Config.Keybind) and Config.EnableKeybind then return end;

    if dting then
        local angle = Math.PositionAngles(pLocalEye, dtpoint);
        --print("shooting dt");
        
        if not Config.Silent then
            engine.SetViewAngles(angle);
        end

        cmd.viewangles = Vector3(angle.pitch, angle.yaw, 0);
        cmd.buttons = cmd.buttons | IN_ATTACK;

        if pWeapon:GetPropInt("m_iConsecutiveShots") ~= dtshots then
            dting = false;
        end

        return;
    end

    --[[if dting and not canshoot(pLocal, pWeapon) then
        dting = false;
        return;
    end]]--

    --[[local wWeapon = WWeapon.FromEntity(pWeapon);
    if not Helpers.CanShoot(wWeapon) then return end;]]--
    if not canshoot(pLocal, pWeapon) then return end;

    local manualshot = false;

    if (cmd.buttons & IN_ATTACK) ~= 0 then
        manualshot = true;
        cmd.buttons = cmd.buttons & (~IN_ATTACK);
    end

    local target = GetBestTarget(pLocal, pWeapon);
    if target == nil then
        if manualshot then
            cmd.buttons = cmd.buttons | IN_ATTACK;
        end
        return;
    end
    local wTarget = WPlayer.FromEntity(target);
    local hitboxes = GetHitboxes(pWeaponId);

    local model = target:GetModel();
    local studioHdr = models.GetStudioModel(model);
  
    local myHitBoxSet = target:GetPropInt("m_nHitboxSet");
    local hitboxSet = studioHdr:GetHitboxSet(myHitBoxSet);
    local pHitboxes = hitboxSet:GetHitboxes();

    local bestHitbox = nil;
    local bestDist = Config.FOV;
    local bestPoint = Vector3(0, 0, 0);

    local matrices = target:SetupBones();

    for _, hitbox in pairs(hitboxes) do
        --[[local angle = Math.PositionAngles(pLocalEye, GetHitboxPosition(target, hitbox));
        local delta = Math.AngleTo(engine.GetViewAngles(), angle);
        if delta < bestDist then
            bestDist = delta;
            bestHitbox = hitbox;
        end]]--

        if hitbox == nil then
            goto skiphitbox;
        end

        local bbox = pHitboxes[hitbox];
        if Config.Multipoint then
            local points = GetMultiPoints(bbox, matrices);

            for i, point in pairs(points) do

                local isVisible = IsHitboxVisible(target, hitbox, pLocalEye, point);

                if isVisible then
                    local angle = Math.PositionAngles(pLocalEye, point);
                    local delta = Math.AngleFov(engine.GetViewAngles(), angle);
                    --print("best hitbox: " .. hitbox .. " delta: " .. delta);
                    if delta < bestDist then
                        bestDist = delta;
                        bestHitbox = hitbox;
                        bestPoint = point;
                    end
                end

                ::skipmpoint::
            end
        else
            local bbpos = (bbox:GetBBMin() + bbox:GetBBMax()) * 0.5;
            local matrix = matrices[bbox:GetBone() + 1];
            local boxPos = bbpos + Vector3(matrix[1][4], matrix[2][4], matrix[3][4]);
            --local boxPos = GetHitboxPosition(target, hitbox);
            --print("pos: " .. boxPos.x .. " " .. boxPos.y .. " " .. boxPos.z);
            local isVisible = IsHitboxVisible(target, hitbox, pLocalEye, boxPos);

            if isVisible then
                local angle = Math.PositionAngles(pLocalEye, boxPos);
                local delta = Math.AngleFov(engine.GetViewAngles(), angle);
                if delta < bestDist then
                    bestDist = delta;
                    bestHitbox = hitbox;
                    bestPoint = boxPos;
                end
            end
        end

        ::skiphitbox::
    end

    if bestHitbox ~= nil then
        --print("best delta: " .. )
        local angle = Math.PositionAngles(pLocalEye, bestPoint);

        if not Config.Silent then
            engine.SetViewAngles(angle);
        end

        if Config.Doubletap then
            if warp.CanDoubleTap(pWeapon) then
                warp.TriggerDoubleTap();
                dting = true;
                dtshots = pWeapon:GetPropInt("m_iConsecutiveShots");
                dtpoint = bestPoint;
            end
        end

        cmd.viewangles = Vector3(angle.pitch, angle.yaw, 0);
        cmd.buttons = cmd.buttons | IN_ATTACK;
    end

    if manualshot then
        cmd.buttons = cmd.buttons | IN_ATTACK;
    end
end

callbacks.Register("CreateMove", CM);
