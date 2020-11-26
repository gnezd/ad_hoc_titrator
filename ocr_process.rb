#!/usr/bin/ruby
#Processing OCR result

ocr_file = 'QuinKAT.ocr'
time_start_coord = [175,186,1,10]
volume_start_coord = [158,170,80,95]

fin = File.open(ocr_file, 'r')
result = Array.new { ["", "", "", ""] } #frame_name, time, volume, pH
frame_name = ""
time = ""
volume = ""
ph = ""

fin.each_line do |line|
  if line =~ /^frame/
    frame_name = line.chomp
    next
  end
  if line.chomp == '--'
    result.push [frame_name, time, volume, ph]
    #puts '--'
    next
  end
  begin
  y_start = line.split('y_start=>')[1].split(',')[0].to_i
  x_start = line.split('x_start=>')[1].split(',')[0].to_i
  word = line.split(':word=>"')[1].split('",')[0].to_s

  if  x_start > time_start_coord[0] && x_start < time_start_coord[1] && y_start > time_start_coord[2] && y_start < time_start_coord[3]
    time = word
    #puts time
  end

  if x_start > volume_start_coord[0] && x_start < volume_start_coord[1] && y_start > volume_start_coord[2] && y_start < volume_start_coord[3]
    volume = word
    #puts volume
  end
  
  if line =~/^pH/
    ph = line.split(':word=>"')[1].split('",')[0].to_s
    #puts ph
  end
rescue
end
end

tsvoutfile = 'QuinKAT.tsv'
fout = File.open(tsvoutfile, "w")

result.each do |point|
  fout.puts point.join "\t"
end

fout.close
