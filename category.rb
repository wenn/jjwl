require 'json'
require 'csv'

def collect_categories_from_events
  categories_data = []

  Dir.glob('./data/events/*/categories/*.json').each do |file_path|
    puts "Processing file: #{file_path}"
    brackets = JSON.parse(File.read(file_path))

    next unless brackets['status'] && brackets['data']

    if brackets['data'].is_a?(Hash)
      brackets['data'].transform_values do |bracket|
        categories_data << flatten_bracket_data(bracket, file_path)
      end
    else
      brackets['data'].each do |bracket|
        categories_data << flatten_bracket_data(bracket, file_path)
      end
    end
  rescue JSON::ParserError => e
    puts "Error parsing #{file_path}: #{e.message}"
  rescue => e
    puts "Error processing #{file_path}: #{e.message}"
  end

  categories_data.compact.flatten
end

def flatten_bracket_data(bracket, source_file)
  return nil unless bracket
  return nil unless bracket['status'] == 'CONCLUDED' || bracket['status'] == 'COMPLETED'
  puts "Processing bracket: #{bracket['category']} from #{source_file}"

  event_name = source_file.split('/')[3]

  flattened = {
    event_name: event_name.split('-').map(&:capitalize).join(' '),
    category: bracket['category'],
  }

  winners = bracket['tree']['winners'] || []
  thirdplace = bracket['tree']['thirdPlace'] || []
  matches = winners + thirdplace

  matches
    .flatten
    .filter { |match| match.is_a?(Hash) && match['status'] == 'COMPLETED' }
    .map do |match|
      flattened.merge(simplify_match(match))
    end

end

def simplify_match(match)
  f1fn = match['fighter1_fullname']
  f2fn = match['fighter2_fullname']

  {
    title: "#{f1fn} vs #{f2fn}",
    match_video_uri: match['match_video_uri'] || 'Not available',
  }
end

def write_to_csv(categories_data, output_file = 'data/categories_flattened.csv')
  return if categories_data.empty?

  headers = [ :title, :event_name, :category, :match_video_uri ]

  CSV.open(output_file, 'w', write_headers: false, headers: headers) do |csv|
    categories_data.each do |row|
      csv << headers.map { |header| row[header] }
    end
  end

  puts "CSV file generated: #{output_file}"
  puts "Total records: #{categories_data.size}"
end

categories = collect_categories_from_events.sort_by { |cat| [cat[:event_name], cat[:category], cat[:title]] }
write_to_csv(categories)
