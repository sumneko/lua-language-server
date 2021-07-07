local nonil     = require 'without-check-nil'
local util      = require 'utility'
local lang      = require 'language'
local proto     = require 'proto'
local define    = require 'proto.define'
local config    = require 'config'

local m = {}
m.watchList = {}

function m.client(newClient)
    if newClient then
        m._client = newClient
    else
        return m._client
    end
end

function m.isVSCode()
    if not m._client then
        return false
    end
    if m._isvscode == nil then
        local lname = m._client:lower()
        if lname:find 'vscode'
        or lname:find 'visual studio code' then
            m._isvscode = true
        else
            m._isvscode = false
        end
    end
    return m._isvscode
end

function m.getOption(name)
    nonil.enable()
    local option = m.info.initializationOptions[name]
    nonil.disable()
    return option
end

local function packMessage(...)
    local strs = table.pack(...)
    for i = 1, strs.n do
        strs[i] = tostring(strs[i])
    end
    return table.concat(strs, '\t')
end

---show message to client
---@param type '"Error"'|'"Warning"'|'"Info"'|'"Log"'
function m.showMessage(type, ...)
    local message = packMessage(...)
    proto.notify('window/showMessage', {
        type = define.MessageType[type] or 3,
        message = message,
    })
    proto.notify('window/logMessage', {
        type = define.MessageType[type] or 3,
        message = message,
    })
end

---@param type '"Error"'|'"Warning"'|'"Info"'|'"Log"'
function m.logMessage(type, ...)
    local message = packMessage(...)
    proto.notify('window/logMessage', {
        type = define.MessageType[type] or 4,
        message = message,
    })
end

---@class config.change
---@field key       string
---@field value     any
---@field action    '"add"'|'"set"'
---@field isGlobal? boolean
---@field uri?      uri

---@param changes config.change[]
function m.setConfig(changes)
    for _, change in ipairs(changes) do
        if change.action == 'add' then
            config.add(change.key, change.value)
        elseif change.action == 'set' then
            config.set(change.key, change.value)
        end
    end
    m.event('updateConfig')
    if m.getOption 'changeConfiguration' then
        for _, change in ipairs(changes) do
            proto.notify('$/command', {
                command   = 'lua.config',
                data      = change,
            })
        end
    else
        -- TODO translate
        local messages = {}
        messages[1] = lang.script('你的客户端不支持从服务侧修改设置，请手动修改如下设置：')
        for _, change in ipairs(changes) do
            if change.action == 'add' then
                messages[#messages+1] = lang.script('为 `{key}` 添加值 `{value:q}`;', change)
            else
                messages[#messages+1] = lang.script('将 `{key}` 的值设置为 `{value:q}`;', change)
            end
        end
        local message = table.concat(messages, '\n')
        m.showMessage('Info', message)
    end
end

function m.event(ev, ...)
    for _, callback in ipairs(m.watchList) do
        callback(ev, ...)
    end
end

function m.watch(callback)
    m.watchList[#m.watchList+1] = callback
end

function m.init(t)
    log.debug('Client init', util.dump(t))
    m.info = t
    nonil.enable()
    m.client(t.clientInfo.name)
    nonil.disable()
    lang(LOCALE or t.locale)
end

return m