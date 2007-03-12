#!/usr/bin/ruby

require 'rexml/document'
require 'optparse'
include REXML

options = {}
OptionParser.new do |opts|
  
  options[:artist_as_tag] = false
  
  opts.banner = "Usage: get_top_tags_for_month.rb [options]"
  opts.on("-v", "--[no-]verbose", "Run verbosely") do |v|
    options[:verbose] = v
  end
  opts.on("-i", "--input-dir DIRECTORY", "Input Weekly data DIRECTORY") do |dir|
    options[:input_directory] = dir
  end

  opts.on("-o", "--output-dir DIRECTORY", "Output DIRECTORY") do |dir|
    options[:output_directory] = dir
  end

  opts.on("-a", "--artists-dir DIRECTORY", "Artists DIRECTORY") do |dir|
    options[:artists_directory] = dir
  end

  opts.on("--artist-as-tag", "--[no-]artist-as-tag", "Use artists as tags") do |art|
    options[:artist_as_tag] = art ? true : false
  end

  # No argument, shows at tail.  This will print an options summary.
  # Try it and see!
  opts.on_tail("-h", "--help", "Show this message") do
    puts opts
    exit
  end

end.parse(ARGV)

p options


class Tag

	@@tagcache = {}
	@@niltag = Tag.new()
	@@globalplaycount = 0

	attr_accessor :count, :name, :globalcount, :playcount

	def Tag.AddTag(tag)
		if ( @@tagcache[tag.name] == nil )
			@@tagcache[tag.name] = @@niltag
		end
		@@tagcache[tag.name] += tag
	end

	def Tag.GetTags()
		return @@tagcache.values
	end

	def Tag.SetTotalPlayCounts(playcount)
		@@globalplaycount += playcount
	end

	def Tag.Reset()
		@@tagcache = {}
		@@globalplaycount = 0
	end

	def +(tag)
			
		if (self == @@niltag)
			return tag
		end
		
		if tag.name == self.name
			self.globalcount += tag.globalcount
			self.playcount += tag.playcount
			self.count += 1
		end
		
		return self
	end

	def prevalence
		return 100 * ( @playcount.to_f / @@globalplaycount.to_f ) 
	end

	def initialize
		@count = 0
	end

end




class WeeklyAnalyser

  attr_accessor :use_artist_as_tag

	def analyseWeek(filename)
		@sourcefile = filename
		xmldoc = Document.new( File.new(filename) )
		totalplays = 0
		xmldoc.root.elements.each("//playcount") { |count|
			totalplays += count.text.to_i
		}
		Tag.SetTotalPlayCounts(totalplays)

		counter = 0
		xmldoc.root.elements.each("artist") { |artist|
			singleplaycount = 0
			artist.elements.each("playcount") { |count|
				singleplaycount += count.text.to_i
			}
			counter += singleplaycount
			artist.elements.each("url") { |url|
				if url.text =~ %r|http://www.last.fm/music/(.*)|
					getTags($1, singleplaycount)
				end
			}
			puts "Complete #{counter} of #{totalplays}"
		}
	end

	def getTags(artist, totalplays)
		
		if use_artist_as_tag
		  return getArtistAsTag(artist,totalplays)
	  end
		
		filename = "#{@artist_data_path}/#{artist}.xml"
		if ! FileTest.exist?(filename)
                  puts "Missing #{filename}"
		  exit
	  end
		xmldoc = Document.new( File.new(filename) )
		xmldoc.root.get_elements("//tag").sort_by { |x|
			x.get_elements("count")[0].text.to_i
		}.reverse[0..10].each { |xmltag|
			newtag = Tag.new()
			newtag.globalcount = xmltag.get_elements("count")[0].text.to_i
			newtag.playcount = totalplays
			newtag.name = xmltag.get_elements("name")[0].text
			if ( newtag.globalcount > 3 )
				Tag.AddTag(newtag)
			end
		}
	end
	
	def getArtistAsTag(artist, totalplays)
	  newtag = Tag.new()
	  newtag.globalcount = 100
	  newtag.playcount = totalplays
	  newtag.name = artist
	  Tag.AddTag(newtag)
  end
	
	def writeResults(outdir)
		xmldoc = Document.new()
		xmldoc.add_element("tagdata")
		Tag.GetTags.sort { |x,y|
			if ( x.prevalence == y.prevalence )
				x.globalcount <=> y.globalcount	
			else
				x.prevalence <=> y.prevalence
			end
		}.reverse.each { |tag|
			tagel = xmldoc.root.add_element("tag")
			tagel.add_element("totalcount").add_text(tag.globalcount.to_s)
			tagel.add_element("timesused").add_text(tag.count.to_s)
			tagel.add_element("prevalence").add_text(tag.prevalence.to_s)
			tagel.add_element("name").add_text(tag.name)
		}
		file = open(WeeklyAnalyser.GetOutputFilename(@sourcefile,outdir), "w")
		xmldoc.write(file)
		file.close()
	end

	def WeeklyAnalyser.GetOutputFilename(input_file, output_directory)
		outfile = /(\d+-\d+).xml/.match(input_file)[1]
		output_directory.gsub!(/\/$/, "")
		return "#{output_directory}/#{outfile}-summary.xml"
	end
	
	def initialize(artist_data_path)
		@artist_data_path = artist_data_path
	end
end

#getopts('h')

#ARGV.size < 3 || $OPT_h and
#	(puts "usage: get_top_tags_for_month weeklydatadir artistdatadir outputdir"; exit 1)

inputdir = options[:input_directory]
artistdatasource = options[:artists_directory]
outdir = options[:output_directory]

inputdir.gsub!(/\/$/, "")
artistdatasource.gsub!(/\/$/, "")

Dir.foreach(inputdir) { |filename|
	if filename =~ /\.xml/
		if ( ! FileTest.exist?( 
				WeeklyAnalyser.GetOutputFilename(
					"#{inputdir}/#{filename}",
					outdir
				)
				)
			)
			analyser = WeeklyAnalyser.new(artistdatasource)
			analyser.use_artist_as_tag = options[:artist_as_tag]
			analyser.analyseWeek("#{inputdir}/#{filename}")
			puts filename
			analyser.writeResults(outdir)
			Tag.Reset()
		end
	end
}



