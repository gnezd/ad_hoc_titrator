#Modifying pH meter image for OCR
require 'vips'

image = Vips::Image.new_from_file "./temp/ph/frame7.bmp"

puts image.width
puts image.height

puts image.getpoint(200, 200)
ann = image.draw_circle([0,255,0], 200, 200, 5)
puts image.getpoint(180, 180)
ann.draw_circle([255,255,255], 180, 180, 5).write_to_file "annotated.bmp"

#test = Vips::Image.black image.width, image.height
#mask = [[128,255,128],[255,255,255],[128,255,128]]
#mask = [[128,0,128],[0,0,0],[128,0,128]]
#image.colourspace(:b_w).dilate(mask).write_to_file "eroded.png"
#(0..image.width-1).each do |x|
#    puts "x: #{x}"
#    (0..image.height-1).each do |y|
#        pt = image.getpoint x, y
#        test.draw_point([255,255,255], x, y) if pt[0]+pt[2] < 2 * pt[1]
#    end
#end
matrix = [
    [0, 0, 0],
    [0, 0, 0],
    [-5, 10, -5]
]
bright = image + 50
#bright = bright.rank(3,3,3)
contrast = (bright * 4.5 - 200).colourspace(:b_w)
mask = [[0,128,0],[128,255,128],[0,128,0]]
mask2 = [[128,128,128],[128,0,128],[128,128,128]]
contrast.write_to_file "test.jpg"