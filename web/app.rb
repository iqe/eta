#!/bin/env ruby
require 'rubygems'
require 'date'
require 'sinatra'
require 'sequel'
require 'slim'

DB = Sequel.mysql(:user => 'root', :password => 'root', :host => 'localhost', :database => 'eta')

get '/csv' do
  variable_ids = params[:vars].split(",").map {|id| id.to_i} || []
  from = Date.parse(params[:from]) rescue Date.today << 1 # 1 month back
  to = Date.parse(params[:to]) rescue Date.today + 1 # tomorrow at 0 AM

  variables = DB.fetch("SELECT id, name FROM variables WHERE id in ? ORDER BY id", variable_ids)
  variable_ids = variables.map {|v| v[:id]}
  variable_names = variables.map {|v| v[:name]}

  csv = "Created At," << variable_names.join(",") << "\n"
  DB.fetch("SELECT * FROM `values` WHERE variable_id in ? AND created_at BETWEEN ? AND ?",
      variable_ids, from, to) do |row|
    csv << row[:created_at].to_s << ","
    
    column_count = variable_ids.length
    column_index = variable_ids.find_index row[:variable_id]
    
    columns = Array.new(column_count)
    columns[column_index] = row[:dec_value].to_s
    
    csv << columns.join(",") << "\n"
  end
  
  content_type :csv
  csv
end

get '/variables' do
  rows = DB.fetch("SELECT * FROM variables")
  slim :variables, :locals => {:variables => rows}
end

get '/graph' do
  variable_ids = params[:vars] || []
  query_type = params[:q]
  combined = params[:combined] == "on"
  case query_type
  when "age"
    from = Date.today - params[:days].to_i
    to = Date.today + 1
  when "timespan"
    from = Date.parse(params[:from])
    to = Date.parse(params[:to])
  end
  
  rows = DB.fetch("SELECT * FROM variables WHERE id IN ?", variable_ids)
  
  slim :graph, :locals => {:variables => rows, :from => from, :to => to, :combined => combined}
end
