#!/usr/bin/env ruby
# encoding: utf-8

require 'ap'
require 'yaml'
require 'json'

file = ARGV[0]

exit unless file
help_text = File.read(file)

groups = help_text.match(/^.+commandGroups[^\n]+{(.+?)}/m)[1].split.map{|l| l.tr('","', '') }

docu = {}

help_text.scan(/^\s+({.+\n.+\n.+\n.+\n.+},)/).flatten.each do |line|
  line = line.split("\n")

  to_trim = "\"{}\n"
  command = line[0].tr(to_trim, '').strip.sub(/,$/, '')
  params  = line[1].tr(to_trim, '').strip.sub(/,$/, '')
  summary = line[2].tr(to_trim, '').strip.sub(/,$/, '')
  group   = line[3].to_i
  since   = line[4].tr(to_trim, '').strip.sub(/,$/, '')

  docu[groups[group]] ||= ""
  docu[groups[group]] << <<-EOF
<strong>#{command}</strong> #{params}<br>
summary: #{summary}<br>
since: #{since}<br>
<br>
  EOF
end

puts docu.to_json
