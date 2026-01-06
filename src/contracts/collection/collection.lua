cheese_mint_collection_initialized = cheese_mint_collection_initialized or false
cheese_mints_by_id = cheese_mints_by_id or {}
cheese_mints_by_address = cheese_mints_by_address or {}
acl = require('..common.acl')

function assertValidCheeseMintName(name)
  assert(name ~= nil, 'Cheese Mint name is required')
  assert(type(name) == 'string', 'Cheese Mint name must be a string')
  assert(name ~= '', 'Cheese Mint name cannot be empty')
  assert(name:len() <= 250, 'Cheese Mint name cannot exceed 250 characters')
end

function assertValidCheeseMintDescription(description)
  assert(description ~= nil, 'Cheese Mint description is required')
  assert(type(description) == 'string', 'Cheese Mint description must be a string')
  assert(description ~= '', 'Cheese Mint description cannot be empty')
  assert(description:len() <= 1000, 'Cheese Mint description cannot exceed 1000 characters')
end

function assertValidCheeseMintPoints(points)
  assert(points ~= nil, 'Cheese Mint points are required')
  assert(type(points) == 'number', 'Cheese Mint points must be a number')
  assert(points >= 0, 'Cheese Mint points cannot be negative')
  assert(points < math.maxinteger, 'Cheese Mint points cannot exceed maximum integer value')
end

function assertValidCheeseMintId(cheeseMintId)
  assert(cheeseMintId ~= nil, 'Cheese Mint ID is required')
  assert(type(cheeseMintId) == 'string', 'Cheese Mint ID must be a string')
  assert(cheeseMintId ~= '', 'Cheese Mint ID cannot be empty')
  assert(cheese_mints_by_id[cheeseMintId] ~= nil, 'Cheese Mint does not exist: ' .. tostring(cheeseMintId))
end

function assertValidAddress(address)
  -- TODO -> Could detect address type & perform stricter validation
  assert(address ~= nil, 'Address is required')
  assert(type(address) == 'string', 'Address must be a string')
  assert(address ~= '', 'Address cannot be empty')
end

function assertValidCheeseMintIcon(icon)
  assert(icon ~= nil, 'Cheese Mint icon is required')
  assert(type(icon) == 'string', 'Cheese Mint icon must be a string')
  assert(icon ~= '', 'Cheese Mint icon cannot be empty')
  assert(icon:len() == 43, 'Cheese Mint icon must be 43 char arweave txid')
  -- TODO -> could validate txid further & allow ar:// style links
end

function assertValidCheeseMintCategory(category)
  assert(category ~= nil, 'Cheese Mint category is required')
  assert(type(category) == 'string', 'Cheese Mint category must be a string')
  assert(category ~= '', 'Cheese Mint category cannot be empty')
  assert(category:len() <= 100, 'Cheese Mint category cannot exceed 100 characters')
end

-- Award helper functions to reduce duplication between single and bulk award handlers

function assertCanAwardCheeseMint(cheeseMintId, address, errorPrefix)
  errorPrefix = errorPrefix or ''
  assertValidCheeseMintId(cheeseMintId)
  assertValidAddress(address)

  local existingAwards = cheese_mints_by_address[address]
  assert(
    existingAwards == nil or existingAwards[cheeseMintId] == nil,
    errorPrefix .. 'Address already has Cheese Mint with id ' .. tostring(cheeseMintId)
  )
end

function applyAward(cheeseMintId, address, awardedBy, awardedAt, messageId)
  cheese_mints_by_address[address] = cheese_mints_by_address[address] or {}
  cheese_mints_by_address[address][cheeseMintId] = {
    awarded_by = awardedBy,
    awarded_at = awardedAt,
    message_id = messageId
  }
end

Handlers.add('Update-Roles', 'Update-Roles', function (msg)
  local json = require('json')

  acl.utils.assertHasOneOfRole(msg.From, { 'owner', 'admin', 'Update-Roles' })

  acl.utils.updateRoles(json.decode(msg.Data))

  ao.send({
    Target = msg.From,
    Action = 'Update-Roles-Response',
    Data = 'OK'
  })
  ao.send({
    device = 'patch@1.0',
    acl = acl.state
  })
end)

Handlers.add('View-Roles', 'View-Roles', function (msg)
  local json = require('json')

  ao.send({
    Target = msg.From,
    Action = 'View-Roles-Response',
    Data = json.encode(acl.state)
  })
end)

