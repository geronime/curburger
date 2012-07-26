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
+ request timeout
+ number of attempts for each request
  + default instance configuration to retry 4XX/5XX responses
+ random sleep time before retrying failed request
+ per-instance request count per time period limitation
+ default instance http authentication
+ default instance SSL certificate verification
+ default instance option to determine whether to ignore signal-based exceptions

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
  + `http_auth` - default instance http authentication credentials sent with
     requests (hash with keys `user`, `password`, default `{}`)
  + `follow_loc` - follow `Location:` in HTTP response header (default `true`)
  + `verify_ssl` - whether to verify SSL certificates (default `true`)
  + `retry_45` - whether to retry 4XX/5XX responses (default `false`)
  + `ignore_kill` - how to handle exceptions based on signaling
    + before __0.2.2__ all exceptions were handled generally during requests
      + when f.ex. Ctrl-c was pressed during the request, interruption exception
        rose, followed by `Curl::Err::MultiBadEasyHandle: Invalid easy handle`
        exceptions on retries
      + all these failures were uselessly retried as the Curl handle became
        invalid with no useful result anyway and all following requests
        with the same instance would fail as well
    + since __0.2.2__ these interruption (and "Invalid easy handle") exceptions
      are recognized and handled based on `ignore_kill` option:
      + `false` (default) - do not retry at all and immediately return the
        result hash with `:error` key set
      + `true` - reinitialize Curl handle and keep going, retry the current
        attempt not counting it
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
  + `resolve_mode` - override resolving mode (default `:ipv4`)
    + possible options: `:auto`, `:ipv4`, `:ipv6`
    + `curl` default `:auto` may generate frequent
      `Curl::Err::HostResolutionError` errors for ipv4 only machine therefore
      Curburger uses `:ipv4` as default

### Instance methods:

  + `user_agent`
  + `user_agent=`
    + get/set currently configured instance `user_agent`
  + `http_auth`
  + `http_auth=`
    + get/set default authentication credentials (`nil` clears the settings)

### Available request methods:

Available request methods:

  + `head`
  + `get`
  + `post`
  + `put`
  + `delete`

Request methods return hash with following keys/values:

  + `:content` - content of the response
    + header hash for `head` request (decoded by `headers` method)
    + recoded to UTF-8 if original encoding is successfully guessed,
      byte encoded original otherwise
      (for more info refer to `Curburger::Recode.recode`)
  + `:ctype` - appropriate response HTTP header value (empty string if missing)
  + `:last_url` - last effective url of the request (to recognize redirections)
  + `:attempts` - count of spent request attempts
  + `:responses` - array `[[status, time]]` of all attempts
  + `:time` - total processing time rounded to 6 decimal places
  + `:error` - defined only in case of error: the last error is stored here

#### Reqeust options:

Request methods support following optional parameters:

  + `user`
  + `password` - credentials for basic HTTP authentication
     (override instance `http_auth` for this request, default `nil`)
  + `follow_loc` - redefine instance `follow_loc` for this request
  + `verify_ssl` - redefine instance `verify_ssl` for this request
  + `retry_45` - redefine instance `retry_45` for this request
  + `ignore_kill` - redefine instance `ignore_kill` for this request
  + `ctimeout` - redefine instance `req_ctimeout` for this request
  + `timeout` - redefine instance `req_timeout` for this request
  + `attempts` - redefine instance `req_attempts` for this request
  + `retry_wait` - redefine instance `req_retry_wait` for this request
  + `encoding` - force encoding for the response body (default `nil`)
  + `force_ignore` - use `UTF-8//IGNORE` target encoding in iconv
     (default `false`)
  + `cookies` - set additional cookies for the request ( default `nil`)
  + `headers` - add custom HTTP headers to the request ( default `{}`)
  + optional _block_ given:
    + relevant only in case of enabled request per time period limitation
    + request method yields to execute the block before sleeping if the
      reqeust limit was reached

#### HEAD

    result = c.head(url, {opts}) { optional block ... }

#### GET

    result = c.get(url, {opts}) { optional block ... }

#### POST, PUT, DELETE

    result = c.post(url, data, {opts}) { optional block ... }
    result = c.put(url, data, {opts}) { optional block ... }
    result = c.delete(url, data=nil, {opts}) { optional block ... }

  + `data` parameter is expected in `String` scalar or `Hash` of
  `{parameter => value}`
    + posted direcly in case of `String` scalar
    + url-encoded and assembled to scalar in case of `Hash`
    + example: `'param1=value1&param2=value2'` or
  `{:param1=>'value1', 'param2'=>'value2'}`
  + optional `content_type` option overrides default
    `application/x-www-form-urlencoded` Content-Type HTTP POST header

#### Headers:

To obtain headers of the last reply parsed into `Hash` use `headers`
instance method

    headers = c.headers

  + the first line (status line) is stored in `Status` key of the returned `Hash`
  + multivalue headers are stored in an `Array`

## Changelog:

+ __0.2.4__: removal of 'Expect' HTTP header by default
+ __0.2.3__: hide iconv deprecation warning
+ __0.2.2__: instance/request `ignore_kill` options
+ __0.2.1__: rescue 'ArgumentError: unknown encoding name' in Curburger::Recode
+ __0.2.0__: request methods return hash
+ __0.1.8__: `user_agent` and `user_agent=` get/set methods
+ __0.1.7__: instance/request `retry_45` options
+ __0.1.6__: instance/request `verify_ssl` options
+ __0.1.5__: empty string `content_type` returned from requests in case of
             missing `Content-Type` HTTP header
+ __0.1.4__: optional post data in DELETE request, bugfix
+ __0.1.3__: default instance http authentication
+ __0.1.2__: `:cookies` option to set additional cookies for requests
+ __0.1.1__: `:follow_loc` option for requests; HEAD, PUT, DELETE requests
+ __0.1.0__: `:headers` option for custom headers in requests
+ __0.0.9__: `:resolve_mode` instance option
+ __0.0.8__: removed "`require 'bundler/setup'`" statements
+ __0.0.7__: `headers` instance method
+ __0.0.6__: `last_url` part in request return array
+ __0.0.5__: `:force_ignore` option for requests
+ __0.0.4__: `:content_type` option for POST requests
+ __0.0.3__: request timeout added (previously only connect timeout)
+ __0.0.2__: option for random sleep time before retrying failed request
+ __0.0.1__: first revision

## License

Curburger is copyright (c)2011 Jiri Nemecek, and released under the terms
of the MIT license. See the LICENSE file for the gory details.

