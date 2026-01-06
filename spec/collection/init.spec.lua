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

describe('Bulk-Award-Cheese-Mint', function ()
  local json = require('json')
  local handler
  local testCheeseMintId1 = 'test-cheese-mint-1'
  local testCheeseMintId2 = 'test-cheese-mint-2'
  local testAddress1 = 'test-address-1'
  local testAddress2 = 'test-address-2'

  before_each(function()
    CacheOriginalGlobals()
    _G.send = spy.new(function() end)

    -- Reset globals BEFORE requiring module (since module uses `or {}` pattern)
    _G.cheese_mints_by_id = nil
    _G.cheese_mints_by_address = nil
    _G.cheese_mint_collection_initialized = nil

    package.loaded[codepath] = nil
    require(codepath)
    handler = GetHandler('Bulk-Award-Cheese-Mint')

    -- Setup test cheese mints
    cheese_mints_by_id[testCheeseMintId1] = {
      id = testCheeseMintId1,
      created_at = 1000,
      created_by = 'creator',
      name = 'Test Cheese Mint 1',
      description = 'Test description 1',
      points = 10,
      icon = 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
      category = 'test'
    }
    cheese_mints_by_id[testCheeseMintId2] = {
      id = testCheeseMintId2,
      created_at = 1000,
      created_by = 'creator',
      name = 'Test Cheese Mint 2',
      description = 'Test description 2',
      points = 20,
      icon = 'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
      category = 'test'
    }
  end)

  after_each(function()
    RestoreOriginalGlobals()
    _G.send = spy.new(function() end)
    package.loaded[codepath] = nil
    _G.cheese_mints_by_id = nil
    _G.cheese_mints_by_address = nil
    _G.cheese_mint_collection_initialized = nil
  end)

  it('should bulk award multiple cheese mints to multiple addresses', function ()
    local msg = {
      Id = 'msg-id-1',
      From = Owner,
      Timestamp = 2000,
      Data = json.encode({
        awards = {
          { cheeseMintId = testCheeseMintId1, address = testAddress1 },
          { cheeseMintId = testCheeseMintId2, address = testAddress1 },
          { cheeseMintId = testCheeseMintId1, address = testAddress2 }
        }
      })
    }

    handler.handle(msg)

    assert.is_not_nil(cheese_mints_by_address[testAddress1][testCheeseMintId1])
    assert.is_not_nil(cheese_mints_by_address[testAddress1][testCheeseMintId2])
    assert.is_not_nil(cheese_mints_by_address[testAddress2][testCheeseMintId1])
    assert.equals(Owner, cheese_mints_by_address[testAddress1][testCheeseMintId1].awarded_by)
    assert.equals(2000, cheese_mints_by_address[testAddress1][testCheeseMintId1].awarded_at)
  end)

  it('should fail-fast on invalid cheese mint id', function ()
    local msg = {
      Id = 'msg-id-1',
      From = Owner,
      Timestamp = 2000,
      Data = json.encode({
        awards = {
          { cheeseMintId = testCheeseMintId1, address = testAddress1 },
          { cheeseMintId = 'non-existent-id', address = testAddress2 }
        }
      })
    }

    assert.has_error(function() handler.handle(msg) end, 'Cheese Mint does not exist: non-existent-id')
    -- Verify no awards were made (fail-fast)
    assert.is_nil(cheese_mints_by_address[testAddress1])
  end)

  it('should fail-fast on invalid address', function ()
    local msg = {
      Id = 'msg-id-1',
      From = Owner,
      Timestamp = 2000,
      Data = json.encode({
        awards = {
          { cheeseMintId = testCheeseMintId1, address = '' }
        }
      })
    }

    assert.has_error(function() handler.handle(msg) end, 'Address cannot be empty')
  end)

  it('should fail-fast on duplicate award', function ()
    -- Pre-award a cheese mint
    cheese_mints_by_address[testAddress1] = {
      [testCheeseMintId1] = {
        awarded_by = 'someone',
        awarded_at = 1000,
        message_id = 'old-msg'
      }
    }

    local msg = {
      Id = 'msg-id-1',
      From = Owner,
      Timestamp = 2000,
      Data = json.encode({
        awards = {
          { cheeseMintId = testCheeseMintId2, address = testAddress2 },
          { cheeseMintId = testCheeseMintId1, address = testAddress1 }
        }
      })
    }

    assert.has_error(function() handler.handle(msg) end, 'Award #2: Address already has Cheese Mint with id ' .. testCheeseMintId1)
    -- Verify no new awards were made (fail-fast)
    assert.is_nil(cheese_mints_by_address[testAddress2])
  end)

  it('should fail on empty awards array', function ()
    local msg = {
      Id = 'msg-id-1',
      From = Owner,
      Timestamp = 2000,
      Data = json.encode({ awards = {} })
    }

    assert.has_error(function() handler.handle(msg) end, 'Awards array cannot be empty')
  end)

  it('should fail on missing awards array', function ()
    local msg = {
      Id = 'msg-id-1',
      From = Owner,
      Timestamp = 2000,
      Data = json.encode({})
    }

    assert.has_error(function() handler.handle(msg) end, 'Awards array is required')
  end)

  it('should enforce ACL permissions', function ()
    local msg = {
      Id = 'msg-id-1',
      From = 'unauthorized-user',
      Timestamp = 2000,
      Data = json.encode({
        awards = {
          { cheeseMintId = testCheeseMintId1, address = testAddress1 }
        }
      })
    }

    assert.has_error(function() handler.handle(msg) end, 'Permission Denied')
  end)

  it('should allow Award-Cheese-Mint role to bulk award', function ()
    acl.state.roles = acl.state.roles or {}
    acl.state.roles['Award-Cheese-Mint'] = { ['role-holder'] = true }

    local msg = {
      Id = 'msg-id-1',
      From = 'role-holder',
      Timestamp = 2000,
      Data = json.encode({
        awards = {
          { cheeseMintId = testCheeseMintId1, address = testAddress1 }
        }
      })
    }

    handler.handle(msg)

    assert.is_not_nil(cheese_mints_by_address[testAddress1][testCheeseMintId1])
  end)

  it('should allow Bulk-Award-Cheese-Mint role to bulk award', function ()
    acl.state.roles = acl.state.roles or {}
    acl.state.roles['Bulk-Award-Cheese-Mint'] = { ['bulk-role-holder'] = true }

    local msg = {
      Id = 'msg-id-1',
      From = 'bulk-role-holder',
      Timestamp = 2000,
      Data = json.encode({
        awards = {
          { cheeseMintId = testCheeseMintId1, address = testAddress1 }
        }
      })
    }

    handler.handle(msg)

    assert.is_not_nil(cheese_mints_by_address[testAddress1][testCheeseMintId1])
  end)
end)

