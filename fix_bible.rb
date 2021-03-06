SRC = './ESV-original'
DST = '/Users/evan/src/github.com/evantravers/undo-zk/wiki/ESV'

`rm -rf #{DST}`

def chapter_number(str)
  str.scan(/-(\d+)/).flatten.first
end

Dir.glob("#{SRC}/*/*.md").each do |chapter|
  book     = File.dirname(chapter).gsub("#{SRC}/", '')
  filename = File.basename(chapter)
  content  = File.read(chapter)
  number   = chapter_number(chapter)

  # fix the verses
  content.gsub!(/(###### \d+) /) { |v| "\n\n#{v}\n\n" }

  # chapter
  if filename.match(/-\d+/)
    # add links back to the book
    content = "# [[ESV/#{book}/#{book}|#{book} #{number}]]\n#{content}"
  # book title
  else
    # find all the chapters
    chapters =
      Dir
      .glob("#{SRC}/#{book}/*.md")
      .filter { |c| c.match(/-\d+/) }
      .sort_by { |c| chapter_number(c).to_i }
      .map { |c| "- [[#{File.basename(c)}|#{chapter_number(c)}]]" }
      .join("\n")
    content = "# #{book}\n\n[[#{book}-1|Start Reading →]]\n\n#{chapters}\n\nlinks: [[The Bible]]"
  end

  `mkdir -p '#{DST}/#{book}'`
  
  File.write("#{DST}/#{book}/#{filename}", content)
end