Handlers.add('Create-Cheese-Mint', 'Create-Cheese-Mint', function (msg)
  acl.utils.assertHasOneOfRole(msg.From, { 'owner', 'admin', 'Create-Cheese-Mint' })

  local cheeseMintId = msg.Id
  local cheeseMintCreatedBy = msg.From
  local cheeseMintName = msg.Tags['Cheese-Mint-Name']
  assertValidCheeseMintName(cheeseMintName)
  local cheeseMintDescription = msg.Tags['Description']
  assertValidCheeseMintDescription(cheeseMintDescription)
  local cheeseMintPoints = tonumber(msg.Tags['Points']) or 0
  assertValidCheeseMintPoints(cheeseMintPoints)
  local cheeseMintIcon = msg.Tags['Icon']
  assertValidCheeseMintIcon(cheeseMintIcon)
  local cheeseMintCategory = msg.Tags['Category'] or 'default'
  assertValidCheeseMintCategory(cheeseMintCategory)

  cheese_mints_by_id[cheeseMintId] = {
    id = cheeseMintId,
    created_at = msg.Timestamp,
    created_by = cheeseMintCreatedBy,
    name = cheeseMintName,
    description = cheeseMintDescription,
    points = cheeseMintPoints,
    icon = cheeseMintIcon,
    category = cheeseMintCategory
  }

  ao.send({
    Target = msg.From,
    Action = 'Cheese-Mint-Created',
    Data = 'OK',
    ['Cheese-Mint-Id'] = cheeseMintId
  })
  ao.send({
    device = 'patch@1.0',
    cheese_mints_by_id = cheese_mints_by_id
  })
end)

Handlers.add('Update-Cheese-Mint', 'Update-Cheese-Mint', function (msg)
  acl.utils.assertHasOneOfRole(msg.From, { 'owner', 'admin', 'Update-Cheese-Mint' })

  local cheeseMintId = msg.Tags['Cheese-Mint-Id']
  assertValidCheeseMintId(cheeseMintId)
  local cheeseMintUpdatedBy = msg.From
  local cheeseMintName = msg.Tags['Cheese-Mint-Name'] or cheese_mints_by_id[cheeseMintId].name
  assertValidCheeseMintName(cheeseMintName)
  local cheeseMintDescription = msg.Tags['Description'] or cheese_mints_by_id[cheeseMintId].description
  assertValidCheeseMintDescription(cheeseMintDescription)
  local cheeseMintPoints = tonumber(msg.Tags['Points']) or cheese_mints_by_id[cheeseMintId].points or 0
  assertValidCheeseMintPoints(cheeseMintPoints)
  local cheeseMintIcon = msg.Tags['Icon'] or cheese_mints_by_id[cheeseMintId].icon
  assertValidCheeseMintIcon(cheeseMintIcon)
  local cheeseMintCategory = msg.Tags['Category'] or cheese_mints_by_id[cheeseMintId].category
  assertValidCheeseMintCategory(cheeseMintCategory)

  local created_at = cheese_mints_by_id[cheeseMintId].created_at
  local created_by = cheese_mints_by_id[cheeseMintId].created_by

  cheese_mints_by_id[cheeseMintId] = {
    id = cheeseMintId,
    created_at = created_at,
    created_by = created_by,
    updated_at = msg.Timestamp,
    updated_by = cheeseMintUpdatedBy,
    name = cheeseMintName,
    description = cheeseMintDescription,
    points = cheeseMintPoints,
    icon = cheeseMintIcon,
    category = cheeseMintCategory
  }

  ao.send({
    Target = msg.From,
    Action = 'Cheese-Mint-Updated',
    Data = 'OK',
    ['Cheese-Mint-Id'] = cheeseMintId
  })
  ao.send({
    device = 'patch@1.0',
    cheese_mints_by_id = cheese_mints_by_id
  })
end)

Handlers.add('Remove-Cheese-Mint', 'Remove-Cheese-Mint', function (msg)
  acl.utils.assertHasOneOfRole(msg.From, { 'owner', 'admin', 'Remove-Cheese-Mint' })

  local cheeseMintId = msg.Tags['Cheese-Mint-Id']
  assertValidCheeseMintId(cheeseMintId)

  cheese_mints_by_id[cheeseMintId] = nil

  for address in pairs(cheese_mints_by_address) do
    if cheese_mints_by_address[address][cheeseMintId] ~= nil then
      cheese_mints_by_address[address][cheeseMintId] = nil
    end
  end

  ao.send({
    Target = msg.From,
    Action = 'Cheese-Mint-Removed',
    Data = 'OK',
    ['Cheese-Mint-Id'] = cheeseMintId
  })
  ao.send({
    device = 'patch@1.0',
    cheese_mints_by_id = cheese_mints_by_id,
    cheese_mints_by_address = cheese_mints_by_address
  })
end)

