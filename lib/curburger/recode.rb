#encoding:utf-8

module Curburger

	module Recode

		# regexp constants
		RGX = {
			:empty_content    => %r{\A\s*\Z}m,
			:enc_from_ctype   => %r{charset=([a-zA-Z0-9\-]+)(?:;|$)}im,
			:enc_from_content => %r{(?:charset|encoding)=(["']?)([a-zA-Z0-9\-]+)\1}im,
			:enc_match_utf8   => %r{^utf\-?8$}i,
		}

		# recode the content from the forced/guessed encoding to UTF-8
		# 1) in case of specified encoding attempt to recode content to it
		# 2) guess encoding otherwise:
		#    2a) force encoding to ISO-8859-1
		#    2b) attempt to match content with the RGX[:enc_from_content] and get
		#        the real encoding if declared
		#        (web-servers like apache may force incorrect encoding in header)
		#    2c) attempt to get encoding from ctype, if any
		#    2d) assume UTF-8 encoding
		# in both cases:
		#   - use UTF-16 as the stepping stone
		#   - in case of force_ignore perform encode using
		#     :invalid => :replace, :undef => :replace, :replace => ''
		#     (simmilar as previous iconv 'UTF-8//IGNORE' behaviour)
		#   - if the conversion fails (does not happen for force_ignore=true)
		#     keep the original string preserved
		#     (force encoding back, probably to ASCII, in case of 2)
		# Thanks to http://stackoverflow.com
		# /questions/14035307/ruby-invalid-byte-sequence-in-utf-8-argumenterror
		def recode logging, ctype, content, force_ignore=false, encoding=nil
			if encoding                                             # 1)
				if force_ignore
					content.encode! 'UTF-16', encoding,
							:invalid => :replace, :undef => :replace, :replace => ''
					content.encode! 'UTF-8'
					return true
				end
				begin
					content.replace content.encode('UTF-16', encoding).encode 'UTF-8'
					return true
				rescue Exception => e
					if !logging || GLogg.log_w?
						msg = 'Curburger::Recode#recode: Failed to recode page from ' +
								"forced encoding '#{encoding}':\n  #{e.class} - #{e.message}"
						logging ? GLogg.log_w(msg) : warn(msg)
					end
					return false
				end
			end
			enc, orig_enc = nil, content.encoding
			content.force_encoding 'ISO-8859-1'                     # 2a)
			if content.valid_encoding?
				enc = $2 if content =~ RGX[:enc_from_content]         # 2b)
			end
			enc = $1 if enc.nil? && ctype =~ RGX[:enc_from_ctype]   # 2c)
			unless enc.nil?
				enc = 'UTF-8' if enc =~ RGX[:enc_match_utf8]
				  # ruby does not understand 'utf8' encoding, ensure UTF-8
				if force_ignore
					content.encode! 'UTF-16', enc,
							:invalid => :replace, :undef => :replace, :replace => ''
					content.encode! 'UTF-8'
					return true
				end
				begin
					content.force_encoding enc
					unless content.valid_encoding?
						if !logging || GLogg.log_w?
							msg = "Curburger::Recode#recode: Detected encoding '#{
									enc}' invalid!"
							logging ? GLogg.log_w(msg) : warn(msg)
						end
						enc = nil                                         # fall back to 2d)
					end
				rescue ArgumentError => e # Invalid encoding
					if !logging || GLogg.log_w?
						msg = "Curburger::Recode#recode: Detected encoding '#{
								enc}' invalid: #{e}!"
						logging ? GLogg.log_w(msg) : warn(msg)
					end
					enc = nil
				end
			end
			enc ||= 'UTF-8'
			if force_ignore
				content.encode! 'UTF-16', enc,
						:invalid => :replace, :undef => :replace, :replace => ''
				content.encode! 'UTF-8'
				return true
			end
			begin
				content.replace content.encode('UTF-16', encoding).encode 'UTF-8'
				return true
			rescue Exception => e
				if !logging || GLogg.log_e?
					msg = "Curburger::Recode#recode: Failed to recode page from '#{
							enc}':\n  #{e.class} - #{e.message}"
					logging ? GLogg.log_e(msg) : warn(msg)
				end
				content.force_encoding orig_enc
				return false
			end
		end # recode

	end # Recode

end # Curburger

