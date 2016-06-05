#!/bin/env ruby
# encoding: utf-8
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

  str_value.gsub!('ä', 'ae')
  str_value.gsub!('ö', 'oe')
  str_value.gsub!('ü', 'ue')
  str_value.gsub!('ß', 'ss')
  str_value.gsub!('Ä', 'Ae')
  str_value.gsub!('Ö', 'Oe')
  str_value.gsub!('Ü', 'Ue')

  {:str_value => str_value, :dec_value => dec_value}
end

def send_message(text)
  puts `/bin/sh #{File.dirname(__FILE__)}/eta-notification.sh "#{text}"`
end

def send_notification_if_required(id, current_value, last_value)
  kessel_status_id = 52
  kessel_stoerung = 16

  current = current_value[:dec_value]
  last = last_value[:dec_value]

  if id == kessel_status_id
    if last != kessel_stoerung && current == kessel_stoerung
      send_message("Kessel-Störung! (Status '#{last_value[:str_value]}' => '#{current_value[:str_value]})'")
    elsif last == kessel_stoerung && current != kessel_stoerung
      send_message("Kessel-Störung behoben. (Status '#{last_value[:str_value]}' => '#{current_value[:str_value]}')")
    end
  end
end


DB = Sequel.mysql(:user => 'eta', :password => 'eta', :host => 'localhost', :database => 'eta', :encoding => 'utf8')

DB.fetch("SELECT *, #{Time.now.min} % `interval` = 0 AS run_now FROM variables HAVING run_now = 1") do |row|
  begin
    uri = ROOT + "/user/var" + row[:uri]
    value_xml = read_value(uri)
    value = parse_value(value_xml)

    last_value = DB.fetch("SELECT * FROM `values` WHERE variable_id = ? ORDER BY created_at DESC LIMIT 1", row[:id]).first
#    if last_value[:dec_value] != value[:dec_value]
      record = {:variable_id => row[:id], :created_at => Time.now}.merge(value)
      DB[:values].insert(record)
#    end
    send_notification_if_required(row[:id], value, last_value)
  rescue => e
    puts e
  end
end

