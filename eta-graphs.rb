#!/bin/env ruby
require 'rubygems'
require 'open-uri'
require 'nokogiri'
require 'sequel'

ROOT = "http://edling2.de:8080"

def read_value(uri)
  xml = Nokogiri::XML(open(uri))
  xml.at_css("eta value")
end

def parse_value(element)
  unit = element["unit"]
  str_value = element["strValue"]

  raw_value = element.text.gsub(',', '.').to_f

  scale = element["scaleFactor"].to_f
  offset = element["advTextOffset"].to_f

  dec_value = (raw_value - offset) / scale

  {:str_value => str_value, :dec_value => dec_value}
end


DB = Sequel.mysql(:user => 'eta', :password => 'eta', :host => 'localhost', :database => 'eta', :encoding => 'utf8')

DB.fetch("SELECT *, #{Time.now.min} % `interval` = 0 AS run_now FROM variables HAVING run_now = 1") do |row|
  begin
    uri = ROOT + "/user/var" + row[:uri]
    value_xml = read_value(uri)
    value = parse_value(value_xml)

#    last_value = DB.fetch("SELECT dec_value FROM `values` WHERE variable_id = ? ORDER BY created_at DESC LIMIT 1", row[:id]).first
#    if last_value != value[:dec_value]
      record = {:variable_id => row[:id], :created_at => Time.now}.merge(value)
      DB[:values].insert(record)
#    end
  rescue => e
    puts e
  end
end

