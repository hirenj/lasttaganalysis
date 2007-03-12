#!/usr/bin/ruby

require 'rexml/document'
require 'net/http'
require 'yaml'

def get_weekly_data(name)
  if FileTest.exist? "data/artists/#{name}.xml"
    if (File.ctime "data/artists/#{name}.xml") > ( Time.now - ( 60 * 60 * 24 * 365 ) )
      puts "Skipping #{name}"
      return
    end
  end
  puts "Doing #{name}"
  begin
    http = Net::HTTP.new("ws.audioscrobbler.com", 80)
    tags = http.get("/1.0/artist/#{name}/toptags.xml",{"User-Agent" => "HirenjauLastFmStats/0.1"}).body
    File.open("data/artists/#{name}.xml",'w') {|file|
      file << tags
    }
  rescue Exception => e
    puts "Failed getting #{name} #{e}"
  end
  sleep 5
end

artists = YAML::load(File.new('data/artistlist.yaml'))
artists.each { |name|
  get_weekly_data(name)
}
