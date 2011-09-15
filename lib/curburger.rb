#encoding:utf-8
require 'curburger/client'

module Curburger

	class << self
		def new o={}
			Curburger::Client.new o
		end
	end

end

