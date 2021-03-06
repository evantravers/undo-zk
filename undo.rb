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

require './bible_books'

SRC = "#{Dir.home}/Dropbox/wiki".freeze
DST = './wiki'.freeze
FORBIDDEN = %r{[<>:"/\|?*]}.freeze
# the following books were generated from a list on a bible site, I forget which

# This represents a Zettel
class Zettel
  attr_reader :content, :meta, :original_filename

  def initialize(file)
    @original_filename = file
    file_content = File.read(file)

    @meta = load_yaml(file_content)
    filter_meta

    @content = remove_frontmatter(file_content)
  end

  def load_yaml(content)
    return YAML.load(content) if content.match(/---/)

    {}
  end

  def tags
    @meta['tags']
  end

  def filter_meta
    @meta['aliases'] = @meta['aliases'].reject { |a| a == @meta['title'] } if @meta['aliases']
    @meta.delete_if { |_k, v| v.is_a?(Array) && v.empty? }
  end

  def remove_frontmatter(str)
    str.gsub(/---.+?---\n{0,2}/m, '')
  end

  def render
    "#{@meta.to_yaml}---\n\n#{@content}"
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

    # guard clause
    return unless title.match(/(?<month>\d{2})-(?<day>\d{2})-(?<year>\d{4})/)

    d = title.match(/(?<month>\d{2})-(?<day>\d{2})-(?<year>\d{4})/)
    Date.parse("#{d['year']}-#{d['month']}-#{d['day']}")
  end

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

  # zettels should be a map of {:old_filename => NewZettel}
  def fix_links(zettels)
    @content =
      zettels.reduce(@content) do |new_content, mapping|
        old, zettel = mapping

        new_content.gsub(old, zettel.path)
      end

    self
  end

  def fix_bible_references
    BOOKS.each do |book_match|
      book, regex = book_match
      @content.gsub!(/\b(?<book>#{regex}) (?<chapter>\d{1,3})(?::(?<verse>\d+))?(?:- ?(?<end>\d+))?\b/) do |_v|
        match = Regexp.last_match
        if match[:end]
          "[[ESV/#{book_folder(book)}/#{book}-#{match[:chapter]}##{match[:verse]}|#{match}]]"
        elsif match[:verse]
          "[[ESV/#{book_folder(book)}/#{book}-#{match[:chapter]}##{match[:verse]}|#{match}]]"
        else
          "[[ESV/#{book_folder(book)}/#{book}-#{match[:chapter]}|#{match}]]"
        end
      end
    end

    self
  end
end

def err(str, context = nil)
  puts str
  binding.pry
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
    zettel
      .fix_links(zettels)
      .fix_bible_references
      .render,
    mode: 'a'
  )
end

require './fix_bible'
