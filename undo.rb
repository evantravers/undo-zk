# Flipping my ZK back to Obsidian's Format
# - make a map of filename transitions
#     - Use the `title:` attribute for the filename
#     - Rules
#         - `tag:#journal` -> Daily note in `/journal`
#         - `tag:#career` -> Folders `/careers/eab/` etc.
#         - `tag:#booknotes` -> Folder: `/booknotes
#     - Error any duplicate final filenames
# - Change Links
#     - For each starting, filename, search through the ZK to find matching
#       links, replacing with the final filename.
#     - Leave block references and header references alone.
# - Execute
#     - Have a dry-run option
#     - Logging

require 'pry'
require 'yaml'
require 'uri'
require 'date'

SRC = "#{Dir.home}/Dropbox/wiki".freeze
DST = './wiki'.freeze
FORBIDDEN = %r{[<>:"/\|?*]}.freeze

# This represents a Zettel
class Zettel
  attr_reader :content, :meta, :original_filename

  def initialize(file)
    @original_filename = file
    @content           = File.read(file)
    @meta              = YAML.load(@content)
  end

  def tags
    @meta['tags']
  end

  # these rules apply "first wins"
  def folders
    if tags
      return ['booknotes'] if tags.include?('#booknote')
      return ['links'] if tags.include?('#links')
      return ['journal'] if tags.include?('#journal')

      if tags.any? { |t| t.match %r{#career/} }
        return tags
               .find { |t| t.match %r{#career/} }
               .gsub('#', '')
               .split('/')
      end
    end

    nil
  end

  def filename
    if tags&.include?('#links')
      url = URI.parse(URI.extract(@content).last).host
      return "#{title.gsub(url, '')} - #{url}" if url
    end

    if tags&.include?('#booknote')
      author = @meta['author'].split(',').first if @meta['author']
      return "#{title} by #{author}" if author
    end

    return date.strftime('%Y-%m-%d') if tags&.include?('#journal')

    title
  end

  def extract_date_from_title(title)
    return Date.parse(title) if title.match(/(?<year>\d{4})-(?<month>\d{2})-(?<day>\d{2})/)

    if title.match(/(?<month>\d{2})-(?<day>\d{2})-(?<year>\d{4})/)
      d = title.match(/(?<month>\d{2})-(?<day>\d{2})-(?<year>\d{4})/)
      Date.parse("#{d['year']}-#{d['month']}-#{d['day']}")
    end
  end

  # FIXME: There's a date (Thu, 18 Jun 2020) that is often applied incorrectly.
  def date
    return Date.parse(@meta['date']) if @meta['date'] && !@meta['date'].match(/Thu, 18 Jun 2020/)
    return extract_date_from_title(@meta['title']) if @meta['title'].match(/\d+-\d+-\d+/)
    return Date.parse(@meta['id'].to_s) if @meta['id']

    err("Can't find a date!")
  end

  def path
    if folders
      File.join(folders, filename)
    else
      filename
    end
  end

  def title
    return @meta['title'].to_s.gsub(FORBIDDEN, '') if @meta['title']

    File.basename(@original_filename)
  end
end

def err(str, context = nil)
  puts str
  binding.pry
end

def fix_links(content, zettels)
  zettels.reduce(content) do |new_content, mapping|
    old, zettel = mapping

    new_content.gsub(old, zettel.path)
  end
end

# delete the distribution folder
`rm -rf #{DST}`
`mkdir #{DST}`

# ---

# zettels becomes a mapping of [old => new] names
zettels = {}
Dir.glob("#{SRC}/*.md").each do |file|
  zettel = Zettel.new(file)
  # err("🛑 duplicate name: #{file}", [zettels, zettel]) if zettels.values.any? { |z| z.path == zettel.path }

  zettels[File.basename(file, '.*')] = zettel
end

# make files based on the new zettels, but fixing the links in the content
zettels.each_value do |zettel|
  # create any folders
  `mkdir -p #{File.join(DST, zettel.folders)}` if zettel.folders

  File.write(
    "#{File.join([DST, zettel.path])}.md",
    fix_links(zettel.content, zettels),
    mode: 'a'
  )
end
