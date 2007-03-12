#!/usr/bin/ruby

require 'yaml'

artists = Hash.new()

Dir["data/weeklydata*/*.xml"].each { |weekly|
  puts "Weekly is #{weekly}"
  begin
  week =File.new(weekly)
  week.readlines.delete_if { |line| /<url>.*<\/url>/ !~ line }.each { |url|
    url.sub!('http://www.last.fm/music/','')
    url.sub!('<url>','')
    url.sub!('</url>','')
    details = Hash.new()
    url.strip!
    artists[url] = { :mbid => 1 }
  }
  rescue Exception => e
    puts "Had a problem with #{weekly}"
  end
}

File.open('data/artistlist.yaml','w') { |file|
  file << artists.keys.sort.to_yaml
}