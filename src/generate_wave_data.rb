#!/usr/bin/ruby

require 'rexml/document'
require 'optparse'
require 'cgi'
include REXML

options = {}
OptionParser.new do |opts|
  
  options[:averaging] = 1
  options[:lowpass_cutoff] = 0
  options[:weekly_cutoff] = 10
  options[:width_function] = :normalised
  options[:label_all] = false
  options[:week_labels] = true
  options[:web_label] = false
  options[:offset] = :none
  
  opts.banner = "Usage: generate_wave_data.rb [options]"
  opts.on("-v", "--[no-]verbose", "Run verbosely") do |v|
    options[:verbose] = v
  end
  opts.on("-d", "--input-dir DIRECTORY", "Input DIRECTORY") do |dir|
    options[:input_directory] = dir
  end

  opts.on("-o", "--output FILENAME", "Output FILENAME") do |filename|
    options[:out_file] = filename
  end

  opts.on("--artist-analysis", "--[no-]artist-analysis", "Do an artist analysis") do |art|
    options[:averaging] = 3
    options[:lowpass_cutoff] = 0
    options[:weekly_cutoff] = 30
    options[:width_function] = :normalised
    options[:offset] = :median
  end

  opts.on("--tag-analysis", "--[no-]tag-analysis","Do a tag analysis") do |tag|
    options[:averaging] = 3
    options[:lowpass_cutoff] = 0
    options[:weekly_cutoff] = 10
    options[:width_function] = :raw
    options[:offset] = :median
  end

  opts.on("--weekly-cutoff CUTOFF", Integer,"Maximum number of points to take from a week CUTOFF") do |cutoff|
    options[:weekly_cutoff] = cutoff
    # Tags 10
    # Artists 30
  end
  opts.on("--lowpass-cutoff CUTOFF", Integer,"Number of data points to cut off from total vocabulary CUTOFF") do |cutoff|
    options[:lowpass_cutoff] = cutoff
    # Tags 3
    # Artists 0
  end
  opts.on("--averaging [AMOUNT]", [:none,:three,:five], "Select averaging for data points (none, three, five) weeks") do |ave|
    if ave == :three
      options[:averaging] = 3
    end
    if ave == :five
      options[:averaging] = 5
    end
    if ave == :none
      options[:averaging] = 1
    end
    #Default 3
  end
  opts.on("--offset [OFFSET]", [:none,:curve,:median],"Select offsetting method (none,curve,median)") do |method|
    options[:offset] = method
  end
  
  opts.on("--function [FUNCTION]", [:raw,:log_squared,:normalised], "Select function for band width (raw, log_squared, normalised)") do |func|
    options[:width_function] = func
    # Artists normalised
    # Tags raw
  end

  opts.on("--label-all") do
    options[:label_all] = true
  end

  opts.on("--no-week-labels") do
    options[:week_labels] = false
  end

  opts.on("--web-label") do
    options[:web_label] = true
  end

  # No argument, shows at tail.  This will print an options summary.
  # Try it and see!
  opts.on_tail("-h", "--help", "Show this message") do
    puts opts
    exit
  end

end.parse(ARGV)
p options

inputdir = options[:input_directory].gsub(/\/$/, "")
tags = {}
filenames = []
counter = 0
filenames = Dir["#{inputdir}/*.xml"].sort

TOTAL_RESULTS = 100

max_rank = 0

class RGB
  attr_accessor :r,:g,:b
  def initialize(r=0,g=0,b=0)
    @r = r
    @g = g
    @b = b
  end
  
  def to_hex
    return sprintf("#%02x%02x%02x",(@r*255).floor,(@g*255).floor,(@b*255).floor)
  end
end

class HSV
  attr_accessor :h,:s,:v
  def initialize(h=0,s=0,v=0)
    @h = h.to_f
    @s = s.to_f
    @v = v.to_f
  end
  
  def to_rgb
    sextant = (@h / 60).floor.modulo(6)
    f = (@h / 60.0) - sextant.to_f
    p = @v * (1 - @s)
    q = @v * (1 - f * @s)
    t = @v * (1 - (1 - f) * @s)
    case sextant
    when 0
      return RGB.new(@v,t,p)
    when 1
      return RGB.new(q,@v,p)
    when 2
      return RGB.new(p,@v,t)
    when 3
      return RGB.new(p,q,@v)
    when 4
      return RGB.new(t,p,@v)
    when 5
      return RGB.new(@v,p,q)
    end
  end
  def to_hex
    to_rgb.to_hex
  end
end


class PrevalenceData < Array
  attr_accessor :rank
  attr_accessor :first_seen
  attr_accessor :space_for_label
end

class PlotPoints < Array
  attr_accessor :original_prevalence
  attr_accessor :calculated_height
end

def printout(number)
  return sprintf("%0.2f",number)
end


