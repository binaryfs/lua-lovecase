local BASE = (...):gsub("%.TestSet$", "")
local helpers = require(BASE .. ".helpers")
local serial = require(BASE .. ".serial")
local TestReport = require(BASE .. ".TestReport")

--- @alias lovecase.EqualityCheck fun(a: any, b: any, almost: boolean): boolean
--- @alias lovecase.TypeCheck fun(t: table): string|false

--- Represents a collection of test results and sub groups.
--- @class lovecase.TestGroup
--- @field name string
--- @field failed boolean True if one of the contained tests or sub groups failed
--- @field results lovecase.TestResult[]
--- @field subgroups lovecase.TestGroup[]

--- Represents the result of a single test case.
--- @class lovecase.TestResult
--- @field name string
--- @field failed boolean
--- @field error string

--- The TestSet class represents a collection of test cases.
--- @class lovecase.TestSet
--- @field protected _groupStack lovecase.TestGroup[]
--- @field protected _typeChecks lovecase.TypeCheck[]
--- @field protected _equalityChecks table<string, lovecase.EqualityCheck>
local TestSet = {}
TestSet.__index = TestSet

--- Create a new test set.
--- @param name string The name of the test set
--- @return lovecase.TestSet
--- @nodiscard
function TestSet.new(name)
  if type(name) ~= "string" or name == "" then
    error("Please name your TestSet")
  end

  --- @type lovecase.TestSet
  local instance = setmetatable({
    _groupStack = {},
    _typeChecks = {},
    _equalityChecks = {},
  }, TestSet)

  instance:_pushGroup(name)
  return instance
end

--- Determine if the given value is an instance of the TestSet class.
--- @param value any
--- @return boolean
--- @nodiscard
function TestSet.isInstance(value)
  return type(value) == "table" and getmetatable(value) == TestSet
end

--- Add an equality function for a custom type.
---
--- The equality function takes two arguments and should return true if the values
--- are considered equal.
---
--- Usage:
--- ```
--- test:addEqualityCheck("Point", function(p1, p2)
---   return p1.x == p2.x and p1.y == p2.y
--- end)
--- ```
--- @param typename string The type identifier, determined by the type checker.
--- @param func lovecase.EqualityCheck The equality function. 
function TestSet:addEqualityCheck(typename, func)
  helpers.assertArgument(1, typename, "string")
  helpers.assertArgument(2, func, "function")
  self._equalityChecks[typename] = func
end

--- Add a custom type checking function to determine the type of custom tables.
---
--- The type checking function expects a table whose type is to be determined and should
--- return the type identifier if successful and false otherwise.
---
--- Usage:
--- ```
--- test:addTypeCheck(function(value)
---   return Point.isInstance(value) and "Point" or false
--- end)
--- ```
--- @param func lovecase.TypeCheck The type checking function
function TestSet:addTypeCheck(func)
  helpers.assertArgument(1, func, "function")
  table.insert(self._typeChecks, func)
end

--- Add a named test group.
--- @param groupName string The group name
--- @param groupFunc function A function that contains the grouped test cases
function TestSet:group(groupName, groupFunc)
  helpers.assertArgument(1, groupName, "string")
  helpers.assertArgument(2, groupFunc, "function")

  self:_pushGroup(groupName)
  groupFunc()
  self:_popGroup()
end

--- Run the specified test with optional test data.
---
--- When specified, `testData` is expected to be a sequence of tables. The values of
--- each table are unpacked and passed to the test function.
--- @param testName string The name of the test
--- @param testFunc fun(...: any) A function that provides the test
--- @param testData? table[] Optional test data for the test
function TestSet:run(testName, testFunc, testData)
  helpers.assertArgument(1, testName, "string")
  helpers.assertArgument(2, testFunc, "function")

  local passed, message

  if testData then
    helpers.assertArgument(3, testData, "table")
    for i = 1, #testData do
      passed, message = pcall(testFunc, unpack(testData[i]))
      if not passed then
        break
      end
    end
  else
    passed, message = pcall(testFunc)
  end

  --- @type lovecase.TestResult
  local result = {
    name = testName,
    failed = not passed,
    error = message
  }

  table.insert(self:_peekGroup().results, result)

  if result.failed then
    self:_markAsFailed()
  end
end

--- Assert that the given value is true.
--- @param value any
--- @param message? string The message to show if the assertion fails
function TestSet:assertTrue(value, message)
  self:assertSame(value, true, message)
end

--- Assert that the given value is false.
--- @param value any
--- @param message? string The message to show if the assertion fails
function TestSet:assertFalse(value, message)
  self:assertSame(value, false, message)
end

--- Assert that a given value is equal to an expected value.
--- @param value any
--- @param expectedValue any
--- @param message? string The message to show if the assertion fails
function TestSet:assertEqual(value, expectedValue, message)
  if not self:_compareValues(value, expectedValue) then
    error(string.format(
      message or "Actual value: %s | Expected value: %s",
      serial.serialize(value),
      serial.serialize(expectedValue)
    ), 0)
  end
end

