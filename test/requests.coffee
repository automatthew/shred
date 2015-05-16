assert = require "assert"

{type} = require "fairmont"
{resource} = require "../src/shred"

module.exports = (context) ->
  context.test "Make a request with an empty body.", (context) ->
    repo =
      resource "https://api.github.com/repos/pandastrike/shred/issues",
        list:
          method: "get"
          headers:
            accept: "application/vnd.github.v3.raw+json"
          expect: 200

    {data} = yield repo.list()
    assert.equal type(yield data), "array"


  context.test "Make a request that passes a string body to the handler.", (context) ->
    repo =
      resource "https://api.github.com/repos/pandastrike/shred/issues",
        list:
          method: "get"
          headers:
            accept: "application/vnd.github.v3.raw+json"
          expect: 200

    {data} = yield repo.list "'assignee': 'none'"
    assert.equal type(yield data), "array"


  context.test "Make a request that passes an object body to the handler.", (context) ->
    repo =
      resource "https://api.github.com/repos/pandastrike/shred/issues",
        list:
          method: "get"
          headers:
            accept: "application/vnd.github.v3.raw+json"
          expect: 200

    {data} = yield repo.list
      assignee: "none"
      state: "all"
    assert.equal type(yield data), "array"


  # TODO: These tests need to be written.
  context.test "Make a request that passes a stream body to the handler."
  context.test "Make an authorized request"
