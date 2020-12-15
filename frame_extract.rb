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

filename = "/Dropbox/Dropbox/LAb/Workplace/Q4/10Dec Titrations/5.5mg-QuinKAT-VID_20201210_063810.mp4"
raise "Input movie filename in ARGV!" unless filename
#smplname = 
Dir.mkdir("temp") if !(Dir.exist?("temp"))
Dir.mkdir("temp/ph") if !(Dir.exist?("temp/ph"))
Dir.mkdir("temp/pump") if !(Dir.exist?("temp/pump"))
Dir.mkdir("temp/preview") if !(Dir.exist?("temp/preview"))


# Phase 1: Grab video parameters, determine timeframe and cropbox, show result
#ask for cropbox input if setting isn't there
# Crop box for pH reading
puts "Attemting reading boxes settings..."
if File.exist? 'boxes.settings'
  ph_box, s_pump_box = box_settings('./boxes.settings')
else
  puts "No setting file found. defaults created."
  ph_box = [100, 100, 200, 100]
  s_pump_box = [300, 300, 200, 100]
end

puts "Preview to align cropboxes?"
ans = gets.chomp
if ans == 'y'
while true
  puts "--Cropboxes preview--"
  mov = FFMPEG::Movie.new(filename)
  puts "Opening file #{filename}"
  puts "Video length: #{mov.duration} seconds"
  puts "Taking preview at 5% and 95% time"
  #mov.screenshot('./temp/preview/5pc.jpg', seek_time: (mov.duration*0.05).to_i, validate: false)
  #puts "ffmpeg -ss #{(mov.duration*0.05).to_i} -i #{filename} -vframes 1 ./temp/preview/05pc.jpg -q 1 -y -loglevel 8"
  puts `ffmpeg -ss #{(mov.duration*0.05).to_i} -i \"#{filename}\" -vframes 1 ./temp/preview/05pc.jpg -q 1 -y -loglevel 8`
  puts `ffmpeg -ss #{(mov.duration*0.95).to_i} -i \"#{filename}\" -vframes 1 ./temp/preview/95pc.jpg -q 1 -y -loglevel 8`
  #mov = FFMPEG::Movie.new(filename)
  #mov.screenshot('./temp/preview/95pc.jpg', seek_time: (mov.duration*0.95).to_i, validate: false)
  draw_boxes(ph_box, s_pump_box, './temp/preview/05pc.jpg')
  draw_boxes(ph_box, s_pump_box, './temp/preview/95pc.jpg')
  pop_preview
  puts "Current crop boxes:"
  puts "pH meter box: #{ph_box}"
  puts "Syringe pump box: #{s_pump_box}"
  puts "Change? (y/N)"
  ans = gets.chomp
  break unless ans == 'y'

  puts "Set pH meter box:"
  result = gets.chomp.split(',').map{ |field| field.to_i }
  if result.size == 4
    ph_box = result
  else
    puts "Error parsing pH meter box parameters. 4 Integers spaced by comma required."
    redo
  end

  puts "Set syringe pump box:"
  result = gets.chomp.split(',').map{ |field| field.to_i }
  if result.size == 4
    s_pump_box = result
  else
    puts "Error parsing syringe pump box parameters. 4 Integers spaced by comma required."
    redo
  end
end
box_settings('./boxes.settings', ph_box, s_pump_box)
end

# Phase 2: exec the screenshotting
puts "Default: taking secondwise shots from 0 to the end. Proceed? (y/N)"
ans = gets.chomp
if ans == 'y'
#mov.screenshot("./temp/frame%d.jpg", { vframes: mov.duration.to_i, frame_rate: '1', quality: 1}, validate: false)
result = `ffmpeg -i #{filename} -f image2 -vframes 600 -r 1 -q:v 1 ./temp/frame%03d.jpg -y`
end
# Phase 3: OCR, put in html table for human check
puts "Going on to OCR"
ocr_out =File.open("ocr.out", "w")
frames = Dir.glob("./temp/frame*.jpg").sort
frames.each do |frame|
  frame_name = File.basename(frame, ".jpg")
  image = Vips::Image.new_from_file frame
  ph_reading = image.crop(ph_box[0], ph_box[1], ph_box[2], ph_box[3])
  s_pump_reading = image.crop(s_pump_box[0], s_pump_box[1], s_pump_box[2], s_pump_box[3])
  ph_reading.write_to_file("./temp/ph/#{frame_name}.jpg")
  s_pump_reading.write_to_file("./temp/pump/#{frame_name}.jpg")

  #OCR
  puts "Processing frame #{frame_name}"
  ocr_out.puts frame_name
  ocr_out.puts RTesseract.new("./temp/pump/#{frame_name}.jpg").to_box
  #ocr_out.puts "pH: " + RTesseract.new("./temp/ph/#{frame_name}.jpg", options: :digits, :lang => 'ssd', :psm => 8).to_box.to_s
  ph_result = `ssocr -d -1 -c decimal ./temp/ph/#{frame_name}.jpg`.to_f
  ocr_out.puts "pH: #{ph_result}"
  ocr_out.puts "--"
end
ocr_out.close