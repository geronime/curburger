#encoding:utf-8

module Curburger

	module Headers

		# parse headers provided in String str to Hash
		# - the first - status line - is stored in 'Status' key
		# - multi-value headers are stored in an array
		def parse_headers str
			hdr, ha = {}, str.split("\r\n")
			hdr['Status'] = ha.shift
			ha.each{|ln|
				h, val = ln.split(': ', 2)
				hdr[h].nil? ?
					(hdr[h] = val) :
					hdr[h].kind_of?(Array) ? hdr[h].push(val) : (hdr[h] = [hdr[h], val])
			}
			hdr
		end

	end

end

