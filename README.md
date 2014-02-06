# Lua client for the Diffbot API

The Diffbot Lua interface is a module, named *diffbot*. You can create one or
more client instances (if neccessary).

## Installation

* Ensure dkjson (https://github.com/LuaDist/dkjson) module is installed on your system.
* (Optional) Install the Seawolf library, for convenient debugging.
* Load diffbot module. E.g.: `local diffbot = require 'diffbot'`

If a JSON is not installed on your system, it will throw an error message.

## Configuration

First, create a diffbot object. The only mandatory parameter is your
personal developer token. The second, optional parameter is the API version.

```lua
local diffbot = require 'diffbot'
local diffbot_client = diffbot('DEVELOPER TOKEN', 2)
```

Then, the diffbot table (a.k.a object) can be used to call the Diffbot API several times.

### Metatable synopsis

    diffbot = {
      -- variables
      logfile = 'diffbot.log',
      dateformat = 'Y-m-d H:i:sP',
      tracefile = 'diffbot.trc',
      base_url = 'http://api.diffbot.com/v%d/%s?',

      -- methods
      public __call(string token [, int version = 2] )

      -- automatic APIs
      table analyze(string url [, table fields] ),
      table article(string url [, table fields] ),
      table frontpage(string url [, table fields] ),
      table product(string url [, table fields] ),
      table image(string url [, table fields] ),

      -- crawlbot API
      table crawlbot_start(string name, table seeds, table api_query = nil [, table options ] ),
      table crawlbot_pause(string name),    // pause a runnning job
      table crawlbot_continue(string name), // continue a paused job
      table crawlbot_restart(string name),  // restart a job, cleaning previous results
      table crawlbot_delete(string name),   // delete a job with all of its results
    }

### Options

Each option is a public variable, you can change its default value after the object is
created. 

* **logfile** is the filename where API names and passed URLs are logged. If
 set to _nil_, no logging performed.
* **dateformat** is the format of _date()_ function, used in log file.
* **tracefile** is the file name of the trace file where raw request and
 response data is saved for debugging purposes. In production environment,
 you should set it to _nil_ to disable tracing.
* **base_url** contains the URL pattern to use when calling Diffbot
 API. First value will be replaced to version number, the second will be the
 api name. Usually, you do not need to change this. 

E.g., to disable trace information:

```lua
diffbot_client.tracefile = false
```

## Usage

For each API, a different public function can be called. The function name
is the same as the API name. The first, mandatory parameter is the URL to be
analyzed, the second, optional parameter contains the fields to be returned.
Functions return an object hierarchy or _false_ if an error occurs.

### Example 1: Call the Analyze API

Code:

```lua
local diffbot, d, c
diffbot = require 'diffbot'
d = diffbot 'DEVELOPER_TOKEN'
c = d:analyze 'http://diffbot.com/products/'
diffbot.debug.print_r(c)
```

Returns:

    table {
      type = "serp"
      title = "Diffbot: Products"
      url = "http://diffbot.com/products/"
      human_language = "en"
      childNodes = {
        ...
      }
    }

### Example 2: Call the Article API

Code:

```lua
local diffbot, d, fields, c
diffbot = require 'diffbot'
d = diffbot 'DEVELOPER_TOKEN'
fields = {'icon', 'text', 'title'} -- fields to be returned
c = d:article('http://diffbot.com/products/', fields)
diffbot.debug.print_r(c)
```

Returns:

    table {
      type = "article"
      title = "Products"
      url = "http://diffbot.com/products/"
      text = ""name": "Automatic APIs", "type": "computer vision", "author": "Diffy", "target": "common web pages"
        "name": "Custom API Toolkit", "type": "custom extraction", "author": "Diffy", "target": "any kind of page"
        "name": "Crawlbot", "type": "spidering", "author": "Diffy", "target": "entire domains""
      icon = "http://diffbot.com/favicon.ico?v=2"
      author = ""
    }

For choosing _fields_, see the official api documentation:

* http://diffbot.com/products/automatic/classifier/
* http://diffbot.com/products/automatic/article/
* http://diffbot.com/products/automatic/frontpage/
* http://diffbot.com/products/automatic/product/
* http://diffbot.com/products/automatic/image/

### Example 3: Submit and control a crawl job

Synopsys:

  table crawlbot_start(string name, table seeds, table api_query = nil [, table options ] )

The parameters are:

* **name** - The name of your crawl job.
* **seeds** - The URL(s) to crawl. Pass one URL as a string, more URLs as an array.
* **api_query** - If you set this parameter to _nil_ or just ignore it, your crawl will run in automatic mode.
 Here you can define what Diffbot API should the crawlbot use. It is an associated array where array keys are:
  * _api_ : one of Diffbot API name, e.g. "article"
  * _fields_ (optional) : array of field names to processed, e.g. array("meta","image")
* **Options** - An associated array for optional crawl arguments and/or refining your crawl. 
 See [crawl documentation](http://diffbot.com/dev/docs/crawl/) for details.

#### Start a job in automatic mode, crawl up to five pages:

```lua
local diffbot, d, ret
diffbot = require 'diffbot'
d = diffbot 'DEVELOPER_TOKEN'
ret = d:crawlbot_start('testJob', 'http://diffbot.com/',
  nil,
  {maxToProcess = 5}
)
diffbot.debug.print_r(ret.response)
```

Returns:

    Successfully added urls for spidering.

#### Start a job using _product_ api with fields _querystring_ and _meta_ :

```lua
local diffbot, d, ret
diffbot = require 'diffbot'
d = diffbot 'DEVELOPER_TOKEN'
ret = d:crawlbot_start('testJob', 'http://diffbot.com/',
  {
    api = 'product',
    fields = {'querystring', 'meta'},
  },
  {maxToProcess = 5}
)
diffbot.debug.print_r(ret.response)
```

Returns:

    Successfully added urls for spidering.

#### Pause a running crawl job:

```lua
local diffbot, d, ret
diffbot = require 'diffbot'
d = diffbot 'DEVELOPER_TOKEN'
ret = d:crawlbot_pause 'testJob'
diffbot.debug.print_r(ret.jobs[1].jobStatus)
```

Returns:

    {
      status = 6
      message = "Job paused."
    }

#### Delete a crawl job with its results:

```lua
local diffbot, d, ret
diffbot = require 'diffbot'
d = diffbot 'DEVELOPER_TOKEN'
ret = d:crawlbot_delete 'testJob'
diffbot.debug.print_r(ret.response)
```

Returns:

  Successfully deleted job.
