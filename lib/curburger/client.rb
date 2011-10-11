#encoding:utf-8
require 'bundler/setup'
require 'glogg'
require 'curb'

require 'curburger/recode'
require 'curburger/request'

module Curburger

	class Client

		# available options and defaults:
		#   logging        - enable/disable logging using GLogg (true)
		#   user_agent     - set user agent string (default is the curb one)
		#   http_proxy     - setup http proxy for this instance (nil)
		#   cookies        - enable cookie jar (false)
		#   follow_loc     - follow Location in HTTP response header (true)
		#   req_ctimeout   - connection timeout for the requests (REQ_CONN_TOUT)
		#                    - this is the timeout for the connection to be made,
		#                      not the timeout for the whole request and reply)
		#   req_timeout    - overall request timeout (REQ_TOUT)
		#   req_attempts   - number of attempts for the request (REQ_ATTEMPTS)
		#   req_retry_wait - specify random upper bound to sleep between retrying
		#                    failed request (default 0 = disabled)
		#   req_limit      - limit number of successful requests per req_time_range
		#                    time period (nil)
		#   req_time_range - set request limit time period in seconds
		def initialize o={}
			self.class.hash_keys_to_sym o
			@glogging = o[:logging].nil? ? true : o[:logging] ? true : false
			@req_ctimeout   = o[:req_ctimeout] ? o[:req_ctimeout].to_i : REQ_CONN_TOUT
			@req_timeout    = o[:req_timeout]  ? o[:req_timeout].to_i  : REQ_TOUT
			@req_attempts   = o[:req_attempts] ? o[:req_attempts].to_i : REQ_ATTEMPTS
			@req_retry_wait =
				o[:req_retry_wait] ? o[:req_retry_wait].to_i : REQ_RETRY_WAIT
			if o[:req_limit] && o[:req_time_range] # enable request limitation
				@req_limit, @req_time_range = o[:req_limit].to_i, o[:req_time_range].to_i
				@reqs = {:cnt => 0, :next_check => Time.now + @req_time_range}
			end
			@curb = Curl::Easy.new
			@curb.useragent = o[:user_agent] if o[:user_agent]
			@curb.proxy_url = o[:http_proxy] if o[:http_proxy]
			@curb.enable_cookies = true if o[:cookies]
			@curb.follow_location =
				o[:follow_loc].nil? ? true : o[:follow_loc] ? true : false
		end

		def get url, opts={}, &block
			request :get, url, opts, block
		end

		def post url, data, opts={}, &block
			opts[:data] = data_to_s data
			request :post, url, opts, block
		end

		# Is the logging through GLogg enabled or not?
		def log?
			@glogging
		end

		private

		# default connection timeout, request timeout, attempt count, and retry wait
		REQ_CONN_TOUT  = 10
		REQ_TOUT       = 20
		REQ_ATTEMPTS   = 3
		REQ_RETRY_WAIT = 0 # disabled

		extend  Curburger::Recode
		include Curburger::Request

		def self.hash_keys_to_sym h
			h.each_pair{|k, v| h[k.to_sym] = h.delete k if k.kind_of? String }
		end

		def data_to_s data
			if data.kind_of? Hash
				a = []
				data.each_pair{|k, v|
					a.push "#{@curb.escape k.to_s}=#{@curb.escape v.to_s}" }
				a.join '&'
			elsif data.kind_of? String
				data
			else
				throw "Unsupported data format: #{data.class} !"
			end
		end

	end # Client

end # Curburger