-- Helper to create a valid cheese mint for tests
local function createTestCheeseMint(id, overrides)
  overrides = overrides or {}
  return {
    id = id or 'test-id',
    created_at = overrides.created_at or 1000,
    created_by = overrides.created_by or 'creator',
    name = overrides.name or 'Test Cheese Mint',
    description = overrides.description or 'Test description',
    points = overrides.points or 10,
    icon = overrides.icon or 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
    category = overrides.category or 'test'
  }
end

-- Shared test setup helper
local function resetGlobalsAndRequire()
  _G.cheese_mints_by_id = nil
  _G.cheese_mints_by_address = nil
  _G.cheese_mint_collection_initialized = nil
  package.loaded[codepath] = nil
  require(codepath)
end

describe('Create-Cheese-Mint', function ()
  local handler

  before_each(function()
    CacheOriginalGlobals()
    _G.send = spy.new(function() end)
    resetGlobalsAndRequire()
    handler = GetHandler('Create-Cheese-Mint')
  end)

  after_each(function()
    RestoreOriginalGlobals()
    _G.send = spy.new(function() end)
    package.loaded[codepath] = nil
    _G.cheese_mints_by_id = nil
    _G.cheese_mints_by_address = nil
    _G.cheese_mint_collection_initialized = nil
  end)

  it('should create a cheese mint with valid data', function ()
    local msg = {
      Id = 'cheese-mint-id-1',
      From = Owner,
      Timestamp = 1000,
      Tags = {
        ['Cheese-Mint-Name'] = 'My Cheese Mint',
        ['Description'] = 'A delicious cheese mint',
        ['Points'] = '100',
        ['Icon'] = 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
        ['Category'] = 'rewards'
      }
    }

    handler.handle(msg)

    assert.is_not_nil(cheese_mints_by_id['cheese-mint-id-1'])
    assert.equals('My Cheese Mint', cheese_mints_by_id['cheese-mint-id-1'].name)
    assert.equals('A delicious cheese mint', cheese_mints_by_id['cheese-mint-id-1'].description)
    assert.equals(100, cheese_mints_by_id['cheese-mint-id-1'].points)
    assert.equals('aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa', cheese_mints_by_id['cheese-mint-id-1'].icon)
    assert.equals('rewards', cheese_mints_by_id['cheese-mint-id-1'].category)
    assert.equals(1000, cheese_mints_by_id['cheese-mint-id-1'].created_at)
    assert.equals(Owner, cheese_mints_by_id['cheese-mint-id-1'].created_by)
  end)

  it('should use default category when not provided', function ()
    local msg = {
      Id = 'cheese-mint-id-1',
      From = Owner,
      Timestamp = 1000,
      Tags = {
        ['Cheese-Mint-Name'] = 'My Cheese Mint',
        ['Description'] = 'A delicious cheese mint',
        ['Points'] = '100',
        ['Icon'] = 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa'
      }
    }

    handler.handle(msg)

    assert.equals('default', cheese_mints_by_id['cheese-mint-id-1'].category)
  end)

  it('should fail without name', function ()
    local msg = {
      Id = 'cheese-mint-id-1',
      From = Owner,
      Timestamp = 1000,
      Tags = {
        ['Description'] = 'A delicious cheese mint',
        ['Points'] = '100',
        ['Icon'] = 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa'
      }
    }

    assert.has_error(function() handler.handle(msg) end, 'Cheese Mint name is required')
  end)

  it('should fail with name exceeding 250 characters', function ()
    local msg = {
      Id = 'cheese-mint-id-1',
      From = Owner,
      Timestamp = 1000,
      Tags = {
        ['Cheese-Mint-Name'] = string.rep('a', 251),
        ['Description'] = 'A delicious cheese mint',
        ['Points'] = '100',
        ['Icon'] = 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa'
      }
    }

    assert.has_error(function() handler.handle(msg) end, 'Cheese Mint name cannot exceed 250 characters')
  end)

  it('should fail with invalid icon length', function ()
    local msg = {
      Id = 'cheese-mint-id-1',
      From = Owner,
      Timestamp = 1000,
      Tags = {
        ['Cheese-Mint-Name'] = 'My Cheese Mint',
        ['Description'] = 'A delicious cheese mint',
        ['Points'] = '100',
        ['Icon'] = 'invalid-icon'
      }
    }

    assert.has_error(function() handler.handle(msg) end, 'Cheese Mint icon must be 43 char arweave txid')
  end)

  it('should enforce ACL permissions', function ()
    local msg = {
      Id = 'cheese-mint-id-1',
      From = 'unauthorized-user',
      Timestamp = 1000,
      Tags = {
        ['Cheese-Mint-Name'] = 'My Cheese Mint',
        ['Description'] = 'A delicious cheese mint',
        ['Points'] = '100',
        ['Icon'] = 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa'
      }
    }

    assert.has_error(function() handler.handle(msg) end, 'Permission Denied')
  end)
end)