total_prevs = []
average_prevs = Hash.new()
tag_ranks = Hash.new()
tag_counts = []
max_tag_count = nil
max_prev = nil

filenames.each { |filename|
	xmldoc = Document.new( File.new(filename) )
	total_prevs[counter] = 0
	all_prevs = []
	xmldoc.elements.each("//prevalence") { |prev|
	  all_prevs << prev.text().to_f
	}
	all_prevs = all_prevs.sort.reverse
	tag_counts << all_prevs.size
	
	if max_tag_count == nil || all_prevs.size > max_tag_count
	  max_tag_count = all_prevs.size
  end
	
	#puts "Doing week #{counter}"
	xmldoc.elements.each("//tag") { |tag|
		tagname = tag.get_elements("name")[0].text()
		prevalence = tag.get_elements("prevalence")[0].text().to_f

		unless prevalence < (all_prevs[options[:weekly_cutoff]] || 0)
		  #puts "Adding #{tagname} prev #{prevalence} which is > than #{all_prevs[10]}"
		  if (tags[tagname] == nil)
		    average_prevs[tagname] = 0
			  tags[tagname] = PrevalenceData.new()
			  tags[tagname].first_seen = counter
			  tags[tagname].rank = max_rank + 1
			  max_rank = max_rank + 1
		  end
		  tags[tagname][counter] = prevalence
		  average_prevs[tagname] = average_prevs[tagname] + prevalence
		  total_prevs[counter] = total_prevs[counter] + prevalence
	  end
	}
	if max_prev == nil || total_prevs[counter] > max_prev
	  max_prev = total_prevs[counter]
  end
	counter = counter + 1
}

file_count = filenames.size - 1
# Filter out this so that only the top 100 tags come out per week

alltags = tags.keys
alltags = alltags.sort_by { |x|
	xtotal = 0
	tags[x].compact.each { |prev|
		xtotal += prev
	}
	xtotal	
}.reverse[options[:lowpass_cutoff]..TOTAL_RESULTS].sort_by { |tag|
  tags[tag].rank
}

# Generate co-ordinates, replacing the prevalence
curr_rank = 0
min_ys = []
max_ys = []
weekly_heights = []

alltags.each { |tag|
  first_point = tags[tag].first_seen
  (first_point..file_count).each { |week|
    prev = tags[tag][week] || 0
    tags[tag][week] = PlotPoints.new()
    tags[tag][week].original_prevalence = prev
    if options[:averaging] >= 3
      prev = (week == 0 || tags[tag][week - 1] == nil) ? prev : prev + (tags[tag][week - 1].original_prevalence || 0)
      prev = tag[tag][week + 1] == nil ? prev : prev + (tags[tag][week + 1] || 0)
      prev = prev / 5.0
    elsif options[:averaging] >= 5
      prev = (week == 0 || week == 1 || tags[tag][week - 2] == nil) ? prev : prev + (tags[tag][week - 2].original_prevalence || 0)
      prev = tag[tag][week + 2] == nil ? prev : prev + (tags[tag][week + 2] || 0)
      prev = prev / 5.0
    end
    
    # BEST FOR ARTISTS
    if options[:width_function] == :normalised
      height = 300.to_f * prev / total_prevs[week]
    end
    if options[:width_function] == :log_squared
      height = (1.0+Math.log(prev+1))**1.5
    end
    
    #height = Math.log(prev+1)

    # BEST FOR TAGS
    if options[:width_function] == :raw
      height = prev
    end
    
    tags[tag][week].calculated_height = height
    if weekly_heights[week] == nil
      weekly_heights[week] = 0
    end
    weekly_heights[week] = weekly_heights[week] + height
    
    #curve_offset = 10*Math.log(100.0 * total_prevs[week] / max_prev)
    if options[:offset] == :curve
      curve_offset = 10*Math.log(100.0 * tag_counts[week] / max_tag_count)
    else
      curve_offset = 0
    end
    
    if curr_rank == 0
      max_ys[week] = curve_offset + 0 + (height / 2.0)
      min_ys[week] = curve_offset + 0 - (height / 2.0)
      tags[tag][week][0] = min_ys[week]
      tags[tag][week][1] = max_ys[week]
    elsif curr_rank.modulo(2) == 1
      tags[tag][week][0] = curve_offset + 0
      tags[tag][week][1] = max_ys[week] + height+ 0
      max_ys[week] = max_ys[week] + height + 0
    else
      tags[tag][week][0] = min_ys[week] - height - 0
      tags[tag][week][1] = curve_offset + 0
      min_ys[week] = min_ys[week] - height - 0
    end
  }
  tags[tag].rank = curr_rank
  curr_rank = curr_rank + 1
}

