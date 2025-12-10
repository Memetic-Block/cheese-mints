local codepath = 'collection.collection'

describe('CheeseMintCollection Initialization', function ()
  _G.send = spy.new(function() end)
  require(codepath)
  before_each(function()
    CacheOriginalGlobals()
    _G.send = spy.new(function() end)
    require(codepath)
  end)
  after_each(function()
    RestoreOriginalGlobals()
    _G.send = spy.new(function() end)
    package.loaded[codepath] = nil
  end)

  it('should initialize', function ()
    _G.send = spy.new(function() end)
    package.loaded[codepath] = nil
    require(codepath)

    assert.is_true(cheese_mint_collection_initialized)
  end)
end)