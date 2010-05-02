#!/usr/bin/env ruby
require 'rubygems'
require 'mongrel'
#require 'daemons'
 
#init()
#Daemons.daemonize()

Dir.chdir('/Users/tom/Downloads/')
h = Mongrel::HttpServer.new("0.0.0.0", "3001")
h.register('/', Mongrel::DirHandler.new('.'))
h.run.join
