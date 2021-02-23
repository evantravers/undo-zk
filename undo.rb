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

SRC = "#{Dir.home}/Dropbox/wiki"
DST = './wiki'
FORBIDDEN = /[<>:"\/\\|?*]/

class Zettel
  attr_reader :content

  def initialize(file)
    @content = File.read(file)
  end

  def tags
    match = /^tags: ?\[(.*)\]$/.match(@content)
    if match
      match
      .captures
      .first
      .split(/, ?/)
      .map { |t| t.gsub('"', '') }
    else
      return nil
    end
  end

  # these rules apply "last wins"
  def folders
    if tags
      case
      when tags.include?('#booknote')
        ['booknotes']
      when tags.include?('#links')
        ['links']
      when tags.any? { |t| t.match /#career\// }
        tags
          .find { |t| t.match /#career\// }
          .gsub('#', '')
          .split('/')
      when tags.include?('#journal')
        ['journal']
      else
        ""
      end
    else
      ""
    end
  end

  def filename
    title
  end

  def title
    title = /^title: "?(.*)"?$/.match(@content)

    title.captures.first.gsub(FORBIDDEN, "")
  end
end

def err(str)
  puts str
  binding.pry
end

def fix_links(content, filenames)
  filenames.reduce(content) do |new_content, mapping|
    old, zettel = mapping

    new_content.gsub(old, File.join(zettel.folders, zettel.filename))
  end
end

# delete the distribution folder
`rm -rf #{DST}`

# ---

# filenames becomes a mapping of [old => new] names
filenames = {}
Dir.glob("#{SRC}/*.md").each do |file|
  zettel = Zettel.new(file)
  err("🛑 duplicate name: #{file}") if filenames.values.include?(zettel.title)

  filenames[File.basename(file, ".*")] = zettel
end

# make files based on the new filenames, but fixing the links in the content
Dir.glob("#{SRC}/*.md").each do |file|
  zettel = Zettel.new(file)

  # create any folders
  `mkdir -p #{File.join(DST, zettel.folders)}`

  File.write(
    File.join([DST, zettel.folders, "#{zettel.filename}.md"]),
    fix_links(zettel.content, filenames)
  )
end
