puts "Cleaning database..."

ActiveRecord::Base.connection.execute(
  "TRUNCATE TABLE lists, receipes, ingredients RESTART IDENTITY"
)

puts "Database cleaned !"

url = 'https://pennylane-interviewing-assets-20220328.s3.eu-west-1.amazonaws.com/recipes-en.json.gz'

URI.open(url, 'rb') do |source|
  File.open('receipes.gz', 'wb') do |destination|
    IO.copy_stream(source, destination)
  end
end

puts 'receipes.gz file downloaded'

Zlib::GzipReader.open('receipes.gz') do |gz|
  File.open('receipes.json', 'wb') do |receipe|
    IO.copy_stream(gz, receipe)
  end
end

puts 'file unzipped'

file = File.open('receipes.json')
data = JSON.load file

puts 'JSON loaded'

Importer::ImporterService.new(data).import