describe('Update-Cheese-Mint', function ()
  local handler
  local testCheeseMintId = 'test-cheese-mint-1'

  before_each(function()
    CacheOriginalGlobals()
    _G.send = spy.new(function() end)
    resetGlobalsAndRequire()
    handler = GetHandler('Update-Cheese-Mint')

    -- Create a cheese mint to update
    cheese_mints_by_id[testCheeseMintId] = createTestCheeseMint(testCheeseMintId)
  end)

  after_each(function()
    RestoreOriginalGlobals()
    _G.send = spy.new(function() end)
    package.loaded[codepath] = nil
    _G.cheese_mints_by_id = nil
    _G.cheese_mints_by_address = nil
    _G.cheese_mint_collection_initialized = nil
  end)

  it('should update a cheese mint with new values', function ()
    local msg = {
      Id = 'update-msg-id',
      From = Owner,
      Timestamp = 2000,
      Tags = {
        ['Cheese-Mint-Id'] = testCheeseMintId,
        ['Cheese-Mint-Name'] = 'Updated Name',
        ['Description'] = 'Updated description',
        ['Points'] = '200',
        ['Icon'] = 'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
        ['Category'] = 'updated-category'
      }
    }

    handler.handle(msg)

    assert.equals('Updated Name', cheese_mints_by_id[testCheeseMintId].name)
    assert.equals('Updated description', cheese_mints_by_id[testCheeseMintId].description)
    assert.equals(200, cheese_mints_by_id[testCheeseMintId].points)
    assert.equals('bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb', cheese_mints_by_id[testCheeseMintId].icon)
    assert.equals('updated-category', cheese_mints_by_id[testCheeseMintId].category)
    assert.equals(2000, cheese_mints_by_id[testCheeseMintId].updated_at)
    assert.equals(Owner, cheese_mints_by_id[testCheeseMintId].updated_by)
    -- Original values should be preserved
    assert.equals(1000, cheese_mints_by_id[testCheeseMintId].created_at)
    assert.equals('creator', cheese_mints_by_id[testCheeseMintId].created_by)
  end)

  it('should keep existing values when not provided', function ()
    local msg = {
      Id = 'update-msg-id',
      From = Owner,
      Timestamp = 2000,
      Tags = {
        ['Cheese-Mint-Id'] = testCheeseMintId,
        ['Cheese-Mint-Name'] = 'Updated Name Only'
      }
    }

    handler.handle(msg)

    assert.equals('Updated Name Only', cheese_mints_by_id[testCheeseMintId].name)
    -- Original values should be preserved
    assert.equals('Test description', cheese_mints_by_id[testCheeseMintId].description)
    assert.equals(10, cheese_mints_by_id[testCheeseMintId].points)
  end)

  it('should fail for non-existent cheese mint', function ()
    local msg = {
      Id = 'update-msg-id',
      From = Owner,
      Timestamp = 2000,
      Tags = {
        ['Cheese-Mint-Id'] = 'non-existent-id',
        ['Cheese-Mint-Name'] = 'Updated Name'
      }
    }

    assert.has_error(function() handler.handle(msg) end, 'Cheese Mint does not exist: non-existent-id')
  end)

  it('should enforce ACL permissions', function ()
    local msg = {
      Id = 'update-msg-id',
      From = 'unauthorized-user',
      Timestamp = 2000,
      Tags = {
        ['Cheese-Mint-Id'] = testCheeseMintId,
        ['Cheese-Mint-Name'] = 'Updated Name'
      }
    }

    assert.has_error(function() handler.handle(msg) end, 'Permission Denied')
  end)
end)

