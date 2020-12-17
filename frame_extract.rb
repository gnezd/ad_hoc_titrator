# Single shoot test prototype
# Purpose: Parse frame from the test data, slice monitoring windows, locate them? Then OCR.
# Implement: ruby-vips for image
require 'vips'
require 'streamio-ffmpeg' # https://github.com/streamio/streamio-ffmpeg
require 'rtesseract'

def pop_preview
  preview_layout = <<LAYOUTEND
  <html>
  <head><title>Previewing 5% and 95% time frame</title></head>
  <body>
  <table width="800 px">
  <tr>
  <td><img src ="./05pc.jpg"></td>
  <td><img src ="./95pc.jpg"></td>
  </tr>
  <tr>
  <td>time 0.05</td>
  <td>time 0.95</td>
  </tr>
  </table>
  </body>
  </html>
LAYOUTEND

  layout_html = File.open('./temp/preview/view.html', 'w')
  layout_html.puts preview_layout
  layout_html.close
  `open ./temp/preview/view.html` #Just convinience for previewing
end

def draw_boxes(ph_box, s_pump_box, filename)
  image = Vips::Image.new_from_file filename
  image = image.draw_rect([255, 50, 50], ph_box[0], ph_box[1], ph_box[2], ph_box[3])
  image = image.draw_rect([50, 255, 50], s_pump_box[0], s_pump_box[1], s_pump_box[2], s_pump_box[3])
  overlay_text = Vips::Image.text('pH box', :font => 'sans 30')#.copy(:interpretation => :rgb)
  image = image.composite(overlay_text, :over, :x => ph_box[0], :y => ph_box[1]-30)
  overlay_text = Vips::Image.text('Syringe pump box', :font => 'sans 30')#.copy(:interpretation => :rgb)
  image = image.composite(overlay_text, :over, :x => s_pump_box[0], :y => s_pump_box[1]-30)
  image.write_to_file filename
end

def box_settings(filename, ph_box = nil, s_pump_box = nil)
  if ph_box == nil && s_pump_box == nil
    #read setting
    fin = File.open(filename, "r")
    fin.each_line do |line|
      if line =~ /^ph\_box/
        ph_box = line.chomp.split('=')[1].split(',').map{ |field| field.to_i }
        raise "ph_box setting corrupt: #{line}" unless ph_box.size == 4
      end
      if line =~ /^s\_pump\_box/
        s_pump_box = line.chomp.split('=')[1].split(',').map{ |field| field.to_i }
        raise "s_pump_box setting corrupt: #{line}" unless s_pump_box.size == 4
      end
    end
    return ph_box, s_pump_box
  elsif ph_box.is_a?(Array) && s_pump_box.is_a?(Array)
    puts "Attempt to write box settings..."
    raise "ph_box not an Array(4)" unless ph_box.size == 4
    raise "s_pump_box not an Array(4)" unless s_pump_box.size == 4
    fout = File.open(filename, "w")
    fout.puts "ph_box=#{ph_box.join(',')}"
    fout.puts "s_pump_box=#{s_pump_box.join(',')}"
    fout.close
  else
    raise "Strange input!"
  end
end

filename = ARGV[0]
Dir.mkdir("temp") if !(Dir.exist?("temp"))
Dir.mkdir("temp/ph") if !(Dir.exist?("temp/ph"))
Dir.mkdir("temp/pump") if !(Dir.exist?("temp/pump"))
Dir.mkdir("temp/preview") if !(Dir.exist?("temp/preview"))

frames = Dir.glob("./temp/frame*.jpg").sort # Find existing frames
unless frames == []
  puts "Found some decoded frames under './temp'. Work with these (Y) or read in a new movie file (n)?"
  ans = $stdin.gets.chomp
end

unless ans == 'Y' || ans == 'y'
  if filename == nil
    puts "Type in movie file name:"
    filename = $stdin.gets.chomp
  end

  puts "Opening file #{filename}"
  mov = FFMPEG::Movie.new(filename)
  puts "Video length: #{mov.duration} seconds"

  # Execute the screenshotting
  puts "Taking secondwise shots every second from 0 to the end. Proceed? (y/N)"
  ans = $stdin.gets.chomp
  if ans == 'y'
    result = `ffmpeg -i #{filename} -f image2 -vframes 600 -r 1 -q:v 1 ./temp/frame%03d.jpg -y`
  else
    puts "Aborting."
    exit
  end
  frames = Dir.glob("./temp/frame*.jpg").sort # Load frames
