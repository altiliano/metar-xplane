-- METAR Fetcher
if not SUPPORTS_FLOATING_WINDOWS then return end
local icao = "KJFK"
local metar_txt = "Enter ICAO and click Get METAR"
local show_window = true

dataref("wind_spd", "sim/weather/wind_speed_kt[0]")
dataref("wind_dir", "sim/weather/wind_direction_degt[0]")
dataref("temp_c", "sim/weather/temperature_ambient_c")
dataref("baro_sea", "sim/weather/barometer_sealevel_inhg")
dataref("visibility", "sim/weather/visibility_reported_m")

wnd = float_wnd_create(600, 320, 1, true)
float_wnd_set_position(wnd, 100, 100)
float_wnd_set_title(wnd, "METAR")
float_wnd_set_imgui_builder(wnd, "draw_wnd")
float_wnd_set_onclose(wnd, "on_close_wnd")

function on_close_wnd()
    show_window = false
end

function draw_wnd()
    if not show_window then
        return
    end
    
    imgui.TextUnformatted("ICAO Airport Code:")
    local ch, nv = imgui.InputText("##ic", icao, 5)
    if ch then icao = string.upper(nv) end
    imgui.SameLine()
    if imgui.Button("Get METAR") then get_metar() end
    imgui.Separator()
    imgui.TextUnformatted("Real-World METAR:")
    imgui.TextUnformatted(metar_txt)
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
    metar_txt = "Fetching METAR for " .. icao .. "..."
    local h = io.popen('curl -s "https://aviationweather.gov/api/data/metar?ids=' .. icao .. '&format=raw"')
    local r = h:read("*a")
    h:close()
    metar_txt = (r and r ~= "") and r or "No METAR data found for " .. icao
end

-- Create menu command to toggle window
add_macro("Toggle METAR Window", "show_window = not show_window", "", "deactivate")
create_command("FlyWithLua/metar/toggle", "Toggle METAR Window", "show_window = not show_window", "", "")
