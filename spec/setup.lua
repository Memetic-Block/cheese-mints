package.path = './src/contracts/?.lua;' ..
  './src/contracts/common/?.lua;' ..
  package.path

-- NB: Preserve original print() as AO overwrites it
_G._print = print

require('spec.hyper-aos')

_G.package.loaded['json'] = require('.json')
_G.module = 'mock-module-id'
_G.owner = 'mock-owner-address'
_G.authority = 'mock-authority-address'
_G.authorities = { _G.authority }
_G.id = 'mock-process-id'
_G.process = { Tags = {} }

function GetHandler(name)
  local handler = require('.utils').find(
    function (val) return val.name == name end,
    _G.Handlers.list
  )
  assert(handler, 'Handler not found: ' .. name)
  return handler
end

function CacheOriginalGlobals()
  -- NB: Preserve a reference to original AO globals to enable test spies
  _G._send = _G.send
  _G._spawn = _G.spawn
end

function RestoreOriginalGlobals()
  -- NB: Restore original AO globals after using test spies
  _G.send = _G._send
  _G.spawn = _G._spawn
end
