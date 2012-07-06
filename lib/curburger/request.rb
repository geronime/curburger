#encoding:utf-8
require 'curb'

module Curburger

	module Request

		private

		# Return [nil, err, last_url, time] upon error,
		# [content-type, content, last_url, time] otherwise.
		# Content is recoded to UTF-8 if original encoding is successfully guessed,
		# byte encoded original is returned otherwise.
		# In case of enabled cookies, the @cookie_jar hash is used and merged
		# with the new cookies.
		# Available options and defaults in opts hash:
		#   user
		#   password     - specify username/password for basic http authentication
		#   follow_loc   - redefine Curburger::Client instance @follow_loc
		#   verify_ssl   - redefine Curburger::Client instance @verify_ssl
		#   retry_45     - redefine Curburger::Client instance @retry_45
		#   ignore_kill  - redefine Curburger::Client instance @ignore_kill
		#   ctimeout     - redefine Curburger::Client instance @req_ctimeout
		#   timeout      - redefine Curburger::Client instance @req_timeout
		#   attempts     - redefine Curburger::Client instance @req_attempts
		#   retry_wait   - redefine Curburger::Client instance @req_retry_wait
		#   encoding     - force encoding for the fetched page (nil)
		#   force_ignore - use 'UTF-8//IGNORE' target encoding in iconv (false)
		#   cookies      - set custom additional cookies (string, default nil)
		#   headers      - add custom HTTP headers (empty hash)
		#   data         - data to be sent in the request (nil)
		#   content_type - specify custom content-type for POST/PUT request only
		# In case of enabled request per time frame limitation the method yields to
		# execute the optional block before sleeping if the @req_limit was reached.
		def request method, url, opts={}, block=nil
			t0, m, attempt, last_err = Time.now, method.downcase.to_sym, 0, nil
			opts = self.class.hash_keys_to_sym opts
			opts[:data] = data_to_s opts[:data]
			opts[:retry_45]    = @retry_45       if opts[:retry_45].nil?
			opts[:ignore_kill] = @ignore_kill    if opts[:ignore_kill].nil?
			opts[:attempts]    = @req_attempts   unless opts[:attempts]
			opts[:retry_wait]  = @req_retry_wait unless opts[:req_retry_wait]
			initialize_curl unless @curb
			initialize_request url, opts
			while attempt < opts[:attempts]
				attempt += 1
				req_limit_check block if @reqs # request limitation enabled
				t = Time.now
				begin
					case m
						when :head   then
							@curb.http_head
						when :post   then
							@curb.http_post opts[:data]
						when :put    then
							@curb.http_put opts[:data]
						when :delete then
							@curb.post_body = opts[:data]
							@curb.http_delete
						else # GET
							@curb.http_get
					end
					unless ['20', '30'].include? @curb.response_code.to_s[0,2]
						status = $1 if @curb.header_str.match(%r{ ([45]\d{2} .*)\r\n})
						raise Exception.new(status)
					end
					ctype, content = @curb.content_type || '', nil
					if m == :head
						content = @curb.header_str
					else
						content = @curb.body_str
						self.class.recode(log?, ctype, content,
								*opts.values_at(:force_ignore, :encoding))
					end
					@reqs[:cnt] += 1 if @reqs # increase request limitation counter
					log? && GLogg.log_d4? && GLogg.log_d4(sprintf(                      #_
							"Curburger::Request#request:\n    %s %s\n    " +                #_
							'Done in %.6f secs (%u/%u attempt%s, %us/%us connect/timeout).',#_
							m.to_s.upcase, url, Time.now - t0, attempt, opts[:attempts],    #_
							opts[:attempts] == 1 ? '' : 's',                                #_
							@curb.connect_timeout, @curb.timeout))                          #_
					return [ctype, content, @curb.last_effective_url,
							sprintf('%.6f', Time.now - t)]
				rescue interrupt_exception => e
				  # method defined below to recognize exception based on message as well
					log? && GLogg.log_d3? && GLogg.log_d3(sprintf(
							'Curburger::Request#request:' +
							"\n    %s %s\n    %s attempt %u/%u: %s - %s", m.to_s.upcase, url,
							opts[:ignore_kill] ? 'Retrying interrupted' : 'Aborting',
							attempt, opts[:attempts], e.class, e.message))
					if opts[:ignore_kill] # reinitialize @curb and retry
						attempt -= 1 # decrease both counters
						@reqs[:cnt] -= 1 if @reqs
						initialize_curl              # reinitialize @curl instance
						initialize_request url, opts # reinitialize @curl req. options
						redo
					else # abort
						@curl = nil
						return [nil, 'Interrupted!', nil, sprintf('%.6f', Time.now - t)]
					end
				rescue Exception => e
					log? && GLogg.log_i? && GLogg.log_i(sprintf(
							'Curburger::Request#request:' +
							"\n    %s %s\n    Attempt %u/%u failed: %s",
							m.to_s.upcase, url, attempt, opts[:attempts], e.message))
					last_err = e.message
					break if !opts[:retry_45] &&
							@curb.response_code >= 400 && @curb.response_code < 600
					sleep(1 + rand(opts[:retry_wait])) \
							if opts[:retry_wait] > 0 && attempt < opts[:attempts]
					next
				end
			end
			if !log? || GLogg.log_e?
				msg = sprintf "Curburger::Request#request:\n    %s %s\n    " +
						'Failed in %.6f secs (%u/%u attempt%s, %us/%us connect/timeout).' +
						"\n    Last error: %s", m.to_s.upcase, url, Time.now - t,
						attempt, opts[:attempts], opts[:attempts] == 1 ? '' : 's',
						@curb.connect_timeout, @curb.timeout, last_err
				log? ? GLogg.log_e(msg) : warn(msg)
			end
			return [nil, last_err, @curb.last_effective_url,
					sprintf('%.6f', Time.now - t)]
		end

		def data_to_s data
			if data.nil? || data.kind_of?(String)
				data
			elsif data.kind_of? Hash
				a = []
				data.each_pair{|k, v|
					a.push "#{@curb.escape k.to_s}=#{@curb.escape v.to_s}" }
				a.join '&'
			else
				throw "Unsupported data format: #{data.class} !"
			end
		end

		def initialize_request url, opts
			@curb.url = url
			@curb.cookies = nil # reset additional cookies
			@curb.cookies = opts[:cookies] \
				if opts[:cookies] && opts[:cookies].kind_of?(String)
			@curb.headers = {} # reset additional request headers
			@curb.headers = opts[:headers] \
				if opts[:headers] && opts[:headers].kind_of?(Hash)
			@curb.headers['Content-Type'] = opts[:content_type] if opts[:content_type]
			@curb.http_auth_types = nil # reset authentication data
			@curb.http_auth_types, @curb.username, @curb.password =
				:basic, *opts.values_at(:user, :password) if opts[:user]
			@curb.follow_location =
				opts[:follow_loc].nil? ? @follow_loc : opts[:follow_loc]
			@curb.ssl_verify_host = opts[:verify_ssl].nil? ?
					@verify_ssl : opts[:verify_ssl] ? true : false
			@curb.ssl_verify_peer = @curb.ssl_verify_host
			@curb.connect_timeout = opts[:ctimeout] ? opts[:ctimeout] : @req_ctimeout
			@curb.timeout = opts[:timeout] ? opts[:timeout] : @req_timeout
		end

		# method to determine interrupt exception(s) for rescue
		# thanks to http://exceptionalruby.com/exceptional-ruby-sample.pdf (page 34)
		def interrupt_exception
			m = Module.new
			(class << m; self; end).instance_eval do
				define_method(:===){|e|
					e.message =~ /interrupt/i || e.class == Curl::Err::MultiBadEasyHandle
				}
			end
			m
		end

		# Check whether the number of requests is within the limit.
		# Execute the optional block before sleeping until @reqs[:next_check]
		# in case of reached @req_limit.
		# Reset both counter and next_check if the current time is greater.
		def req_limit_check block=nil
			if @reqs[:cnt] >= @req_limit && Time.now <= @reqs[:next_check]
			  # limit reached, execute the optional block and sleep until next_check
				secs = (@reqs[:next_check] - Time.now + 1).to_i
				log? && GLogg.log_d2? && GLogg.log_d2(sprintf(                        #_
						'Curburger::Request#req_limit_check: Request limit ' +            #_
						"(%u per %usecs) reached.\n  Sleeping %u seconds.",               #_
						@req_limit, @req_time_range, secs))                               #_
				if block
					block.call
					secs = (@reqs[:next_check] - Time.now + 1).to_i # recompute
					log? && GLogg.log_d3? && GLogg.log_d3(sprintf(                      #_
							'Curburger::Request#req_limit_check: ' +                        #_
							'Block executed, sleeping %usecs.', secs > 0 ? secs : 0))       #_
				end
				sleep secs if secs > 0
			end
			if Time.now > @reqs[:next_check] # reset the counter
				log? && GLogg.log_d3? && GLogg.log_d3(sprintf(                        #_
						'Curburger::Request#req_limit_check: Resetting counter ' +        #_
						'(%u/%u requests done).', @reqs[:cnt], @req_limit))               #_
				@reqs[:cnt], @reqs[:next_check] = 0, Time.now + @req_time_range
			end
		end

	end # Request

end # Curburger

