#!/bin/env ruby
require 'rubygems'
require 'date'
require 'sinatra'
require 'sequel'
require 'slim'

DB = Sequel.mysql(:user => 'root', :password => 'root', :host => 'localhost', :database => 'eta')

get '/' do
  redirect '/variables'
end

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
  rows = DB.fetch("SELECT * FROM variables ORDER BY name")
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
  
  legend = DB.fetch("SELECT DISTINCT(str_value), dec_value, variables.id AS variable_id, `name` FROM `values`, variables " +
                    "WHERE variables.id = variable_id AND unit = 'B' ORDER BY `name`, dec_value and variable_id in ?",
                    variable_ids)

  legend = legend.to_a.group_by {|e| e[:variable_id]}

  slim :graph, :locals => {:variables => rows, :from => from, :to => to, :legend => legend, :combined => combined}
end