--- Assert that a given value is not equal to another value.
--- @param first any
--- @param second any
--- @param message? string The message to show if the assertion fails
function TestSet:assertNotEqual(first, second, message)
  if self:_compareValues(first, second) then
    error(message or string.format(
      "Both values are equal: %s",
      serial.serialize(first)
    ), 0)
  end
end

--- Assert that a given value is almost equal to an expected value.
--- @param value any
--- @param expectedValue any
--- @param message? string The message to show if the assertion fails
function TestSet:assertAlmostEqual(value, expectedValue, message)
  if not self:_compareValues(value, expectedValue, true) then
    error(string.format(
      message or "Actual value: %s | Expected value: %s",
      serial.serialize(value),
      serial.serialize(expectedValue)
    ), 0)
  end
end

--- Assert that two values are not almost equal.
--- @param first any
--- @param second any
--- @param message? string The message to show if the assertion fails
function TestSet:assertNotAlmostEqual(first, second, message)
  if self:_compareValues(first, second, true) then
    error(string.format(
      message or "Both values are almost equal: %s | %s",
      serial.serialize(first),
      serial.serialize(second)
    ), 0)
  end
end

--- Assert that a given value is the same as the expected value.
--- @param value any
--- @param expectedValue any
--- @param message? string The message to show if the assertion fails
function TestSet:assertSame(value, expectedValue, message)
  if not rawequal(value, expectedValue) then
    error(string.format(
      message or "Actual value: %s | Expected value: %s",
      tostring(value),
      tostring(expectedValue)
    ), 0)
  end
end

--- Assert that a given value is not the same as the expected value.
--- @param first any
--- @param second any
--- @param message? string The message to show if the assertion fails
function TestSet:assertNotSame(first, second, message)
  if rawequal(first, second) then
    error(string.format(
      message or "Both values are the same: %s",
      tostring(first)
    ), 0)
  end
end

--- Assert that the given function throws an error when called.
--- @param func function The function
--- @param message? string The message to show if the assertion fails
function TestSet:assertError(func, message)
  if pcall(func) then
    error(message or "The function was expected to throw an error", 0)
  end
end

--- Write the test results into the given report.
--- @param report lovecase.TestReport The report
--- @return lovecase.TestReport # The report
function TestSet:writeReport(report)
  assert(TestReport.isInstance(report), "TestReport expected, got " .. type(report))
  self:_writeReport(report, self._groupStack[1])
  return report
end

--- Get a string representation of the test set.
--- @return string
function TestSet:__tostring()
  return string.format("<TestSet '%s' (%s)>", self._groupStack[1].name, helpers.rawtostring(self))
end

--- Internal function to write a report.
--- @param report lovecase.TestReport The report
--- @param group lovecase.TestGroup The current test group to write into the report
--- @protected
function TestSet:_writeReport(report, group)
  report:addGroup(group.name, group.failed, function()
    for _, result in ipairs(group.results) do
      report:addResult(result.name, result.failed, result.error)
    end
    for _, subgroup in ipairs(group.subgroups) do
      self:_writeReport(report, subgroup)
    end
  end)
end

--- Test if the two given values are equal.
---
--- The equality operator == is used to compare the values. If both values
--- have the same type and there is an equality function available
--- for this type, the equality function is used instead. 
--- @param first any
--- @param second any
--- @param almost boolean? If true, compare numbers with tolerance (default: false)
--- @return boolean equal
--- @nodiscard
--- @protected
function TestSet:_compareValues(first, second, almost)
  local firstType = self:_determineType(first)

  if type(first) == "table"
    and firstType == self:_determineType(second)
    and self._equalityChecks[firstType]
  then
    return self._equalityChecks[firstType](first, second, almost == true)
  end

  return helpers.compareValues(first, second, almost == true)
end

--- Determine the type of the given value.
---
--- If none of the registered type checks can determine the type, the type()
--- function of Lua is used as a fallback.
--- @param value any
--- @return string type
--- @nodiscard
--- @protected
function TestSet:_determineType(value)
  local typeOfValue = type(value)
  if typeOfValue == "table" then
    -- Check if this table is a custom type.
    for _, typeCheck in ipairs(self._typeChecks) do
      local result = typeCheck(value)
      if result then
        return result
      end
    end
  end
  return typeOfValue
end

--- Push a new group onto the stack.
--- @param groupName string The name of the group
--- @protected
function TestSet:_pushGroup(groupName)
  --- @type lovecase.TestGroup
  local newGroup = {
    name = groupName,
    failed = false,
    results = {},
    subgroups = {}
  }

  if #self._groupStack > 0 then
    table.insert(self:_peekGroup().subgroups, newGroup)
  end

  self._groupStack[#self._groupStack + 1] = newGroup
end

--- Remove the topmost group from the stack.
--- @protected
function TestSet:_popGroup()
  assert(table.remove(self._groupStack), "Cannot pop empty stack")
end

--- Get the topmost group from the stack.
--- @return table # The topmost group
--- @protected
function TestSet:_peekGroup()
  return self._groupStack[#self._groupStack]
end

--- Mark all groups on the stack as failed.
--- @protected
function TestSet:_markAsFailed()
  for i = #self._groupStack, 1, -1 do
    self._groupStack[i].failed = true
  end
end

return TestSet