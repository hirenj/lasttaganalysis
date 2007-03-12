#!/usr/bin/ruby

require 'rexml/document'
include REXML


inputdir = ARGV[0]
inputdir = inputdir.gsub(/\/$/, "")
tags = {}
filenames = []
counter = 0
filenames = Dir["#{inputdir}/*.xml"]
filenames.each { |filename|
	xmldoc = Document.new( File.new(filename) )
	xmldoc.elements.each("//tag") { |tag|
		tagname = tag.get_elements("name")[0].text()
		prevalence = tag.get_elements("prevalence")[0].text().to_f
		if (tags[tagname] == nil) 
			tags[tagname] = []
			tags[tagname][filenames.size - 1] = 0
		end
		tags[tagname][counter] = prevalence
	}
	counter = counter + 1
}
alltags = tags.keys
totals = {}
alltags = alltags.sort { |x,y|
	xtotal = totals[x]
	ytotal = totals[y]

	if (xtotal == nil)
		xtotal = 0
		tags[x].compact.each { |prev|
			xtotal += prev
		}
		totals[x] = xtotal
	end
	if (ytotal == nil)
		ytotal = 0
		tags[y].compact.each { |prev|
			ytotal += prev
		}
		totals[y] = ytotal
	end
	xtotal <=> ytotal	
}.reverse[0..50]

xmldoc = Document.new()
table = xmldoc.add_element("table")
table.add_attribute('xmlns', 'http://www.w3.org/1999/xhtml')
table.add_attribute('xmlns:pmo', 'http://penguins.mooh.org/music')
table.add_attribute('id','current_data')
table.add_attribute('pmo:tagcolumn','1')
theadrow = table.add_element("thead").add_element("tr")
theadrow.add_element("th").add_text("Position")
theadrow.add_element("th").add_text("Tag")
(1 .. tags["indie"].size).each { |counter|
	theadrow.add_element("th").add_text("Week #{counter.to_s}")
}
theadrow.add_element("th").add_text("Total")
tbody = table.add_element("tbody")
counter = 1
alltags.each { |tagname|
	row = tbody.add_element("tr")
	row.add_attribute("pmo:tagname", tagname);
	row.add_attribute("id", tagname.gsub(/\s+/, "_"));	
	row.add_element("td").add_text(counter.to_s)
	row.add_element("td").add_text(tagname)
	tags[tagname].each { |prev|
		prev = (prev == nil) ? 0 : prev
		row.add_element("td").add_text(sprintf("%0.2f",prev))
	}
	row.add_element("td").add_text(sprintf("%0.2f",totals[tagname]))
	counter += 1
}
file = open("#{inputdir}/summary.xhtml", "w")
xmldoc << XMLDecl.new
xmldoc.write(file)
file.close()