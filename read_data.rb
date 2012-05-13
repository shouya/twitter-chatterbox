
require 'date'
require 'set'

@data_file = 'data/saved.data'



tmp = Marshal.load(File.open(@data_file).read)
puts "-- Glorious Chatterboxes: --"
tmp[:chatterboxes].each do |k,v|
    puts v['screen_name']
end