alltags.each { |tag|
  first_point = tags[tag].first_seen
  
  
  if first_point > 0
    if options[:offset] == :curve
      curve_offset = 10*Math.log(100.0 * tag_counts[first_point - 1] / max_tag_count)
    else
      curve_offset = 0
    end
    tags[tag][first_point - 1] = PlotPoints.new()
    tags[tag][first_point - 1].calculated_height = 0    
    tags[tag].first_seen = first_point - 1

    if tags[tag].rank.modulo(2) == 1
      tags[tag][first_point - 1] << curve_offset
      tags[tag][first_point - 1] << max_ys[first_point - 1]
    else
      tags[tag][first_point - 1] << min_ys[first_point -1]
      tags[tag][first_point - 1] << curve_offset
    end
  end
}

xmldoc = Document.new()
svg = xmldoc.add_element("svg")
svg.add_attribute('xmlns', 'http://www.w3.org/2000/svg')
svg.add_attribute('version','1.1')
svg.add_attribute('viewBox', "-25 -110 #{((file_count+2)*10) + 25} 200")
svg.add_attribute('width','100%')
svg.add_attribute('height','100%')
svg.add_attribute('preserveAspectRatio', 'xMinYMin')

alltags.reverse.each { |tag|
  path = ""
  plain_tag = CGI::unescape(CGI::unescape(tag))
  
  group = svg.add_element('g')
  week_group = svg.add_element('g')
  poly = group.add_element('polygon')

  (tags[tag].first_seen..file_count).each { |week|
    if tags[tag].rank == 1 && options[:week_labels] && week.modulo(8) == 0
      epoch_seconds =  filenames[week].scan(/\d+/)[1].to_i
      epoch_week = Time.at(epoch_seconds).strftime("%B")
      label = week_group.add_element('text')
      label.add_text(epoch_week)
      label.add_attribute('x', (week * 10).to_s)
      label.add_attribute('y', -100)
      label.add_attribute('stroke','none')
      label.add_attribute('fill', '#888888')
      label.add_attribute('font-size', '12')
      label.add_attribute('text-anchor','middle')
    end

    median_offset = 0

    if options[:offset] == :median
      median_offset = ( weekly_heights[week] / 2.0 ) - max_ys[week]
    end
    
    path = path + " #{week * 10},#{printout(tags[tag][week][0]-0.2+median_offset)} " 
    if tags[tag][week].calculated_height > 10
      if tags[tag].space_for_label == true
        label = group.add_element('text')
        label.add_text(plain_tag)
        label.add_attribute('x', (week * 10).to_s)
        y_val = (tags[tag].rank.modulo(2) == 1) ? ((tags[tag][week][1])  -  (tags[tag][week].calculated_height / 2)) : ((tags[tag][week][0]) + (tags[tag][week].calculated_height / 2 ))
        y_val = y_val + median_offset
        label.add_attribute('y', y_val)
        label.add_attribute('fill', '#bbbbbb')
        label.add_attribute('font-size', (tags[tag][week].calculated_height / 3).to_s)
        tags[tag].space_for_label = false
      end
    else
      tags[tag].space_for_label = true
    end
  }
  (tags[tag].first_seen..file_count).to_a.reverse.each  { |week|
    median_offset = 0
    if options[:offset] == :median
      median_offset = ( weekly_heights[week] / 2.0 ) - max_ys[week]
    end

    path = path + " #{week * 10},#{printout(tags[tag][week][1]+0.2+median_offset)} "
  }
  label = nil
  if options[:label_all]
    median_offset = 0
    if options[:offset] == :median
      median_offset = ( weekly_heights[tags[tag].first_seen] / 2.0 ) - max_ys[tags[tag].first_seen]
    end

    label = group.add_element('text')
    label.add_text(plain_tag)
    label.add_attribute('x', (tags[tag].first_seen * 10).to_s)
    y_val = (tags[tag].rank.modulo(2) == 1) ? (tags[tag][tags[tag].first_seen][1]) : (tags[tag][tags[tag].first_seen][0])
    label.add_attribute('y', y_val+median_offset)
    label.add_attribute('size', '0.5')
  end
  poly.add_attribute('points',path)
  poly.add_attribute('stroke','#000000')
  poly.add_attribute('stroke-width','0')
  if options[:web_label]  
      bigtext = group.add_element('text')
      bigtext.add_text(plain_tag)
      bigtext.add_attribute('x','30')
      bigtext.add_attribute('y','-50')
      bigtext.add_attribute('fill','#000000')
      bigtext.add_attribute('class','bigtext')
  end
  hue = (170 * (1 - (tags[tag].first_seen.to_f / file_count.to_f))).floor + 50
  
  poly.add_attribute('fill',HSV.new(hue,(10.0-tags[tag].rank.modulo(5).to_f) / 15.0,0.71).to_hex)

  if label != nil
    label.add_attribute('fill', poly.attributes['fill'])
  end
}

file = open(options[:out_file], "w")
xmldoc << XMLDecl.new
xmldoc.write(file)
file.close
