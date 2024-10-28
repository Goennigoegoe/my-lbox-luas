local netvarmethod = false;
local maxRange = 48; -- hammer units, 48 is in theory be the max range the knife can do

local bboxsize = 48;
local M_RADPI = 180 / math.pi

local function isNaN(x) return x ~= x end

function PositionAngles(source, dest)
    local delta = source - dest

    local pitch = math.atan(delta.z / delta:Length2D()) * M_RADPI
    local yaw = math.atan(delta.y / delta.x) * M_RADPI

    if delta.x >= 0 then
        yaw = yaw + 180
    end

    if isNaN(pitch) then pitch = 0 end
    if isNaN(yaw) then yaw = 0 end

    return EulerAngles(pitch, yaw, 0)
end

function AngleFov(vFrom, vTo)
    local vSrc = vFrom:Forward()
    local vDst = vTo:Forward()
    
    local fov = math.deg(math.acos(vDst:Dot(vSrc) / vDst:LengthSqr()))
    if isNaN(fov) then fov = 0 end

    return fov
end

function vMul(a, b)
    return EulerAngles(a.x * b.x, a.y * b.y, a.z * b.z);
end

function IsVisible(pSkip, from, to)
    local trace = engine.TraceLine(from, to, MASK_SHOT | CONTENTS_GRATE);
    return (trace.entity == pSkip) or (trace.fraction > 0.99);
end

function CM(cmd)
    local pLocal = entities.GetLocalPlayer();
    if not pLocal or not pLocal:IsAlive() then return end;

    local pWeapon = pLocal:GetPropEntity("m_hActiveWeapon");
    if not pWeapon then return end;

    if netvarmethod then
        if pWeapon:GetPropInt("m_bReadyToBackstab") == 257 then
            cmd:SetButtons( cmd.buttons | IN_ATTACK);
        end
        return;
    end

    local players = entities.FindByClass("CTFPlayer");

    local besttarget = nil;
    local bestyaw = 0;
    local bestDist = 180;

    for idx, entity in pairs(players) do
        if idx == pLocal:GetIndex() then goto continue end
        if entity:IsDormant() or not entity:IsAlive() then goto continue end
        if entity:GetTeamNumber() == pLocal:GetTeamNumber() then goto continue end

        local localabs = pLocal:GetAbsOrigin();
        local entabs = entity:GetAbsOrigin();
        local entAngles = entity:GetPropFloat("tfnonlocaldata", "m_angEyeAngles[1]");

        local delta = localabs - entabs;
        local range = math.sqrt(delta:Length2DSqr());
        if range >= maxRange + bboxsize * 0.87 then -- out of max range chosen
            --print("out of range: " .. range);
            goto continue;
        end

        local angletolocal = PositionAngles(entabs, localabs);
        local disttolocal = angletolocal.y - entAngles;--AngleFov(vMul(engine.GetViewAngles(), EulerAngles(0, 1, 0)), EulerAngles(0, entAngles, 0));
        if disttolocal < 0 then
            disttolocal = disttolocal * -1;
        end

        if disttolocal < 90 then
            goto continue;
        end

        local angleto = PositionAngles(localabs, entabs);
        local dist = engine.GetViewAngles().y - angleto.y;--AngleFov(vMul(engine.GetViewAngles(), EulerAngles(0, 1, 0)), vMul(angleto, EulerAngles(0, 1, 0)));
        if dist < 0 then
            dist = dist * -1;
        end

        if dist < bestDist then
            local canbackstab = IsVisible(entity, localabs, entabs);

            if canbackstab then
                besttarget = entity;
                bestyaw = angleto.y;
                bestDist = dist;
            end
        end

        ::continue::
    end

    if besttarget ~= nil then
        cmd:SetViewAngles(cmd.viewangles.x, bestyaw, cmd.viewangles.z);
        cmd:SetButtons( cmd.buttons | IN_ATTACK)
    end
end

callbacks.Register("CreateMove", CM);
