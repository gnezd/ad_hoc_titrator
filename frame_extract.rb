#Single shoot test prototype
#Purpose: Parse frame from the test data, slice monitoring windows, locate them? Then OCR.
#Implement: ruby-vips for image
require 'vips'
require 'streamio-ffmpeg'
require 'rtesseract'

Dir.mkdir("temp") if !(Dir.exist?("temp"))
Dir.mkdir("temp/ph") if !(Dir.exist?("temp/ph"))
Dir.mkdir("temp/pump") if !(Dir.exist?("temp/pump"))
filename = "./test_clips/VID_20201023_175103.mp4"

mov = FFMPEG::Movie.new(filename)
mov.screenshot("./temp/frame%d.bmp", {vframes: 20, frame_rate: '1/2'}, validate: false)

#Crop box for pH reading
ph_box = [700, 700, 360, 230]
s_pump_box = [500, 145, 400, 230]
frames = Dir.glob("./temp/*.bmp").sort
frames.each do |frame|
    frame_name = File.basename(frame, ".bmp")
    image = Vips::Image.new_from_file frame
    ph_reading = image.crop(ph_box[0], ph_box[1], ph_box[2], ph_box[3])
    #puts ph_reading.class
    #puts ph_reading.bands
    #ph_b_w = ph_reading.colourspace :b_w
    #puts ph_b_w.class
    #puts ph_b_w.bands
    #ph_b_w.write_to_file("./temp/ph/b_w_#{frame_name}.jpg")
    s_pump_reading = image.crop(s_pump_box[0], s_pump_box[1], s_pump_box[2], s_pump_box[3])
    image = image.draw_rect([255, 50, 50], ph_box[0], ph_box[1], ph_box[2], ph_box[3])
    image = image.draw_rect([50, 255, 50], s_pump_box[0], s_pump_box[1], s_pump_box[2], s_pump_box[3])
    image.write_to_file frame
    puts "Frame #{frame} has size: #{image.size}"
    
    ph_reading.write_to_file("./temp/ph/#{frame_name}.bmp")
    puts "pH OCR"
    puts RTesseract.new("./temp/ph/#{frame_name}.bmp").to_box
    s_pump_reading.write_to_file("./temp/pump/#{frame_name}.bmp")
    puts "Pump OCR"
    puts RTesseract.new("./temp/pump/#{frame_name}.bmp").to_box[-3..-1]
end