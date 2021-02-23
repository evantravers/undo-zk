# Flipping my ZK back to Obsidian's Format

require 'pry'

SRC = "#{Dir.home}/Dropbox/wiki"
DST = './wiki'
FORBIDDEN = ['<', '>', ':', '"', '/', '\\', '|', '?', '*']

# delete the distribution folder
Dir.rmdir(DST) if Dir.exist?(DST)

# make the folder
Dir.mkdir(DST)

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
      else
        return nil
      end
  end

  def title
    /^title: "?(.*)"?/.match(@content).captures.first
  end
end

#     - Error any duplicate final filenames
# - Change Links
#     - For each starting, filename, search through the ZK to find matching
#       links, replacing with the final filename.
#     - Leave block references and header references alone.
# - Execute
#     - Have a dry-run option
#     - Logging
filenames = {}

def err(str)
  puts str
  binding.pry
end

# - make a map of filename transitions
#     - Use the `title:` attribute for the filename
#     - Rules
#         - `tag:#journal` -> Daily note in `/journal`
#         - `tag:#career` -> Folders `/careers/eab/` etc.
#         - `tag:#booknotes` -> Folder: `/booknotes`
Dir.glob("#{SRC}/*.md").each do |file|
  zettel = Zettel.new(file)
  err("🛑 duplicate name: #{file}") if filenames.values.include?(zettel.title)


  filenames[file] = zettel.title
end

