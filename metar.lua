-- METAR Fetcher (Async Version)
if not SUPPORTS_FLOATING_WINDOWS then return end
local icao = "KJFK"
local metar_txt = "Enter ICAO and click Get METAR"
local show_window = false
local http_request_pending = false
local temp_file = SCRIPT_DIRECTORY .. "metar_temp.txt"
local loading_dots = 0
local loading_timer = 0

dataref("wind_spd", "sim/weather/wind_speed_kt[0]")
dataref("wind_dir", "sim/weather/wind_direction_degt[0]")
dataref("temp_c", "sim/weather/temperature_ambient_c")
dataref("baro_sea", "sim/weather/barometer_sealevel_inhg")
dataref("visibility", "sim/weather/visibility_reported_m")

wnd = float_wnd_create(900, 500, 1, true)  -- Larger size for 4K displays
float_wnd_set_position(wnd, 100, 100)
float_wnd_set_title(wnd, "METAR")
float_wnd_set_imgui_builder(wnd, "draw_wnd")
float_wnd_set_onclose(wnd, "on_close_wnd")
float_wnd_set_visible(wnd, 0)  -- Hide window by default

function on_close_wnd()
    show_window = false
    float_wnd_set_visible(wnd, 0)
end

function draw_wnd()
    imgui.TextUnformatted("ICAO Airport Code:")
    local ch, nv = imgui.InputText("##ic", icao, 5)
    if ch then icao = string.upper(nv) end
    imgui.SameLine()
    if imgui.Button("Get METAR") then get_metar() end
    imgui.Separator()
    imgui.TextUnformatted("Real-World METAR:")
    
    -- Show animated loading message while waiting
    if http_request_pending then
        local dots = string.rep(".", (loading_dots % 4))
        imgui.TextUnformatted("Fetching METAR for " .. icao .. dots)
    else
        imgui.TextUnformatted(metar_txt)
    end
    
    imgui.Separator()
    imgui.TextUnformatted("X-Plane Weather (Aircraft Location):")
    local qnh_hpa = baro_sea * 33.8639
    local vis_sm = visibility * 0.000621371
    imgui.TextUnformatted(string.format("Wind %03d/%d kt  Temp %.1fC  QNH %.2f inHg / %d hPa", 
        math.floor(wind_dir), math.floor(wind_spd), temp_c, baro_sea, math.floor(qnh_hpa + 0.5)))
    imgui.TextUnformatted(string.format("Visibility: %.1f SM / %.0f m", vis_sm, visibility))
end

function get_metar()
    if string.len(icao) < 3 then metar_txt = "Invalid ICAO" return end
    if http_request_pending then return end -- Prevent multiple simultaneous requests
    
    metar_txt = "Fetching METAR for " .. icao .. "..."
    http_request_pending = true
    loading_dots = 0
    loading_timer = os.clock()
    
    -- Start async curl in background (returns immediately)
    -- Windows requires 'start /B' instead of '&' for background execution
    local cmd
    if SYSTEM == "IBM" then  -- Windows
        cmd = string.format('start /B curl -s "https://aviationweather.gov/api/data/metar?ids=%s&format=raw" > "%s" 2>&1', 
                          icao, temp_file)
    else  -- Linux/Mac
        cmd = string.format('curl -s "https://aviationweather.gov/api/data/metar?ids=%s&format=raw" > "%s" 2>&1 &', 
                          icao, temp_file)
    end
    os.execute(cmd)
end

function check_metar_response()
    if not http_request_pending then return end
    
    -- Update loading animation every 0.3 seconds
    if os.clock() - loading_timer > 0.3 then
        loading_dots = loading_dots + 1
        loading_timer = os.clock()
    end
    
    -- Try to open and read the temp file
    local file = io.open(temp_file, "r")
    if file then
        local content = file:read("*a")
        file:close()
        
        -- Check if we got actual data (curl might still be writing)
        if content and string.len(content) > 0 then
            metar_txt = content ~= "" and content or "No METAR data found for " .. icao
            http_request_pending = false
            -- Clean up temp file
            os.remove(temp_file)
        end
    end
end

-- Check for response periodically without blocking
do_often("check_metar_response()")

-- Create menu command to toggle window
add_macro("Toggle METAR Window", "show_window = not show_window; float_wnd_set_visible(wnd, show_window and 1 or 0)", "", "deactivate")
create_command("FlyWithLua/metar/toggle", "Toggle METAR Window", "show_window = not show_window; float_wnd_set_visible(wnd, show_window and 1 or 0)", "", "")