describe('Remove-Cheese-Mint', function ()
  local handler
  local testCheeseMintId = 'test-cheese-mint-1'
  local testAddress = 'test-address-1'

  before_each(function()
    CacheOriginalGlobals()
    _G.send = spy.new(function() end)
    resetGlobalsAndRequire()
    handler = GetHandler('Remove-Cheese-Mint')

    -- Create a cheese mint to remove
    cheese_mints_by_id[testCheeseMintId] = createTestCheeseMint(testCheeseMintId)
  end)

  after_each(function()
    RestoreOriginalGlobals()
    _G.send = spy.new(function() end)
    package.loaded[codepath] = nil
    _G.cheese_mints_by_id = nil
    _G.cheese_mints_by_address = nil
    _G.cheese_mint_collection_initialized = nil
  end)

  it('should remove a cheese mint', function ()
    local msg = {
      Id = 'remove-msg-id',
      From = Owner,
      Timestamp = 2000,
      Tags = {
        ['Cheese-Mint-Id'] = testCheeseMintId
      }
    }

    handler.handle(msg)

    assert.is_nil(cheese_mints_by_id[testCheeseMintId])
  end)

  it('should also remove cheese mint from all awarded addresses', function ()
    -- Award the cheese mint to an address first
    cheese_mints_by_address[testAddress] = {
      [testCheeseMintId] = {
        awarded_by = Owner,
        awarded_at = 1500,
        message_id = 'award-msg'
      }
    }

    local msg = {
      Id = 'remove-msg-id',
      From = Owner,
      Timestamp = 2000,
      Tags = {
        ['Cheese-Mint-Id'] = testCheeseMintId
      }
    }

    handler.handle(msg)

    assert.is_nil(cheese_mints_by_id[testCheeseMintId])
    assert.is_nil(cheese_mints_by_address[testAddress][testCheeseMintId])
  end)

  it('should fail for non-existent cheese mint', function ()
    local msg = {
      Id = 'remove-msg-id',
      From = Owner,
      Timestamp = 2000,
      Tags = {
        ['Cheese-Mint-Id'] = 'non-existent-id'
      }
    }

    assert.has_error(function() handler.handle(msg) end, 'Cheese Mint does not exist: non-existent-id')
  end)

  it('should enforce ACL permissions', function ()
    local msg = {
      Id = 'remove-msg-id',
      From = 'unauthorized-user',
      Timestamp = 2000,
      Tags = {
        ['Cheese-Mint-Id'] = testCheeseMintId
      }
    }

    assert.has_error(function() handler.handle(msg) end, 'Permission Denied')
  end)
end)

