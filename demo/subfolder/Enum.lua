--- Simple Enum class.
--- This class is used to demonstrate the lovecase module.
--- @class lovecase.demo.Enum: { [string]: string|number }
local Enum = {}
Enum.__index = Enum

--- Return a new Enum instance with the specified cases.
--- @param cases table A table that represents the available enum cases
--- @return lovecase.demo.Enum
--- @nodiscard
function Enum.new(cases)
  assert(type(cases) == "table", "Enum constructor requires a table")

  local enum = {}

  for key, value in pairs(cases) do
    if type(key) == "string" then
      enum[key] = value
    elseif type(key) == "number" and type(value) == "string" then
      enum[value] = key
    else
      error("Enum keys must be strings")
    end
  end

  setmetatable(enum, Enum)
  return enum
end

--- Get the case of the specified value.
--- @param value any
--- @return string? The case or nil
--- @nodiscard
function Enum:caseOf(value)
  for case, v in pairs(self) do
    if v == value then
      return case
    end
  end
  return nil
end

--- Get the number of enum values.
--- @return integer
--- @nodiscard
function Enum:length()
  local length = 0
  for _ in pairs(self) do
    length = length + 1
  end
  return length
end

--- Assert that the enum contains a given value.
--- @param value any
--- @return any value The input value
function Enum:assert(value)
  if not self:caseOf(value) then
    error("Enum has no case with this value: " .. value)
  end
  return value
end

--- @return string
function Enum:__newindex()
  error("Enum is read-only")
end

return Enum