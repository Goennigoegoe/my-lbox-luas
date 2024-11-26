--[[
A basic Force-of-Nature jump lua I made in like 15 minutes.
]]--

function mapVal(inStart, inEnd, outStart, outEnd, v)
    local slope = 1.0 * (outEnd - outStart) / (inEnd - inStart);
    return outStart + slope * (v - inStart);
end

local minang = 45;
local keybind = MOUSE_5;

local function VectorAngles(forward)
    local tmp, yaw, pitch = 0.0, 0.0, 0.0;

    if forward.y == 0 and forward.x == 0 then
        yaw = 0.0;
        if (forward.z > 0) then
            pitch = 270;
        else
            pitch = 90;
        end
    else
        yaw = math.atan(forward.y, forward.x) * (180 / math.pi);
        if (yaw < 0) then
            yaw = yaw + 360;
        end

        tmp = math.sqrt(forward.x * forward.x + forward.y * forward.y);
        pitch = math.atan(-forward.z, tmp) * (180 / math.pi);
        if (pitch < 0) then
            pitch = pitch + 360;
        end
    end

    return EulerAngles(pitch, yaw, 0);
end

function GetOptimalAngle(speed)
    local angle = minang;
    angle = angle + mapVal(0, 400, 89 - minang, 0, speed);

    print("speed: " .. speed .. " angle: " .. angle)

    return angle;
end

local firstjumptick = false;

function CM(cmd)
    local pLocal = entities.GetLocalPlayer();
    if not pLocal then return end;

    local flags = pLocal:GetPropInt("m_fFlags");
    local Velocity = pLocal:EstimateAbsVelocity();
    local speed = Velocity:Length2D();

    if firstjumptick then
        cmd.buttons = cmd.buttons | IN_ATTACK;

        local velocityAngle = VectorAngles(Velocity);
        cmd:SetViewAngles(GetOptimalAngle(speed), velocityAngle.y, cmd.viewangles.z);
        firstjumptick = false;
    end

    if (cmd.buttons & IN_JUMP) ~= 0 and not firstjumptick and (flags & FL_ONGROUND) ~= 0 and input.IsButtonDown(keybind) then
        firstjumptick = true;
    end
end

callbacks.Register("CreateMove", CM);