describe('Award-Cheese-Mint', function ()
  local handler
  local testCheeseMintId = 'test-cheese-mint-1'
  local testAddress = 'test-address-1'

  before_each(function()
    CacheOriginalGlobals()
    _G.send = spy.new(function() end)
    resetGlobalsAndRequire()
    handler = GetHandler('Award-Cheese-Mint')

    -- Create a cheese mint to award
    cheese_mints_by_id[testCheeseMintId] = createTestCheeseMint(testCheeseMintId)
  end)

  after_each(function()
    RestoreOriginalGlobals()
    _G.send = spy.new(function() end)
    package.loaded[codepath] = nil
    _G.cheese_mints_by_id = nil
    _G.cheese_mints_by_address = nil
    _G.cheese_mint_collection_initialized = nil
  end)

  it('should award a cheese mint to an address', function ()
    local msg = {
      Id = 'award-msg-id',
      From = Owner,
      Timestamp = 2000,
      Tags = {
        ['Cheese-Mint-Id'] = testCheeseMintId,
        ['Award-To-Address'] = testAddress
      }
    }

    handler.handle(msg)

    assert.is_not_nil(cheese_mints_by_address[testAddress])
    assert.is_not_nil(cheese_mints_by_address[testAddress][testCheeseMintId])
    assert.equals(Owner, cheese_mints_by_address[testAddress][testCheeseMintId].awarded_by)
    assert.equals(2000, cheese_mints_by_address[testAddress][testCheeseMintId].awarded_at)
    assert.equals('award-msg-id', cheese_mints_by_address[testAddress][testCheeseMintId].message_id)
  end)

  it('should fail for non-existent cheese mint', function ()
    local msg = {
      Id = 'award-msg-id',
      From = Owner,
      Timestamp = 2000,
      Tags = {
        ['Cheese-Mint-Id'] = 'non-existent-id',
        ['Award-To-Address'] = testAddress
      }
    }

    assert.has_error(function() handler.handle(msg) end, 'Cheese Mint does not exist: non-existent-id')
  end)

  it('should fail for invalid address', function ()
    local msg = {
      Id = 'award-msg-id',
      From = Owner,
      Timestamp = 2000,
      Tags = {
        ['Cheese-Mint-Id'] = testCheeseMintId,
        ['Award-To-Address'] = ''
      }
    }

    assert.has_error(function() handler.handle(msg) end, 'Address cannot be empty')
  end)

  it('should fail for duplicate award', function ()
    -- Award the cheese mint first
    cheese_mints_by_address[testAddress] = {
      [testCheeseMintId] = {
        awarded_by = 'someone',
        awarded_at = 1000,
        message_id = 'old-msg'
      }
    }

    local msg = {
      Id = 'award-msg-id',
      From = Owner,
      Timestamp = 2000,
      Tags = {
        ['Cheese-Mint-Id'] = testCheeseMintId,
        ['Award-To-Address'] = testAddress
      }
    }

    assert.has_error(function() handler.handle(msg) end, 'Address already has Cheese Mint with id ' .. testCheeseMintId)
  end)

  it('should enforce ACL permissions', function ()
    local msg = {
      Id = 'award-msg-id',
      From = 'unauthorized-user',
      Timestamp = 2000,
      Tags = {
        ['Cheese-Mint-Id'] = testCheeseMintId,
        ['Award-To-Address'] = testAddress
      }
    }

    assert.has_error(function() handler.handle(msg) end, 'Permission Denied')
  end)
end)

