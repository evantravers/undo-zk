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

SRC = "#{Dir.home}/Dropbox/wiki"
DST = './wiki'
FORBIDDEN = /[<>:"\/\\|?*]/

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
      if tags.any? { |t| t.match /#career\// }
        return tags
                .find { |t| t.match /#career\// }
                .gsub('#', '')
                .split('/')
      end
    end

    nil
  end

  def filename
    if tags and tags.include?("#links")
      url = URI.parse(URI.extract(@content).last).host
      return "#{title.gsub(url, "")} - #{url}" if url
    end

    if tags and tags.include?("#booknote")
      author = @meta['author'].split(',').first if @meta['author']
      return "#{title} by #{author}" if author
    end

    return date.strftime("%Y-%m-%d") if tags and tags.include?("#journal")

    title
  end

  def date
    return Date.parse(@meta['date']) if @meta['date']
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
    return @meta['title'].to_s.gsub(FORBIDDEN, "") if @meta['title']

    File.basename(@original_filename)
  end
end

def err(str)
  puts str
  binding.pry
end

def fix_links(content, filenames)
  filenames.reduce(content) do |new_content, mapping|
    old, zettel = mapping

    new_content.gsub(old, zettel.path)
  end
end

# delete the distribution folder
`rm -rf #{DST}`
`mkdir #{DST}`

# ---

# filenames becomes a mapping of [old => new] names
filenames = {}
Dir.glob("#{SRC}/*.md").each do |file|
  zettel = Zettel.new(file)
  err("🛑 duplicate name: #{file}") if filenames.values.include?(zettel.title)

  filenames[File.basename(file, ".*")] = zettel
end

# make files based on the new filenames, but fixing the links in the content
filenames.values.each do |zettel|
  # create any folders
  `mkdir -p #{File.join(DST, zettel.folders)}` if zettel.folders

  File.write(
    "#{File.join([DST, zettel.path])}.md",
    fix_links(zettel.content, filenames),
    mode: 'a'
  )
end
