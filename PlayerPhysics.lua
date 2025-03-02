--[[

Author: Goennigoegoe aka nullptr

Idea:
Use PhysicsEnvironment ( https://lmaobox.net/lua/Lua_Classes/PhysicsEnvironment/ )
to predict players.

]]--

local environment = physics.CreateEnvironment();
local object_cache = {};

local lastFire = 0;
local nextAttack = 0;

local predicted_position = Vector3(0, 0, 0);

-- https://github.com/lnx00/Lmaobox-Library/blob/6f2f72b57e21018abf7d1f2560410f10d1756ded/src/lnxLib/Utils/Math.lua#L8
local M_RADPI = 180 / math.pi

function CanFire(pLocal, pWeapon)
    if not pLocal then return false end;
    if not pWeapon then return false end;

    local pWeaponLastFire = pWeapon:GetPropFloat("m_flLastFireTime");
    local pWeaponNextAttack = pWeapon:GetPropFloat("m_flNextPrimaryAttack");
    local pWeaponClip1 = pWeapon:GetPropInt("m_iClip1");

    local ServerTime = pLocal:GetPropInt("m_nTickBase");

    if lastFire ~= pWeaponLastFire then
        lastFire = pWeaponLastFire;
        nextAttack = pWeaponNextAttack;
    end

    if pWeaponClip1 == 0 then return false end;

    return nextAttack <= ServerTime * globals.TickInterval();
end

function IsVisible(Skip, ent, from, to)
    local trace = engine.TraceLine(from, to, MASK_SHOT | CONTENTS_GRATE, function(ent, contentsMask)
        if ent == Skip then
            return false;
        end

        return true;
    end)

    return (trace.entity and trace.entity == ent) or trace.fraction > 0.99;
end

-- https://github.com/lnx00/Lmaobox-Library/blob/6f2f72b57e21018abf7d1f2560410f10d1756ded/src/lnxLib/Utils/Math.lua#L46
function position_angles(source, dest)
    local delta = source - dest

    local pitch = math.atan(delta.z / delta:Length2D()) * M_RADPI
    local yaw = math.atan(delta.y / delta.x) * M_RADPI

    if delta.x >= 0 then
        yaw = yaw + 180
    end

    return EulerAngles(pitch, yaw, 0)
end

-- https://github.com/lnx00/Lmaobox-Library/blob/6f2f72b57e21018abf7d1f2560410f10d1756ded/src/lnxLib/Utils/Math.lua#L66
function angle_fov(vFrom, vTo)
    local vSrc = vFrom:Forward()
    local vDst = vTo:Forward()
    
    local fov = math.deg(math.acos(vDst:Dot(vSrc) / vDst:LengthSqr()))

    return fov
end

function get_best_target(localplayer)
    local players = entities.FindByClass("CTFPlayer");
    local bestTarget = nil;
    local bestFov = 30; -- without any extra checks check if player is within fov
    local pView = localplayer:GetAbsOrigin() + localplayer:GetPropVector("localdata", "m_vecViewOffset[0]");

    --local wWeapon = WWeapon.FromEntity(pWeapon);

    for idx, entity in pairs(players) do
        if idx == localplayer:GetIndex() then goto continue end
        if entity:IsDormant() or not entity:IsAlive() then goto continue end
        if entity:GetTeamNumber() == localplayer:GetTeamNumber() then goto continue end

        --local wTarget = WPlayer.FromEntity(entity);
        local pBody = entity:GetAbsOrigin();

        local ang = position_angles(pView, pBody);
        local dist = angle_fov(engine.GetViewAngles(), ang);

        if dist < bestFov then
            bestTarget = entity;
            bestFov = dist;
        end

        ::continue::
    end

    return bestTarget;
end

-- https://github.com/lnx00/Lmaobox-Library/blob/6f2f72b57e21018abf7d1f2560410f10d1756ded/src/lnxLib/Utils/Conversion.lua#L137
function ticks_to_time(ticks)
    return ticks * globals.TickInterval();
end

function time_to_ticks(time)
    return math.floor(0.5 + time / globals.TickInterval())
end

-- Sets up everything needed for player prediction.
function setup_prediction(target)
    -- cache / entity stuff
    local idx = target:GetIndex();
    local model_name = models.GetModelName(target:GetModel());

    -- physics stuff
    local collision_model = physics.BBoxToCollisionModel(target:GetMins(), target:GetMaxs());
    local velocity = target:EstimateAbsVelocity();
    local origin = target:GetAbsOrigin();
    local physics_object = environment:CreatePolyObject(collision_model, model_name, physics.DefaultObjectParameters());

    -- reset the environment
    environment:ResetSimulationClock();

    -- setup the physics object
    physics_object:SetPosition(origin, Vector3(0, 0, 0), true);
    physics_object:SetVelocity(velocity, Vector3(0, 0, 0));
    
    -- :Wake() the object up so it actually simulates
    physics_object:Wake();

    -- cache stuff
    object_cache[idx] = physics_object;

    -- setup the return data, probably won't be used because you can just index into the cache to get the physics object.
    --[[local data = {
        collision = collision_model,
        object = idx, -- the index of the object in the cache, this should save some memory but it might not.
    }

    return data;]]--
end

-- Run when done predicting a player, otherwise you might have f/s issues because of predicting multiple players at once, that case should never happen but if something can break, it will break.
function kill_prediction(target)
    -- cache / entity stuff
    local idx = target:GetIndex();
    if not object_cache[idx] then return end; -- this should never happen but I've added it for safety.

    -- physics object removal
    object_cache[idx]:Sleep(); -- most likely not needed but added just so that it can't predict multiple targets at once.
    environment:DestroyObject(object_cache[idx]);

    -- remove reference to object from cache and hopefully get lua to fully free() its memory
    object_cache[idx] = nil;

    -- reset the environment
    environment:ResetSimulationClock();
end

-- predicts a target and returns the end position
function run_tick(target)
    -- cache / entity stuff
    local idx = target:GetIndex();
    if not object_cache[idx] then return end; -- this should never happen but I've added it for safety.

    --local physics_object = object_cache[idx]; -- I hope lua does this by reference.
    
    -- run the tick
    environment:Simulate(globals.TickInterval());

    return object_cache[idx]:GetPosition();
end

-- same as run_tick but just allows you to set a custom amount of time
function run_time(target, time)
    -- cache / entity stuff
    local idx = target:GetIndex();
    if not object_cache[idx] then return end; -- this should never happen but I've added it for safety.

    --local physics_object = object_cache[idx]; -- I hope lua does this by reference.
    
    -- run the tick
    environment:Simulate(time);

    return object_cache[idx]:GetPosition();
end




callbacks.Register("CreateMove", function(cmd)
    local localplayer = entities.GetLocalPlayer();
    if not localplayer then return end;

    local weapon = localplayer:GetPropEntity("m_hActiveWeapon");
    if not weapon or not weapon:IsValid() or not weapon:IsShootingWeapon() or not weapon:GetWeaponProjectileType() then return end;

    if (cmd.buttons & IN_ATTACK) == 0 then return end;
    if not CanFire(localplayer, weapon) then return end;

    local target = get_best_target(localplayer);
    if not target then return end;

    local proj_speed = 1100;--weapon:GetProjectileSpeed();
    local time_to_target = (target:GetAbsOrigin() - localplayer:GetAbsOrigin()):Length() / proj_speed;
    local local_eye = localplayer:GetAbsOrigin() + localplayer:GetPropVector("localdata", "m_vecViewOffset[0]");

    print(time_to_ticks(time_to_target));

    setup_prediction(target);

    local pos = Vector3(0, 0, 0);
    for i=1, time_to_ticks(time_to_target) do
        pos = run_tick(target);
    end
    local angle = position_angles(local_eye, pos);

    predicted_position = pos;

    cmd.viewangles = Vector3(angle.x, angle.y, 0.0);
    cmd.sendpacket = false; -- psilent

    kill_prediction(target); -- kill the prediction
end)

callbacks.Register("Draw", function()
    local position = client.WorldToScreen(predicted_position);

    if position ~= nil then
        draw.Color(255, 0, 255, 255);
        draw.OutlinedCircle(position[1], position[2], 5, 4);
    end
end)

-- do cleanup when unloading ( eg: remove physics environment ).
callbacks.Register("Unload", function()
    -- cleanup the object cache
    for i, v in pairs(object_cache) do
        if not v then goto cache_continue; end;
        environment:DestroyObject(v);
        object_cache[i] = nil;

        ::cache_continue::
    end

    -- destroy the environment
    physics.DestroyEnvironment(environment);
    environment = nil;
end)
