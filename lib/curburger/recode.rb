#encoding:utf-8
require 'iconv'

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
		#    2d) attempt to ask whether UTF-8 is valid, leave in ISO-8859-1 if not
		def recode logging, ctype, content, encoding=nil
			if encoding                                             # 1)
				begin
					content.replace Iconv.iconv('UTF-8', encoding, content)[0]
					true
				rescue Exception => e
					if logging
						GLogg.log_w? && GLogg.log_w('Curburger::Recode#recode: ' +
								"Failed to iconv page with forced encoding '#{encoding}':\n  " +
								"#{e.class} - #{e.message}")
					else
						warn 'Curburger::Recode#recode: ' +
								"Failed to iconv page with forced encoding '#{encoding}':\n  " +
								"#{e.class} - #{e.message}"
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
					content.force_encoding enc
					unless content.valid_encoding?
						if logging
							GLogg.log_w? && GLogg.log_w('Curburger::Recode#recode: ' +
									"Detected encoding '#{enc}' invalid!")
						else
							warn "Curburger::Recode#recode: Detected encoding '#{enc}' invalid!"
						end
						enc = nil                                         # fall back to 2d)
					end
				end
				if enc.nil?                                           # 2d)
					content.force_encoding 'UTF-8'
					if content.valid_encoding?
						enc = 'UTF-8'
					else
						content.force_encoding 'ISO-8859-1'
						enc = 'ISO-8859-1'
					end
				end
				begin
					content.replace Iconv.iconv('UTF-8', enc, content)[0]
					true
				rescue Exception => e # should not happen
					if logging
						GLogg.log_e? && GLogg.log_e('Curburger::Recode#recode: ' +
								"Failed to iconv page with detected encoding '#{enc}':\n  " +
								"#{e.class} - #{e.message}")
					else
						warn 'Curburger::Recode#recode: Failed to iconv page ' +
								"with detected encoding '#{enc}':\n  #{e.class} - #{e.message}"
					end
					false
				end
			end
		end

	end # Recode

end # Curburger

