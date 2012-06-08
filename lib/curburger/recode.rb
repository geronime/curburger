#encoding:utf-8

### TODO not to use Iconv. Hiding the deprecation warning for now.
v, $-v = $-v, nil
require 'iconv'
$-v = v

module Curburger

	module Recode

		# regexp constants
		RGX = {
			:empty_content    => %r{\A\s*\Z}m,
			:enc_from_ctype   => %r{charset=([a-zA-Z0-9\-]+)(?:;|$)}im,
			:enc_from_content => %r{(?:charset|encoding)=(["']?)([a-zA-Z0-9\-]+)\1}im,
			:enc_match_utf8   => %r{^utf\-?8$}i,
		}

		# recode the content to the forced/guessed encoding
		# 1) in case of specified encoding attempt to recode content to it
		# 2) guess encoding otherwise:
		#    2a) force encoding to ISO-8859-1
		#    2b) attempt to match content with the RGX[:enc_from_content] and get
		#        the real encoding if declared
		#        (web-servers like apache may force incorrect encoding in header)
		#    2c) attempt to get encoding from ctype, if any
		#    2d) in case of force_ignore do iconv conversion of the content into
		#        'UTF-8//IGNORE' encoding
		#    2e) attempt to ask whether UTF-8 is valid, leave in ISO-8859-1 if not
		def recode logging, ctype, content, force_ignore=false, encoding=nil
			if encoding                                             # 1)
				begin
					to_enc = force_ignore ? 'UTF-8//IGNORE' : 'UTF-8'
					content.replace Iconv.iconv(to_enc, encoding, content)[0]
					true
				rescue Exception => e
					if !logging || GLogg.log_w?
						msg = 'Curburger::Recode#recode: Failed to iconv page from ' +
								"forced encoding '#{encoding}' into '#{to_enc}:\n  " +
								"#{e.class} - #{e.message}"
						logging ? GLogg.log_w(msg) : warn(msg)
					end
					false
				end
			else                                                    # 2)
				enc = nil
				content.force_encoding 'ISO-8859-1'                   # 2a)
				if content.valid_encoding?
					enc = $2 if content =~ RGX[:enc_from_content]       # 2b)
				end
				enc = $1 if enc.nil? && ctype =~ RGX[:enc_from_ctype] # 2c)
				unless enc.nil?
					enc = 'UTF-8' if enc =~ RGX[:enc_match_utf8]
						# ruby does not understand 'utf8' encoding, ensure UTF-8
					if force_ignore                                     # 2d)
						begin
							content.replace Iconv.iconv('UTF-8//IGNORE', enc, content)[0]
							return true
						rescue => e # should not happen
							if !logging || GLogg.log_e?
								msg = 'Curburger::Recode#recode: Failed to iconv page from ' +
										"'#{enc}' into 'UTF-8//IGNORE':\n  #{e.class} - #{e.message}"
								logging ? GLogg.log_e(msg) : warn(msg)
							end
							enc = nil                                       # fall back to 2e)
						end
					else
						begin
							content.force_encoding enc
							unless content.valid_encoding?
								if !logging || GLogg.log_w?
									msg = 'Curburger::Recode#recode: ' +
											"Detected encoding '#{enc}' invalid!"
									logging ? GLogg.log_w(msg) : warn(msg)
								end
								enc = nil                                     # fall back to 2e)
							end
						rescue ArgumentError => e # Invalid encoding
							if !logging || GLogg.log_w?
								msg = 'Curburger::Recode#recode: ' +
										"Detected encoding '#{enc}' invalid: #{e}!"
								logging ? GLogg.log_w(msg) : warn(msg)
							end
						end
					end
				end
				if enc.nil?                                           # 2e)
					content.force_encoding 'UTF-8'
					if content.valid_encoding?
						enc = 'UTF-8'
					else
						content.force_encoding 'ISO-8859-1'
						enc = 'ISO-8859-1'
					end
				end
				begin
					to_enc = force_ignore ? 'UTF-8//IGNORE' : 'UTF-8'
					content.replace Iconv.iconv(to_enc, enc, content)[0]
					true
				rescue Exception => e # should not happen
					if !logging || GLogg.log_e?
						msg = 'Curburger::Recode#recode: Failed to iconv page from ' +
								"'#{enc}' into '#{to_enc}':\n  #{e.class} - #{e.message}"
						logging ? GLogg.log_e(msg) : warn(msg)
					end
					false
				end
			end
		end

	end # Recode

end # Curburger