describe('Revoke-Cheese-Mint', function ()
  local handler
  local testCheeseMintId = 'test-cheese-mint-1'
  local testAddress = 'test-address-1'

  before_each(function()
    CacheOriginalGlobals()
    _G.send = spy.new(function() end)
    resetGlobalsAndRequire()
    handler = GetHandler('Revoke-Cheese-Mint')

    -- Create a cheese mint
    cheese_mints_by_id[testCheeseMintId] = createTestCheeseMint(testCheeseMintId)
    -- Award it to an address
    cheese_mints_by_address[testAddress] = {
      [testCheeseMintId] = {
        awarded_by = Owner,
        awarded_at = 1500,
        message_id = 'award-msg'
      }
    }
  end)

  after_each(function()
    RestoreOriginalGlobals()
    _G.send = spy.new(function() end)
    package.loaded[codepath] = nil
    _G.cheese_mints_by_id = nil
    _G.cheese_mints_by_address = nil
    _G.cheese_mint_collection_initialized = nil
  end)

  it('should revoke a cheese mint from an address', function ()
    local msg = {
      Id = 'revoke-msg-id',
      From = Owner,
      Timestamp = 2000,
      Tags = {
        ['Cheese-Mint-Id'] = testCheeseMintId,
        ['Revoke-From-Address'] = testAddress
      }
    }

    handler.handle(msg)

    assert.is_nil(cheese_mints_by_address[testAddress][testCheeseMintId])
  end)

  it('should fail for non-existent cheese mint', function ()
    local msg = {
      Id = 'revoke-msg-id',
      From = Owner,
      Timestamp = 2000,
      Tags = {
        ['Cheese-Mint-Id'] = 'non-existent-id',
        ['Revoke-From-Address'] = testAddress
      }
    }

    assert.has_error(function() handler.handle(msg) end, 'Cheese Mint does not exist: non-existent-id')
  end)

  it('should fail for address without any cheese mints', function ()
    local msg = {
      Id = 'revoke-msg-id',
      From = Owner,
      Timestamp = 2000,
      Tags = {
        ['Cheese-Mint-Id'] = testCheeseMintId,
        ['Revoke-From-Address'] = 'address-without-mints'
      }
    }

    assert.has_error(function() handler.handle(msg) end, 'Address does not have any Cheese Mints')
  end)

  it('should fail for address without the specified cheese mint', function ()
    cheese_mints_by_address['other-address'] = {
      ['other-cheese-mint'] = {
        awarded_by = Owner,
        awarded_at = 1500,
        message_id = 'award-msg'
      }
    }
    cheese_mints_by_id['other-cheese-mint'] = createTestCheeseMint('other-cheese-mint')

    local msg = {
      Id = 'revoke-msg-id',
      From = Owner,
      Timestamp = 2000,
      Tags = {
        ['Cheese-Mint-Id'] = testCheeseMintId,
        ['Revoke-From-Address'] = 'other-address'
      }
    }

    assert.has_error(function() handler.handle(msg) end, 'Address does not have the specified Cheese Mint')
  end)

  it('should enforce ACL permissions', function ()
    local msg = {
      Id = 'revoke-msg-id',
      From = 'unauthorized-user',
      Timestamp = 2000,
      Tags = {
        ['Cheese-Mint-Id'] = testCheeseMintId,
        ['Revoke-From-Address'] = testAddress
      }
    }

    assert.has_error(function() handler.handle(msg) end, 'Permission Denied')
  end)
end)

