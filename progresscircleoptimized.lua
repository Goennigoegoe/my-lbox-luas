local tex = draw.CreateTextureRGBA("\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF", 2, 2);


function clamp(v, min, max)
    if v < min then return min end
    if v > max then return max end
    
    return v;
end

function mapVal(inStart, inEnd, outStart, outEnd, v)
    local slope = 1.0 * (outEnd - outStart) / (inEnd - inStart);
    return outStart + slope * (v - inStart);
end

--Vertices = {{2, 4}, {4, 2}}
function DrawLineFromTable(vertices)
    for i, v in pairs(vertices) do
        if vertices[i + 1] == nil then
            goto continue;
        end

        draw.Line(vertices[i][1], vertices[i][2], vertices[i + 1][1], vertices[i + 1][2]);

        ::continue::
    end
end

local sinTable = {};
local cosTable = {};
for i = 0, 720 do
    sinTable[i] = math.sin(math.rad(i * 0.5));
    cosTable[i] = math.cos(math.rad(i * 0.5));
end

--[[
call draw.Color before running
]]--
function DrawProgressCircle(v, min, max, xPos, yPos, startdegree, innerrad, outerrad)
    local progress = mapVal(min, max, 0.0, 1.0, v);

    --print(progress);

    local precision = 64; -- 64 total segments
    local scaled_precision = math.floor(precision * clamp(progress, 0.0, 1.0));

    local degpertriangle = 360 / precision;
    local angle = startdegree;

    local vertices = {
        {0.0, 0.0, 0.0, 1.0},
        {0.0, 0.0, 0.0, 1.0},
        {0.0, 0.0, 0.0, 1.0},
        {0.0, 0.0, 0.0, 1.0},
        {0.0, 0.0, 0.0, 1.0},
        {0.0, 0.0, 0.0, 1.0},
    };

    local sinf = math.sin;
    local cosf = math.cos;
    local rad = math.rad;
    local floor = math.floor;

    local drawPoly = draw.TexturedPolygon;

    for i=1, scaled_precision do
        --[[local vposX = xPos + cosf(rad(angle)) * innerrad;
        local vposY = yPos + sinf(rad(angle)) * innerrad;

        local v2posX = xPos + cosf(rad(angle)) * outerrad;
        local v2posY = yPos + sinf(rad(angle)) * outerrad;

        local v3posX = xPos + cosf(rad(angle + degpertriangle)) * innerrad;
        local v3posY = yPos + sinf(rad(angle + degpertriangle)) * innerrad;]]--
        local ang = floor(2 * angle);
        local ang_deg = floor(2 * (angle + degpertriangle));

        local cr, sr = cosTable[ang], sinTable[ang];
        local cr_d, sr_d = cosTable[ang_deg], sinTable[ang_deg];

        local vposX = xPos + cr * innerrad;
        local vposY = yPos + sr * innerrad;

        local v2posX = xPos + cr * outerrad;
        local v2posY = yPos + sr * outerrad;

        local v3posX = xPos + cr_d * innerrad;
        local v3posY = yPos + sr_d * innerrad;

        --[[local v1 = {
            vposX, vposY, 0.0, 1.0
        };

        local v2 = {
            v2posX, v2posY, 1.0, 0.0
        }

        local v3 = {
            v3posX, v3posY, 0.0, 1.0
        }]]--

        --[[vertices[#vertices+1] = v1;
        vertices[#vertices+1] = v2;
        vertices[#vertices+1] = v3;]]--

        --local v4posX = xPos + cosf(rad(angle)) * outerrad;
        --local v4posY = yPos + sinf(rad(angle)) * outerrad;

        local v5posX = xPos + cr_d * outerrad;
        local v5posY = yPos + sr_d * outerrad;

        --local v6posX = xPos + cosf(rad(angle + degpertriangle)) * innerrad;
        --local v6posY = yPos + sinf(rad(angle + degpertriangle)) * innerrad;

        --[[print("v1X: " .. vposX .. " v1Y: " .. vposY);
        print("v2X: " .. v2posX .. " v2Y: " .. v2posY);
        print("v3X: " .. v3posX .. " v6Y: " .. v3posY);
        print("v4X: " .. v4posX .. " v4Y: " .. v4posY);
        print("v5X: " .. v5posX .. " v5Y: " .. v5posY);
        print("v6X: " .. v6posX .. " v6Y: " .. v6posY);]]--

        --[[local v4 = {
            v2posX, v2posY, 0.0, 1.0
        };

        local v5 = {
            v5posX, v5posY, 0.0, 1.0
        }

        local v6 = {
            v3posX, v3posY, 0.0, 1.0
        }]]--

        vertices[1][1] = vposX;
        vertices[1][2] = vposY;

        vertices[2][1] = v2posX;
        vertices[2][2] = v2posY;

        vertices[3][1] = v3posX;
        vertices[3][2] = v3posY;

        vertices[4][1] = v2posX;
        vertices[4][2] = v2posY;

        vertices[5][1] = v5posX;
        vertices[5][2] = v5posY;

        vertices[6][1] = v3posX;
        vertices[6][2] = v3posY;
        --[[vertices[2] = v2;
        vertices[3] = v3;
        vertices[4] = v4;
        vertices[5] = v5;
        vertices[6] = v6;]]--

        drawPoly(tex, vertices, true);

        angle = angle + degpertriangle;
    end


    --[[for i=1, scaled_precision do
        local vposX = xPos + math.cos(math.rad(angle)) * outerrad;
        local vposY = yPos + math.sin(math.rad(angle)) * outerrad;

        local v2posX = xPos + math.cos(math.rad(angle + degpertriangle)) * innerrad;
        local v2posY = yPos + math.sin(math.rad(angle + degpertriangle)) * innerrad;

        local v3posX = xPos + math.cos(math.rad(angle + degpertriangle)) * outerrad;
        local v3posY = yPos + math.sin(math.rad(angle + degpertriangle)) * outerrad;

        local v1 = {
            vposX, vposY, 0.0, 1.0
        };

        local v2 = {
            v2posX, v2posY, 1.0, 0.0
        }

        local v3 = {
            v3posX, v3posY, 0.0, 1.0
        }
        vertices[#vertices+1] = v1;
        vertices[#vertices+1] = v2;
        vertices[#vertices+1] = v3;

        angle = angle - degpertriangle;
    end]]--

    --draw.TexturedPolygon(tex, vertices, true);

    --draw.Color(255, 0, 0, 255);
    --draw.OutlinedCircle(xPos, yPos, 30, 255, 0, 0, 255);

    --draw.Color(255, 0, 0, 255)
    --draw.TexturedPolygon(tex, vertices2, true);

    --[[local vertices = {};
    for i=1, scaled_precision do
        local deg = math.rad((i * (360 / precision)) % 360);

        vertices[i] = { math.floor(xPos + innerrad * math.cos(deg)), math.floor(yPos + innerrad * math.sin(deg)) };
    end

    for i=1, scaled_precision do
        vertices[scaled_precision + 1 + i] = vertices[scaled_precision - i];
    end

    DrawLineFromTable(vertices);]]--

    
end

local value = 0;

callbacks.Register("Draw", function()
    value = value + 1;

    if value > 100 then
        value = 0;
    end

    --draw.Color(255, 0, 0, 255);
    --DrawProgressCircle(value, 0, 100, 50, 50, 0, 20, 1);

    draw.Color(255, 255, 255, 255);

    --[[local w, h = draw.GetScreenSize()
    local tw, th = 50, 50;

    draw.TexturedPolygon( tex, {
        { w/2 - tw/2, h/2 - th/2, 0.0, 0.0 },
        { w/2 + tw/2, h/2 - th/2, 1.0, 0.1 },
        { w/2 + tw/2, h/2 + th/2, 1.0, 1.0 },
        { w/2 - tw/2, h/2 + th/2, 0.0, 1.0 },
    }, true )]]--

    for i=1, 50 do
        DrawProgressCircle(value, 0, 100, i*10, i*10, 0, 20, 30);
    end
    
    --[[DrawProgressCircle(value, 0, 100, 860, 540, 0, 20, 30);

    DrawProgressCircle(value, 0, 100, 125, 100, 0, 20, 30);

    DrawProgressCircle(value, 0, 100, 860, 540, 0, 20, 30);

    DrawProgressCircle(value, 0, 100, 1500, 1000, 0, 20, 30);

    DrawProgressCircle(value, 0, 100, 200, 500, 0, 20, 30);]]--
end)

callbacks.Register("Unload", function()
    draw.DeleteTexture(tex);
end)
