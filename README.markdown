# Curburger - custom User-Agent

+ [github project] (https://github.com/geronime/curburger)

Curburger is configurable instance based User-Agent providing get/post requests
using curb.

Configurable features:

+ user-agent string settings
+ per-instance proxy configuration
+ enable cookies per-instance
+ disable following of `Location:` in HTTP response header
+ request connection timeout
+ request timeout (new in __0.0.3__)
+ number of attempts for each request
+ random sleep time before retrying failed request (new in __0.0.2__)
+ per-instance request count per time period limitation

## Usage

    require 'curburger'

### Instance options:

    c = Curburger.new({:opt => val})

  + `logging` - logging via `GLogg` (default `true`); with logging disabled
  only errors/warnings are printed to `STDERR`
    + to completely disable logging leave `logging=true` and configure
  `GLogg` verbosity to `GLogg::L_NIL`

            GLogg.ini(nil, GLogg::L_NIL)
  + `user_agent` - redefine instance `user_agent` string (default is set by
  `curb`)
  + `http_proxy` - set instance proxy url (default `nil`)
  + `cookies` - enable cookies for this instance (default `false`)
  + `follow_loc` - follow `Location:` in HTTP response header (default `true`)
  + `req_ctimeout` - connection timeout for the requests (default `10`)
    + this is the timeout for the connection to be established, not the timeout
  for the whole request & reply
  + `req_timeout` - request timeout (default `20`)
  + `req_attempts` - number of attempts for the request (default `3`)
  + `req_retry_wait` - maximal count of seconds to sleep before retrying
  failed request (defalut `0`, disabled)
    + e.g. `10` = sleep random 1-10 seconds before retrying failed request
  + `req_limit` - limit number of successful requests per `req_time_range`
  time period (default `nil`)
  + `req_time_range` - set requests limit time period in seconds

### Available request methods:

Two request methods are available for now: `get` and `post`.
Both return arrays:

  + in case of error return `[nil, error_message, last_url, time]`
  + `[content_type, content, last_url, time]` otherwise
    + `content` is recoded to `UTF-8` encoding for the most cases: for more
  information refer to description in `Curburger::Recode#recode`
    + `last_url` is last effective URL  of the request - to recognize
  redirections (new in __0.0.6__)
    + `time` is request processing time formatted to `%.6f` seconds

#### Reqeust options:

Request methods support following optional parameters:

  + `user`
  + `password` - credentials for basic HTTP authentication (default `nil`)
  + `ctimeout` - redefine instance `req_ctimeout` for this request
  + `timeout` - redefine instance `req_timeout` for this request
  + `attempts` - redefine instance `req_attempts` for this request
  + `retry_wait` - redefine instance `req_retry_wait` for this request
  + `encoding` - force encoding for the response body (default `nil`)
  + `force_ignore` - use `UTF-8//IGNORE` target encoding in iconv (new in
  __0.0.5__, default `false`)
  + optional _block_ given:
    + relevant only in case of enabled request per time period limitation
    + request method yields to execute the block before sleeping if the
  reqeust limit was reached

#### GET

    result = c.get(url, {opts}) { optional block ... }

#### POST

    result = c.post(url, data, {opts}) { optional block ... }

  + `data` parameter is expected in `String` scalar or `Hash` of
  `{parameter => value}`
    + posted direcly in case of `String` scalar
    + url-encoded and assembled to scalar in case of `Hash`
    + example: `'param1=value1&param2=value2'` or
  `{:param1=>'value1', 'param2'=>'value2'}`
  + optional `content_type` option overrides default
  `application/x-www-form-urlencoded` Content-Type HTTP POST header
  (new in __0.0.4__)

## Changelog:

+ __0.0.6__: `last_url` part in request return array
+ __0.0.5__: `:force_ignore` option for requests
+ __0.0.4__: `:content_type` option for POST requests
+ __0.0.3__: request timeout added (previously only connect timeout)
+ __0.0.2__: option for random sleep time before retrying failed request
+ __0.0.1__: first revision

## License

Curburger is copyright (c)2011 Jiri Nemecek, and released under the terms
of the MIT license. See the LICENSE file for the gory details.

