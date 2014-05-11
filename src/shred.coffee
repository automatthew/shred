{include, type} = require "fairmont"
{EventChannel} = require "mutual"
url = require "url"
parse_url = url.parse
resolve = url.resolve
querystring = require "querystring"
schemes =
  http: require "http"
  https: require "https"

class Method
  constructor: (@resource, {@method, @headers, @expect}) ->
    # load version from file instead of hard-coding
    @headers["user-agent"] ?= "shred v0.9.0"
    @expect = [ @expect ] unless type(@expect) is "array"

  request: (body=null) ->
    @resource.events.source (events) =>
      events.pipe = (pipe) -> @_pipe = pipe
      if body?
        unless type(body) is "string"
          body = JSON.stringify(body)
      events.safely =>
        handler = (response) =>
          events.safely =>
            if response.statusCode in @expect
              expected response
            else if response.statusCode in [ 301, 302, 303, 305, 307 ]
              request(response.headers.location)
            else
              unexpected response

        expected = (response) =>
          events.emit "success", response
          read response

        unexpected = (response) =>
          {statusCode} = response
          events.emit "error",
            new Error "Expected #{@expect}, got #{statusCode}"
          read response

        read = (response) =>
          stream = switch response.headers["content-encoding"]
            when 'gzip'
              zlib = require "zlib"
              response.pipe zlib.createGunzip()
            when 'deflate'
              zlib = require "zlib"
              response.pipe zlib.createInflate()
            else
              response

          data = ""
          if events._pipe?
            stream.pipe events._pipe
          else
            if response.statusCode in @expect
              response.on "ready", (data) ->
                events.emit "ready", data
            stream.on "data", (chunk) -> data += chunk
            stream.on "end", ->
              # TODO: this is not a safe way to check for a JSON
              # content-type. We should also make the parser
              # extensible.
              if response.headers["content-type"]?.match(/json/)
                data = JSON.parse(data)
              # TODO: Consider using a separate event channel for this?
              response.emit "ready", data

        request = (url) =>
          # TODO: Check for a null or invalid URL
          {protocol, hostname, port, path} = parse_url url
          scheme = protocol[0..-2] # remove trailing :
          schemes[scheme]
          .request
            hostname: hostname
            port: port || (if scheme is 'https' then 443 else 80)
            path: path
            method: @method.toUpperCase()
            headers: @headers
          .on "response", handler
          .on "error", (error) =>
            events.emit "error", error
          .end(body)

        request @resource.url

reserved = ["url", "events"]
class Resource

  constructor: (@url, @events = new EventChannel) ->

  resource: (path, events = @events.source()) ->
    new Resource(resolve(@url, path), events)

  query: (query, events = @events.source()) ->
    query = querystring.stringify(query)
    resource = new Resource("#{@url}?#{query}", events)
    for key, value of @ when (value.method instanceof Method)
      resource[key] = value
    resource

  describe: (actions) ->
    for action, description of actions when action not in reserved
      do (method = new Method(@, description)) =>
        @[action] = (args...) -> method.request(args...)
        @[action].method = method
    @

resource = (args...) -> new Resource(args...)

module.exports = {resource}