Handlers.add('Award-Cheese-Mint', 'Award-Cheese-Mint', function (msg)
  acl.utils.assertHasOneOfRole(msg.From, { 'owner', 'admin', 'Award-Cheese-Mint' })

  local cheeseMintId = msg.Tags['Cheese-Mint-Id']
  local awardToAddress = msg.Tags['Award-To-Address']

  assertCanAwardCheeseMint(cheeseMintId, awardToAddress)
  applyAward(cheeseMintId, awardToAddress, msg.From, msg.Timestamp, msg.Id)

  ao.send({
    Target = msg.From,
    Action = 'Cheese-Mint-Awarded',
    Data = 'OK',
    ['Cheese-Mint-Id'] = cheeseMintId,
    ['Award-To-Address'] = awardToAddress,
    ['Awarded-At'] = tostring(msg.Timestamp)
  })
  ao.send({
    device = 'patch@1.0',
    cheese_mints_by_address = cheese_mints_by_address
  })
end)

Handlers.add('Bulk-Award-Cheese-Mint', 'Bulk-Award-Cheese-Mint', function (msg)
  local json = require('json')

  acl.utils.assertHasOneOfRole(msg.From, { 'owner', 'admin', 'Award-Cheese-Mint', 'Bulk-Award-Cheese-Mint' })

  local data = json.decode(msg.Data)
  assert(data ~= nil, 'Request body is required')
  assert(data.awards ~= nil, 'Awards array is required')
  assert(type(data.awards) == 'table', 'Awards must be an array')
  assert(#data.awards > 0, 'Awards array cannot be empty')

  -- Validate all awards first (fail-fast, without mutating state)
  for i, award in ipairs(data.awards) do
    assert(award.cheeseMintId ~= nil, 'Award #' .. i .. ': cheeseMintId is required')
    assert(award.address ~= nil, 'Award #' .. i .. ': address is required')
    assertCanAwardCheeseMint(award.cheeseMintId, award.address, 'Award #' .. i .. ': ')
  end

  -- Apply all awards
  for _, award in ipairs(data.awards) do
    applyAward(award.cheeseMintId, award.address, msg.From, msg.Timestamp, msg.Id)
  end

  ao.send({
    Target = msg.From,
    Action = 'Bulk-Cheese-Mint-Awarded',
    Data = 'OK',
    ['Awards-Count'] = tostring(#data.awards),
    ['Awarded-At'] = tostring(msg.Timestamp)
  })
  ao.send({
    device = 'patch@1.0',
    cheese_mints_by_address = cheese_mints_by_address
  })
end)

Handlers.add('Revoke-Cheese-Mint', 'Revoke-Cheese-Mint', function (msg)
  acl.utils.assertHasOneOfRole(msg.From, { 'owner', 'admin', 'Revoke-Cheese-Mint' })

  local cheeseMintId = msg.Tags['Cheese-Mint-Id']
  assertValidCheeseMintId(cheeseMintId)
  local revokeFromAddress = msg.Tags['Revoke-From-Address']
  assertValidAddress(revokeFromAddress)
  assert(
    cheese_mints_by_address[revokeFromAddress] ~= nil,
    'Address does not have any Cheese Mints'
  )
  assert(
    cheese_mints_by_address[revokeFromAddress][cheeseMintId] ~= nil,
    'Address does not have the specified Cheese Mint'
  )

  cheese_mints_by_address[revokeFromAddress][cheeseMintId] = nil

  ao.send({
    Target = msg.From,
    Action = 'Cheese-Mint-Awarded',
    Data = 'OK',
    ['Cheese-Mint-Id'] = cheeseMintId,
    ['Revoke-From-Address'] = revokeFromAddress,
    ['Revoked-At'] = tostring(msg.Timestamp)
  })
  ao.send({
    device = 'patch@1.0',
    cheese_mints_by_address = cheese_mints_by_address
  })
end)

Handlers.add('View-State', 'View-State', function (msg)
  local json = require('json')
  ao.send({
    Target = msg.From,
    Action = 'View-State-Response',
    Data = json.encode({
      cheese_mints_by_id = cheese_mints_by_id,
      cheese_mints_by_address = cheese_mints_by_address,
      acl = acl.state,
      owner = Owner
    })
  })
end)

Handlers.add('Get-Cheese-Mints-By-Address', 'Get-Cheese-Mints-By-Address', function (msg)
  local json = require('json')
  local address = msg.Tags['Address'] or msg.From
  assertValidAddress(address)

  ao.send({
    Target = msg.From,
    Action = 'Get-Cheese-Mints-By-Address-Response',
    Data = json.encode({
      cheese_mints_by_address = cheese_mints_by_address[address] or {},
      cheese_mints_by_id = cheese_mints_by_id
    })
  })
end)

Handlers.add('Info', 'Info', function (msg)
  local json = require('json')
  ao.send({
    Target = msg.From,
    Action = 'Info-Response',
    Data = json.encode({
      acl = acl.state,
      owner = Owner,
      cheese_mints_by_id = cheese_mints_by_id
    })
  })
end)

if not cheese_mint_collection_initialized then
  cheese_mint_collection_initialized = true
end
