
--[[
  *** Lua interface for diffbot API ***

  Please check README.md for details and examples.
]]

local m = {version = ('Diffbot/0.1 (%s)'):format(_VERSION)}

local json = require 'dkjson'
local url = require 'socket.url'
local url_escape = function (s) local v = url.escape(s); return v end
local http = require 'socket.http'
local tconcat = table.concat

-- Try to load Seawolf library
do
  local _
  loaded, value = pcall(require, 'seawolf.variable')
  if loaded then
    m.debug = value
  end
end

-- Compute the difference in seconds between local time and UTC.
-- Copied from: http://lua-users.org/wiki/TimeZone
local function get_timezone()
  local now = os.time()
  return os.difftime(now, os.time(os.date("!*t", now)))
end

-- Return a timezone string in ISO 8601:2000 standard form (+hhmm or -hhmm)
-- Copied from: http://lua-users.org/wiki/TimeZone
local function get_tzoffset(timezone)
  local h, m = math.modf(timezone / 3600)
  return string.format("%+.4d", 100 * h + 60 * m)
end

-- our logging functions
local function date_time(t)
  return os.date(t.dateformat, os.time())
end

local function dolog(t, msg)
  if t.logfile ~= nil then
    local fh = io.open(t.logfile, 'a+')
    return fh:write(("%s: %s\n"):format(date_time(t) .. get_tzoffset(get_timezone()), msg))
  end
end

local function log_msg(t, msg)
  return dolog(t, 'info: ' .. (msg or '')) or true -- always true
end

local function log_error(t, msg)
  return dolog(t, 'error: ' .. msg) and false -- always false
end

local function dotrace(t, msg)
  if t.tracefile ~= nil then
    local fh = io.open(t.tracefile, 'a+')
    return fh:write(("%s: %s\n"):format(date_time(t) .. get_tzoffset(get_timezone()), msg))
  end
end

-- handle the response of the final HTTP API call
local function diffbot_call(t, poll_uri)
  dotrace(t, 'request: ' .. poll_uri)

  -- we use HTTP GET, so to minimize dependencies, file_get_contents is enouguh
  local res, code, headers = http.request(poll_uri)

  dotrace(t, 'response headers: ' .. json.encode(headers))
  dotrace(t, 'response body: ' .. res)
  if code ~= 200 then
    return log_error(t, 'cannot read Diffbot api URL')
  end

  local ob = json.decode(res)
  if ob == nil then
    log_error(t, 'response is not a JSON object')
  end

  return ob
end

-- the base of all API calls
function api_call(t, api, url, fields, optargs) --optargs must be an associated array with key/value pairs to be passed
  if fields == nil then fields = {} end
  if optargs == nil then optargs = {} end

  local poll_uri = {
    t.base_url:format(t.version, api),
    'token=', t.token,
    "&url=", url_escape(url),
    '&fields=', tconcat(fields, ','),
  }

  if #optargs > 0 then
    for key, value in pairs(optargs) do
      poll_uri[#poll_uri + 1] = ("&%s=%s"):format(url_escape(key), url_escape(value))
    end
  end

  log_msg(t, ("calling %s for %s"):format(api, url))

  return diffbot_call(t, tconcat(poll_uri))
end

-- common function to handle pause, continue, restart and delete commands
function crawlbot_control(t, name, control)
  local poll_uri = (t.base_url):format(t.version, 'crawl') .. ('token=%s&name=%s&%s'):format(t.token, name, control)
  return diffbot_call(t, poll_uri)
end

local function __construct(t, token, version)
  if version == nil then version = 2 end

  if type(json) ~= 'table' then
    error 'JSON module not installed! dkjson recommended https://github.com/LuaDist/dkjson.'
  end

  local client = {
    -- interface settings. you are free to change them after construct
    logfile = 'diffbot.log',
    dateformat = '%Y-%m-%d %H:%M:%S',

    -- uncomment this if you want trace info
    tracefile = 'diffbot.trc',
    
    -- there should be no reason to change this */
    base_url = 'http://api.diffbot.com/v%d/%s?',


    -- Public API calls follow here
    --
    -- One function for each Diffbot API (parameters may change in the future).

    analyze = function(t, url, fields)
      return api_call(t, 'analyze', url, fields)
    end,

    article = function(t, url, fields)
      return api_call(t, 'article', url, fields)
    end,

    frontpage = function(t, url, fields)
      return api_call(t, 'frontpage', url, fields, {format = 'json'}) -- forcing JSON format as the default is XML
    end,

    product = function(t, url, fields)
      return api_call(t, 'product', url, fields)
    end,

    image = function(t, url, fields)
      return api_call(t, 'image', url, fields)
    end,

    -- submit a crawl job
    crawlbot_start = function (t, name, seeds, api_query, options)
      local poll_uri, api_url, api

      if name == nil then
        return log_error(t, 'crawlbot_start: no name given')
      end
      if seeds == nil then
        return log_error(t, 'crawlbot_start: no seed URL  given')
      end
      if type(seeds) == 'table' then
        seeds = tconcat(seeds, ' ')
      end

      if api_query == nil then -- crawling in auto mode
        api_url = (t.base_url):format(t.version, 'analyze') .. 'mode=auto'
      else
        api = api_query.api
        if api == nil then
          return log_error(t, 'no api_query api given')
        end
        api_url = (t.base_url):format(t.version, api)
        if type(api_query.fields) == 'table' then
          api_url = api_url .. tconcat(api_query.fields, ',')
        end
      end

      poll_uri = {
        (t.base_url):format(t.version, 'crawl'),
        ('token=%s&name=%s&seeds=%s'):format(t.token, name, seeds),
        '&apiUrl=', url_escape(api_url)
      }
      if type(options) == 'table' and #options > 0 then
        for key, val in pairs(options) do
          poll_uri[#poll_uri + 1] = ('&%s=%s'):format(key, url_escape(val))
        end
      end
      
      log_msg(t, 'submit crawl job ' .. name)
      
      return diffbot_call(t, tconcat(poll_uri))
    end,

    crawlbot_pause = function(t, name)
      return crawlbot_control(t, name, 'pause=1')
    end,
    
    crawlbot_continue = function(t, name)
      return crawlbot_control(t, name, 'pause=0')
    end,
    
    crawlbot_restart = function(t, name)
      return crawlbot_control(t, name, 'restart=1')
    end,
    
    crawlbot_delete = function(t, name)
      return crawlbot_control(t, name, 'delete=1')
    end,
  }

  -- 'token' and 'version' should not be changed after construct
  setmetatable(client, {
    __index = function(t, k)
      if k == 'token' then
        return token
      elseif k == 'version' then
        return version
      end
    end,

    __newindex = function(t, k)
      if k == 'token' or k == 'version' then
        error(("Invalid action! Key '%s' is a read-only key."):format(k))
      end
    end,
  })

  return client
end

setmetatable(m, {
  __call = __construct,
})

return m