describe('Update-Roles', function ()
  local json = require('json')
  local handler

  before_each(function()
    CacheOriginalGlobals()
    _G.send = spy.new(function() end)
    resetGlobalsAndRequire()
    handler = GetHandler('Update-Roles')
  end)

  after_each(function()
    RestoreOriginalGlobals()
    _G.send = spy.new(function() end)
    package.loaded[codepath] = nil
    _G.cheese_mints_by_id = nil
    _G.cheese_mints_by_address = nil
    _G.cheese_mint_collection_initialized = nil
  end)

  it('should grant roles', function ()
    local msg = {
      Id = 'update-roles-msg',
      From = Owner,
      Timestamp = 2000,
      Data = json.encode({
        Grant = {
          ['new-admin'] = { 'admin', 'Create-Cheese-Mint' }
        }
      })
    }

    handler.handle(msg)

    assert.is_not_nil(acl.state.roles['admin'])
    assert.is_true(acl.state.roles['admin']['new-admin'])
    assert.is_true(acl.state.roles['Create-Cheese-Mint']['new-admin'])
  end)

  it('should revoke roles', function ()
    -- First grant a role
    acl.state.roles['admin'] = { ['some-admin'] = true }

    local msg = {
      Id = 'update-roles-msg',
      From = Owner,
      Timestamp = 2000,
      Data = json.encode({
        Revoke = {
          ['some-admin'] = { 'admin' }
        }
      })
    }

    handler.handle(msg)

    assert.is_nil(acl.state.roles['admin']['some-admin'])
  end)

  it('should enforce ACL permissions', function ()
    local msg = {
      Id = 'update-roles-msg',
      From = 'unauthorized-user',
      Timestamp = 2000,
      Data = json.encode({
        Grant = {
          ['new-admin'] = { 'admin' }
        }
      })
    }

    assert.has_error(function() handler.handle(msg) end, 'Permission Denied')
  end)
end)

