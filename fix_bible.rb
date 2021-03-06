require './bible_books'

BIBLE_SRC = './ESV'.freeze
BIBLE_DST = './wiki/ESV'.freeze

`rm -rf #{BIBLE_DST}`

def chapter_number(str)
  str.scan(/-(\d+)/).flatten.first
end

Dir.glob("#{BIBLE_SRC}/*/*.md").each do |chapter|
  book       = File.dirname(chapter).gsub("#{BIBLE_SRC}/", '')
  folder     = book_folder(book)
  filename   = File.basename(chapter)
  content    = File.read(chapter)
  number     = chapter_number(chapter)

  # fix the verses
  content.gsub!(/(###### \d+) /) { |v| "\n\n#{v}\n\n" }

  # chapter
  if filename.match(/-\d+/)
    # add links back to the book
    content = "# [[ESV/#{folder}/#{book}|#{book} #{number}]]\n#{content}"
  # book title
  else
    # find all the chapters
    chapters =
      Dir
      .glob("#{BIBLE_SRC}/#{book}/*.md")
      .filter { |c| c.match(/-\d+/) }
      .sort_by { |c| chapter_number(c).to_i }
      .map { |c| "- [[#{File.basename(c)}|#{chapter_number(c)}]]" }
      .join("\n")
    content = "# #{book}\n\n[[#{book}-1|Start Reading →]]\n\n#{chapters}\n\nlinks: [[The Bible]]"
  end

  `mkdir -p '#{BIBLE_DST}/#{folder}'`

  File.write("#{BIBLE_DST}/#{folder}/#{filename}", content)
end
