require 'date'
require 'json'

class Hash
  def self.recursive
    new { |hash, key| hash[key] = recursive }
  end
end

observations = Hash.recursive
odds = Hash.recursive

line_num = 0
percent_complete = 0

# http://aa.usno.navy.mil/faq/docs/daylight_time.php
dst = {
    2006 => Date.new(2006,4,2)..Date.new(2006,10,28),
    2007 => Date.new(2007,3,11)..Date.new(2007,11,3),
    2008 => Date.new(2008,3,9)..Date.new(2008,11,1),
    2009 => Date.new(2009,3,8)..Date.new(2009,10,31),
    2010 => Date.new(2010,3,14)..Date.new(2010,11,6),
    2011 => Date.new(2011,3,13)..Date.new(2011,11,5),
    2012 => Date.new(2012,3,11)..Date.new(2012,11,3),
    2013 => Date.new(2013,3,10)..Date.new(2013,11,2),
    2014 => Date.new(2014,3,9)..Date.new(2014,11,1),
    2015 => Date.new(2015,3,8)..Date.new(2015,10,31),
    2016 => Date.new(2016,3,13)..Date.new(2016,11,5),
    2017 => Date.new(2017,3,12)..Date.new(2017,11,4),
    2018 => Date.new(2018,3,11)..Date.new(2018,11,3),
    2019 => Date.new(2019,3,10)..Date.new(2019,11,2),
    2020 => Date.new(2020,3,8)..Date.new(2020,10,31)
}

File.open('washingtondc.csv').each do |line|
    tfl_id, bikes, spaces, ts = line.split(",")

    dt = DateTime.parse(ts)
    dt = dst[dt.year].cover?(dt) ? dt.new_offset(-4.0/24) : dt.new_offset(-5.0/24)
    dt = Time.at((dt.to_time.to_i / 300.0).floor * 300).to_datetime

    day = ['all', dt.wday == 6 || dt.wday == 0 ? 'weekend' : 'weekday']

    season = ['all']
    if dt.month == 1 || dt.month == 2 || dt.month == 12 then season.push('winter') else season.push('not-winter') end
    if dt.month == 6 || dt.month == 7 || dt.month == 8 then season.push('summer') end

    hashes = day.product(season).map { |a| 'day=' + a[0] + '&season=' + a[1] }

    hashes.each do |hash|
        unless observations[hash][tfl_id].has_key?(dt.strftime("%H:%M"))
            observations[hash][tfl_id][dt.strftime("%H:%M")] = {"obs" => 0, "av_count" => 0, "spaces_count" => 0}
        end

        observations[hash][tfl_id][dt.strftime("%H:%M")]["obs"] += 1
        observations[hash][tfl_id][dt.strftime("%H:%M")]["av_count"] += bikes.to_i > 0 ? 1 : 0
        observations[hash][tfl_id][dt.strftime("%H:%M")]["spaces_count"] += spaces.to_i > 0 ? 1 : 0
    end

    line_num +=1
    new_percent_complete = ((line_num * 100) / 130491748).floor
    if new_percent_complete > percent_complete then
        puts "#{percent_complete}% complete."
        percent_complete = new_percent_complete
    end
end

puts "Finished scanning file."

observations.each do |hash, tfl_ids|
    tfl_ids.each do |tfl_id, times|
        times.each do |time, counts|
            odds['bikes?' + hash][tfl_id][time] = (1.0 * counts["av_count"] / counts["obs"]).round(2)
            odds['spaces?' + hash][tfl_id][time] = (1.0 * counts["spaces_count"] / counts["obs"]).round(2)
        end
    end
end

odds.each do |hash, data|
    File.open(hash + ".json","w") { |f| f.write(data.to_json) }
end
