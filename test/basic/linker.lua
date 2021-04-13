local linker = require 'core.linker'
local files  = require 'files'
local util   = require 'utility'
local guide  = require 'core.guide'
local glob = require "glob"

local function getSource(pos)
    local ast = files.getAst('')
    return guide.eachSourceContain(ast.ast, pos, function (source)
        if source.type == 'local'
        or source.type == 'getlocal'
        or source.type == 'setlocal'
        or source.type == 'setglobal'
        or source.type == 'getglobal'
        or source.type == 'field'
        or source.type == 'method' then
            return source
        end
    end)
end

local function TEST(script)
    return function (expect)
        files.removeAll()
        local start  = script:find('<?', 1, true)
        local finish = script:find('?>', 1, true)
        local pos = (start + finish) // 2 + 1
        local newScript = script:gsub('<[!?]', '  '):gsub('[!?]>', '  ')
        files.setText('', newScript)
        local source = getSource(pos)
        assert(source)
        local result = linker.getLink(source)
        assert(util.equal(result, expect))
    end
end

TEST [[
local <?x?>
]] {
    id = '9',
}

TEST [[
local x
print(<?x?>)
]] {
    id = '7',
}

TEST [[
local x
<?x?> = 1
]] {
    id = '7',
}

TEST [[
print(<?X?>)
]] {
    id     = '"X"',
    global = true,
}

TEST [[
print(<?X?>)
]] {
    id     = '"X"',
    global = true,
}

TEST [[
local x
print(x.y.<?z?>)
]] {
    id     = '7|"y"|"z"',
}

TEST [[
local x
function x:<?f?>() end
]] {
    id     = '7|"f"',
}

TEST [[
print(X.Y.<?Z?>)
]] {
    id     = '"X"|"Y"|"Z"',
    global = true,
}

TEST [[
function x:<?f?>() end
]] {
    id     = '"x"|"f"',
    global = true,
}

TEST [[
{
    <?x?> = 1,
}
]] {
    id     = '1|"x"',
    tfield = true,
}

TEST [[
return <?X?>
]] {
    id      = '"X"',
    global  = true,
    freturn = true,
}
