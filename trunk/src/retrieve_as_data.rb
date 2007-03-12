#!/usr/bin/ruby

require 'net/http'
require 'rexml/document'
require 'optparse'
include REXML

options = {}
optparser = OptionParser.new do |opts|
  
  options[:test] = false
  options[:username] = nil
  
  opts.banner = "Usage: retrieve_as_data.rb [options]"
  opts.on("-v", "--[no-]verbose", "Run verbosely") do |v|
    options[:verbose] = v
  end

  opts.on("-u", "--username USERNAME","USERNAME on Last.fm") do |username|
    options[:username] = username
  end

  opts.on("--test") do
    options[:test] = true
  end

  # No argument, shows at tail.  This will print an options summary.
  # Try it and see!
  opts.on_tail("-h", "--help", "Show this message") do
    puts opts
    exit
  end

end.parse(ARGV)



def get_weekly_data(username, from, to,test=false)  
  return if FileTest.exist?("data/weeklydata-#{username}/#{from}-#{to}.xml")
  sleep 2
  begin
    http = Net::HTTP.new("ws.audioscrobbler.com", 80)
    if ! test
	    chart = http.get("http://ws.audioscrobbler.com/1.0/user/#{username}/weeklyartistchart.xml?from=#{from}&to=#{to}",{"User-Agent" => "HirenjauLastFmStats/0.1"}).body
	  else
	    puts "http://ws.audioscrobbler.com/1.0/user/#{username}/weeklyartistchart.xml?from=#{from}&to=#{to}"
    end
	  File.open("data/weeklydata-#{username}/#{from}-#{to}.xml","w") { |file|
	    file << chart
    }
  rescue Exception => e
    puts e
    exit
  end
end

username = options[:username]

unless username != nil
  puts optparser
  exit
end

puts options

http = Net::HTTP.new("ws.audioscrobbler.com", 80)

chartlist = http.get("/1.0/user/#{username}/weeklychartlist.xml",{"User-Agent" => "HirenjauLastFmStats/0.1"}).body

doc = Document.new chartlist

if FileTest.directory?("data/weeklydata-#{username}")
	puts "\nDirectory already exists. Will not overwrite current data"
else
	Dir.mkdir("data/weeklydata-#{username}")
end

doc.elements.each('*/chart') { |chart|
  get_weekly_data(username,chart.attribute('from').value, chart.attribute('to').value,options[:test])
}