describe('View-Roles', function ()
  local json = require('json')
  local handler

  before_each(function()
    CacheOriginalGlobals()
    resetGlobalsAndRequire()
    handler = GetHandler('View-Roles')
    ao.outbox = { Messages = {}, Spawns = {}, Assignments = {} }
  end)

  after_each(function()
    RestoreOriginalGlobals()
    package.loaded[codepath] = nil
    _G.cheese_mints_by_id = nil
    _G.cheese_mints_by_address = nil
    _G.cheese_mint_collection_initialized = nil
  end)

  it('should return roles state', function ()
    acl.state.roles = { admin = { ['some-admin'] = true } }

    local msg = {
      Id = 'view-roles-msg',
      From = 'anyone',
      Timestamp = 2000
    }

    handler.handle(msg)

    assert.equals(1, #ao.outbox.Messages)
    assert.equals('View-Roles-Response', ao.outbox.Messages[1].Action)
  end)
end)

describe('View-State', function ()
  local json = require('json')
  local handler

  before_each(function()
    CacheOriginalGlobals()
    resetGlobalsAndRequire()
    handler = GetHandler('View-State')
    ao.outbox = { Messages = {}, Spawns = {}, Assignments = {} }
  end)

  after_each(function()
    RestoreOriginalGlobals()
    package.loaded[codepath] = nil
    _G.cheese_mints_by_id = nil
    _G.cheese_mints_by_address = nil
    _G.cheese_mint_collection_initialized = nil
  end)

  it('should return full state', function ()
    local msg = {
      Id = 'view-state-msg',
      From = 'anyone',
      Timestamp = 2000
    }

    handler.handle(msg)

    assert.equals(1, #ao.outbox.Messages)
    assert.equals('View-State-Response', ao.outbox.Messages[1].Action)
  end)
end)

describe('Get-Cheese-Mints-By-Address', function ()
  local json = require('json')
  local handler
  local testCheeseMintId = 'test-cheese-mint-1'
  local testAddress = 'test-address-1'

  before_each(function()
    CacheOriginalGlobals()
    resetGlobalsAndRequire()
    handler = GetHandler('Get-Cheese-Mints-By-Address')
    ao.outbox = { Messages = {}, Spawns = {}, Assignments = {} }

    -- Create a cheese mint and award it
    cheese_mints_by_id[testCheeseMintId] = createTestCheeseMint(testCheeseMintId)
    cheese_mints_by_address[testAddress] = {
      [testCheeseMintId] = {
        awarded_by = Owner,
        awarded_at = 1500,
        message_id = 'award-msg'
      }
    }
  end)

  after_each(function()
    RestoreOriginalGlobals()
    package.loaded[codepath] = nil
    _G.cheese_mints_by_id = nil
    _G.cheese_mints_by_address = nil
    _G.cheese_mint_collection_initialized = nil
  end)

  it('should return cheese mints for specified address', function ()
    local msg = {
      Id = 'get-by-address-msg',
      From = 'anyone',
      Timestamp = 2000,
      Tags = {
        ['Address'] = testAddress
      }
    }

    handler.handle(msg)

    assert.equals(1, #ao.outbox.Messages)
    assert.equals('Get-Cheese-Mints-By-Address-Response', ao.outbox.Messages[1].Action)
  end)

  it('should use msg.From when address not specified', function ()
    local msg = {
      Id = 'get-by-address-msg',
      From = testAddress,
      Timestamp = 2000,
      Tags = {}
    }

    handler.handle(msg)

    assert.equals(1, #ao.outbox.Messages)
    assert.equals('Get-Cheese-Mints-By-Address-Response', ao.outbox.Messages[1].Action)
  end)

  it('should return empty for address without cheese mints', function ()
    local msg = {
      Id = 'get-by-address-msg',
      From = 'anyone',
      Timestamp = 2000,
      Tags = {
        ['Address'] = 'address-without-mints'
      }
    }

    handler.handle(msg)

    assert.equals(1, #ao.outbox.Messages)
    assert.equals('Get-Cheese-Mints-By-Address-Response', ao.outbox.Messages[1].Action)
  end)
end)

describe('Info', function ()
  local json = require('json')
  local handler

  before_each(function()
    CacheOriginalGlobals()
    resetGlobalsAndRequire()
    handler = GetHandler('Info')
    ao.outbox = { Messages = {}, Spawns = {}, Assignments = {} }
  end)

  after_each(function()
    RestoreOriginalGlobals()
    package.loaded[codepath] = nil
    _G.cheese_mints_by_id = nil
    _G.cheese_mints_by_address = nil
    _G.cheese_mint_collection_initialized = nil
  end)

  it('should return info response', function ()
    local msg = {
      Id = 'info-msg',
      From = 'anyone',
      Timestamp = 2000
    }

    handler.handle(msg)

    assert.equals(1, #ao.outbox.Messages)
    assert.equals('Info-Response', ao.outbox.Messages[1].Action)
  end)
end)