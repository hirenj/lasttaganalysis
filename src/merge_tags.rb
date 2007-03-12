#!/usr/bin/ruby

require 'rexml/document'
require 'optparse'
include REXML

options = {}
optparser = OptionParser.new do |opts|
  
  options[:test] = false
  options[:overwrite] = false
  options[:inputdir] = nil
  options[:outputdir] = nil
  
  opts.banner = "Usage: merge_tags.rb [options]"
  opts.on("-v", "--[no-]verbose", "Run verbosely") do |v|
    options[:verbose] = v
  end

  opts.on("-i", "--input-dir DIRECTORY","DIRECTORY to retrieve artist data from") do |directory|
    options[:inputdir] = directory
  end

  opts.on("-o", "--output-dir DIRECTORY","DIRECTORY to write artist data to") do |directory|
    options[:outputdir] = directory
  end

  opts.on("--force-overwrite") do
    options[:overwrite] = true
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


class Tag
  attr_accessor :name, :count, :url
  def initialize
    @count = 0
  end
end

class Replace
  attr_accessor :pattern
  attr_accessor :substitution
end

class SynonymNormaliser
	
	@@SYNONYMSDEF = Document.new( File.new("data/synonyms.xml") ).root

	@@SINGLE_REPLACES = Array.new()
	@@MULTIPLE_REPLACES = Array.new()


	@@SYNONYMSDEF.
		elements.each('synonym') { |syn|
			
			synname = syn.attributes.get_attribute("name").value
			
			syn.elements.each("synonym[count(synonym)=0]") { |substitution|
			  replace = Replace.new()
			  replace.pattern = synname
			  replace.substitution = substitution.text
			  @@SINGLE_REPLACES << replace
      }
			syn.elements.each("synonym[count(synonym)>1]") { |multireplace|
        replace = Replace.new()
        replace.pattern = synname
        replace.substitution = multireplace.get_elements("synonym").collect { |node|
					node.text
				}
				@@MULTIPLE_REPLACES << replace
      } 
    }
	
	@todelete = {}
	
	def fix_synonyms()
		@@SINGLE_REPLACES.each { |replace|
			replace_node( replace.pattern, replace.substitution )
		}
		
		@todelete.values.each { |element|
			@toptags.delete(element.name)
		}
		@todelete = {}
		
		@@MULTIPLE_REPLACES.each { |replace|
		  merge_all_tags( replace.pattern, replace.substitution )
		}
		
		@todelete.values.each { |element|
			@toptags.delete(element.name)
		}
		@toptags.delete('todelete')
		@todelete = {}
	end

	def replace_node(newname, oldname)
		newname = newname.downcase
		oldname = oldname.downcase
		oldtag = @toptags[oldname]
		return if oldtag == nil
		newtag = @toptags[newname]
		if (newtag == nil)
		  newtag = Tag.new()
		  newtag.name = newname
		end
		newtag.count = oldtag.count + newtag.count
		@todelete[oldname] = oldtag
		@toptags[newname] = newtag
	end

	def merge_all_tags(newname, oldnames)
		newname = newname.downcase
		oldelements = oldnames.collect { |oldname|
			oldname = oldname.downcase
			oldelement = @toptags[oldname]
			if (oldelement != nil && oldelement.count > 5 )
				oldelement
			else
				nil
			end
		}.compact

		if oldelements.nitems != oldnames.nitems
			return
		end

		target = @toptags[newname]
		if (target == nil)
		  target = Tag.new()
		  target.name = newname
		end

		min = nil
		oldcount = target.count
		oldelements.each { |oldnode|
			count = oldnode.count
			if min == nil || count < min
				min = count
			end
			@todelete[oldnode.name] = oldnode
		}
		newcount = oldcount + min
		target.count = newcount
		@toptags[newname] = target
	end

	def initialize(filename)
		artistdoc = Document.new( File.new(filename) ).root
		
		@toptags = Hash.new()
		
		artistdoc.elements.each('tag') { |xml_tag|
		  tag = Tag.new()
		  tag.name = xml_tag.get_elements('name').first.text
		  tag.count = xml_tag.get_elements('count').first.text.to_i
		  tag.url = xml_tag.get_elements('url').first.text
		  @toptags[tag.name] = tag
		}
		@todelete = {}
	end

	def filter_lowercase()
		@toptags.values.each { |tag|
			tag.name = tag.name.downcase
		}
	end

	def SynonymNormaliser.Get_Version
		version = @@SYNONYMSDEF.attributes.get_attribute("version").value
		if ( svnversion = /\$Rev:\s+(\d+)\s+\$/.match(version) )
			return "svn-r"+svnversion[1]
		end
		return version
	end

	def write_output(filename)
		file = open(filename,"w")
		result = Document.new()
		result << Element.new('toptags')
		@toptags.values.sort_by { |el| el.count }.reverse.each { |el|
      tag = Element.new('tag')
      newel = Element.new('name')
      newel.add Text.new( el.name )
      tag << newel
      newel = Element.new('count')
      newel.add Text.new( el.count.to_s )
      tag << newel
      newel = Element.new('url')
      newel.add Text.new( el.url || '' )
      tag << newel
		  result.root << tag
		}
		result.write(file)
		file.close()
	end
end


inputdir = options[:inputdir]
outdir = options[:outputdir]

unless inputdir != nil && outdir != nil
  puts optparser
  exit
end

outdir.gsub(/\/$/, "")
inputdir.gsub(/\/$/, "")
inputdir += "/"
outdir += "/artists-synonyms-"+SynonymNormaliser.Get_Version
if FileTest.directory?(outdir)
  if ! options[:overwrite]
	  puts "\nDirectory already exists. Will not overwrite current data"
  else
    puts "\nWill overwrite data in directory"
  end
else
	Dir.mkdir(outdir)
end
Dir.entries(inputdir).sort.each { |filename|
	if filename =~ /\.xml/
		if ( options[:overwrite] || ! FileTest.exist?(outdir+"/"+filename) ) 
  		puts "Converting #{filename}"
			normaliser = SynonymNormaliser.new( inputdir.to_s+filename)
			normaliser.filter_lowercase()
			normaliser.fix_synonyms()
			if ! options[:test]
			  normaliser.write_output(outdir+"/"+filename)
	    end
		end
	end
}
