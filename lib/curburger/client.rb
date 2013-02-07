#encoding:utf-8
require 'glogg'
require 'curb'

require 'curburger/headers'
require 'curburger/recode'
require 'curburger/request'

module Curburger

	class Client

		# available options and defaults:
		#   logging        - enable/disable logging using GLogg (true)
		#   user_agent     - set user agent string (default is the curb one)
		#   http_proxy     - setup http proxy for this instance (nil)
		#   cookies        - enable cookie jar (false)
		#   http_auth      - specify default http authentication data sent each req.
		#                    (hash containing keys user, password, default {})
		#   follow_loc     - follow Location in HTTP response header (true)
		#   verify_ssl     - whether to check SSL certificates (true)
		#   retry_45       - retry 4XX and 5XX erros (false)
		#   ignore_kill    - how to handle exceptions based on signaling
		#                    - first the error with pattern /interrupt/i, next
		#                      Curl::Err::MultiBadEasyHandle: Invalid easy handle
		#                    - previous version just retried them as the exception
		#                      was handled generally in Request#request method;
		#                      unsuccessfully because of "Invalid easy handle"
		#                    - currently the interruption exception is recognized
		#                      and handled, the value of this option determines
		#                      the behaviour:
		#                      - false (default) - do not retry and abort
		#                        (fill return hash with :error set)
		#                      - true - ignore and retry (reinitialize @curb first)
		#   req_ctimeout   - connection timeout for the requests (REQ_CONN_TOUT)
		#                    - this is the timeout for the connection to be made,
		#                      not the timeout for the whole request and reply)
		#   req_timeout    - overall request timeout (REQ_TOUT)
		#   req_attempts   - number of attempts for the request (REQ_ATTEMPTS)
		#   req_retry_wait - specify random upper bound to sleep between retrying
		#                    failed request (default 0 = disabled)
		#   req_norecode   - do not recode request results (false)
		#   req_enc_ignore_illegal - ignore illegal bytes
		#                            during request result recode (false)
		#   req_limit      - limit number of successful requests per req_time_range
		#                    time period (nil)
		#   req_time_range - set request limit time period in seconds
		#   resolve_mode   - override resolving mode. Possible options are :auto,
		#                    :ipv4, :ipv6, with :auto default for curb but it may
		#                    generate frequent Curl::Err::HostResolutionError
		#                    for ipv4 only machine. Curburger uses :ipv4 default.
		def initialize o={}
			o = self.class.hash_keys_to_sym o
			@glogging    = o[:logging].nil?     ? true  : o[:logging]     ? true : false
			@follow_loc  = o[:follow_loc].nil?  ? true  : o[:follow_loc]  ? true : false
			@verify_ssl  = o[:verify_ssl].nil?  ? true  : o[:verify_ssl]  ? true : false
			@retry_45    = o[:retry_45].nil?    ? false : o[:retry_45]    ? true : false
			@ignore_kill = o[:ignore_kill].nil? ? false : o[:ignore_kill] ? true : false
			@req_ctimeout   = o[:req_ctimeout] ? o[:req_ctimeout].to_i : REQ_CONN_TOUT
			@req_timeout    = o[:req_timeout]  ? o[:req_timeout].to_i  : REQ_TOUT
			@req_attempts   = o[:req_attempts] ? o[:req_attempts].to_i : REQ_ATTEMPTS
			@req_retry_wait =
				o[:req_retry_wait] ? o[:req_retry_wait].to_i : REQ_RETRY_WAIT
			@req_norecode   =
				o[:req_norecode].nil? ? false : o[:req_norecode] ? true : false
			@req_enc_ignore_illegal = o[:req_enc_ignore_illegal].nil? ? false :
					o[:req_enc_ignore_illegal] ? true : false
			if o[:req_limit] && o[:req_time_range] # enable request limitation
				@req_limit, @req_time_range = o[:req_limit].to_i, o[:req_time_range].to_i
				@reqs = {:cnt => 0, :next_check => Time.now + @req_time_range}
			else
				@reqs = nil # initialize variable to avoid warnings
			end
			self.http_auth = o[:http_auth]
			@curb_opts = o.keep_if{|k, v|
			  # record options set in @curb instance for use with initialize_curl
				[:user_agent,:http_proxy,:cookies,:resolve_mode].include? k
			}
			initialize_curl
		end

		def user_agent
			@curb.useragent
		end

		def user_agent= ua
			@curb.useragent = ua
		end

		def http_auth
			@http_auth
		end

		def http_auth= http_auth
			if http_auth
				raise 'Hash expected for :http_auth option!' \
					unless http_auth.kind_of?(Hash)
				http_auth = self.class.hash_keys_to_sym http_auth
				http_auth.select!{|k, v| [:user, :password].include? k }
				raise 'Keys \'user\' and \'password\' expected in :http_auth!' \
					unless http_auth[:user] && http_auth[:password]
				@http_auth = http_auth
			else
				@http_auth = {}
			end
		end

		def head url, opts={}, &block
			rslt = request :head, url, @http_auth.merge(opts), block
			rslt[:content] = self.class.parse_headers rslt[:content]
			rslt
		end

		def get url, opts={}, &block
			request :get, url, @http_auth.merge(opts), block
		end

		def post url, data, opts={}, &block
			opts[:data] = data
			request :post, url, @http_auth.merge(opts), block
		end

		def put url, data, opts={}, &block
			opts[:data] = data
			request :put, url, @http_auth.merge(opts), block
		end

		def delete url, data=nil, opts={}, &block
			opts[:data] = data
			request :delete, url, @http_auth.merge(opts), block
		end

		# Is the logging through GLogg enabled or not?
		def log?
			@glogging
		end

		# return headers of the last reply parsed to Hash
		def headers
			hdr = @curb.header_str
			self.class.recode(log?, @curb.content_type, hdr) ?
				self.class.parse_headers(hdr) :
				self.class.parse_headers(@curb.header_str) # recode failed
		end

		# reset the curl instance - cookies are lost!
		def reset
			@curb = nil
			initialize_curl
		end

		private

		# default connection timeout, request timeout, attempt count, and retry wait
		REQ_CONN_TOUT  = 10
		REQ_TOUT       = 20
		REQ_ATTEMPTS   = 3
		REQ_RETRY_WAIT = 0 # disabled

		def initialize_curl
			@curb = Curl::Easy.new
			@curb.useragent = @curb_opts[:user_agent] if @curb_opts[:user_agent]
			@curb.proxy_url = @curb_opts[:http_proxy] if @curb_opts[:http_proxy]
			@curb.enable_cookies = true if @curb_opts[:cookies]
			@curb.resolve_mode = @curb_opts[:resolve_mode] || :ipv4
		end

		extend  Curburger::Headers
		extend  Curburger::Recode
		include Curburger::Request

		def self.hash_keys_to_sym h
			hash = {}
			h.each_pair{|k, v| hash[k.to_sym] = h[k] }
			hash
		end

	end # Client

end # Curburger