end

# Determine cropboxes, show result if demanded
puts "Attemting reading boxes settings..."
if File.exist? 'boxes.settings'
  ph_box, s_pump_box = box_settings('./boxes.settings')
else
  puts "No setting file found. defaults created."
  ph_box = [100, 100, 200, 100]
  s_pump_box = [300, 300, 200, 100]
end

puts "Preview to align cropboxes?"
ans = $stdin.gets.chomp
if ans == 'y'
  while true
    puts "--Cropboxes preview--"
    puts "Taking preview at 5% and 95% time"
    previews = [frames[(0.05 * frames.size).to_i], frames[(0.95 * frames.size).to_i]]
    `cp '#{previews[0]}' './temp/preview/05pc.jpg'`
    `cp '#{previews[1]}' './temp/preview/95pc.jpg'`
    draw_boxes(ph_box, s_pump_box, './temp/preview/05pc.jpg')
    draw_boxes(ph_box, s_pump_box, './temp/preview/95pc.jpg')
    pop_preview
    puts "Current crop boxes:"
    puts "pH meter box: #{ph_box}"
    puts "Syringe pump box: #{s_pump_box}"
    puts "Change? (y/N)"
    ans = $stdin.gets.chomp
    break unless ans == 'y'

    puts "Set pH meter box:"
    result = $stdin.gets.chomp.split(',').map{ |field| field.to_i }
    if result.size == 4
      ph_box = result
    else
      puts "Error parsing pH meter box parameters. 4 integers spaced by comma required."
      redo
    end

    puts "Set syringe pump box:"
    result = $stdin.gets.chomp.split(',').map{ |field| field.to_i }
    if result.size == 4
      s_pump_box = result
    else
      puts "Error parsing syringe pump box parameters. 4 integers spaced by comma required."
      redo
    end
  end
  box_settings('./boxes.settings', ph_box, s_pump_box)
end

# OCR, put in html table for human check?
puts "Going on to OCR"
ocr_out =File.open("ocr.out", "w")
pHs = Array.new(frames.size)
s_pump_boxes = Array.new(frames.size) {Hash.new}

frames.each_with_index do |frame, index|
  frame_name = File.basename(frame, ".jpg")
  image = Vips::Image.new_from_file frame
  ph_reading = image.crop(ph_box[0], ph_box[1], ph_box[2], ph_box[3])
  s_pump_reading = image.crop(s_pump_box[0], s_pump_box[1], s_pump_box[2], s_pump_box[3])
  ph_reading.write_to_file("./temp/ph/#{frame_name}.jpg")
  s_pump_reading.write_to_file("./temp/pump/#{frame_name}.jpg")

  # OCR
  puts "Processing frame #{frame_name}"
  s_pump_boxes[index] = RTesseract.new("./temp/pump/#{frame_name}.jpg").to_box
  ph_result = `ssocr -d -1 -c digits ./temp/ph/#{frame_name}.jpg`.chomp
  ph_result = ph_result.gsub('_', '')
  pHs[index] = "#{ph_result[0]}.#{ph_result[-2..-1]}"
end

volume_boxes = Array.new(frames.size)
time_boxes = Array.new(frames.size)

#s_pump_boxes.each do |boxes|
(0..frames.size - 1).each do |index|
  # Use index access instead of pushing to avoid missing boxes messing up alignment
  s_pump_boxes[index].each do |box|
    if box[:x_start] >= 0.5 * s_pump_box[2]
      # 2nd column boxes
      if box[:y_start] >= 0.2 * s_pump_box[3] && box[:y_start] <= 0.4 * s_pump_box[3]
        # Remaining time
      elsif box[:y_start] <= 0.2 * s_pump_box[3]
        # Elapsed time 
        time_boxes[index] = box
      end
      if box[:y_end] >= 0.75 * s_pump_box[3] && box[:x_start] <= 0.85 * s_pump_box[2]
        # Volume
        volume_boxes[index] = box
      end
    end
  end
  ocr_out.puts "#{index}\t#{time_boxes[index][:word]}\t#{volume_boxes[index][:word]}\t#{pHs[index]}"
end
ocr_out.close