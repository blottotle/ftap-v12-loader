-- FTAP V14 REMOTE BOOTSTRAP
-- Replace BASE once after hosting. Packs then load automatically.
local BASE="https://raw.githubusercontent.com/blottotle/ftap-v12-loader/main/"
local files={"core.lua","shared.lua","antis.lua","blob-gucci.lua","line-lag.lua","grab-mods.lua","move-extra.lua","results-debug.lua"}
for _,f in ipairs(files) do
    local url=BASE..f
    local ok,src=pcall(function() return game:HttpGet(url) end)
    assert(ok,"HTTP failed: "..url.." | "..tostring(src))
    local fn,err=loadstring(src,"@"..f)
    assert(fn,"compile failed: "..f.." | "..tostring(err))
    fn()
end
print("[FTAP V14 BOOTSTRAP] all packs loaded")
