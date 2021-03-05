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
# the following books were generated from a list on a bible site, I forget which
BOOKS = {
  'Genesis'         => /Genesis|Gen\.?|Ge\.?|Gn\.?/,
  'Exodus'          => /Exodus|Ex\.?|Exod\.?|Exo\.?/,
  'Leviticus'       => /Leviticus|Lev\.?|Le\.?|Lv\.?/,
  'Numbers'         => /Numbers|Num\.?|Nu\.?|Nm\.?|Nb\.?/,
  'Deuteronomy'     => /Deuteronomy|Deut\.?|De\.?|Dt\.?/,
  'Joshua'          => /Joshua|Josh\.?|Jos\.?|Jsh\.?/,
  'Judges'          => /Judges|Judg\.?|Jdg\.?|Jg\.?|Jdgs\.?/,
  'Ruth'            => /Ruth|Ruth|Rth\.?|Ru\.?/,
  '1 Samuel'        => /1 Samuel|1 Sam\.?|1 Sm\.?|1 Sa\.?|1 S\.?|I Sam\.?|I Sa\.?|1Sam\.?|1Sa\.?|1S\.?|1st Samuel|1st Sam\.?|First Samuel|First Sam\.?/,
  '2 Samuel'        => /2 Samuel|2 Sam\.?|2 Sm\.?|2 Sa\.?|2 S\.?|II Sam\.?|II Sa\.?|2Sam\.?|2Sa\.?|2S\.?|2nd Samuel|2nd Sam\.?|Second Samuel|Second Sam\.?/,
  '1 Kings'         => /1 Kings|1 Kings|1 Kgs|1 Ki|1Kgs|1Kin|1Ki|1K|I Kgs|I Ki|1st Kings|1st Kgs|First Kings|First Kgs/,
  '2 Kings'         => /2 Kings|2 Kings|2 Kgs\.?|2 Ki\.?|2Kgs\.?|2Kin\.?|2Ki\.?|2K\.?|II Kgs\.?|II Ki\.?|2nd Kings|2nd Kgs\.?|Second Kings|Second Kgs\.?/,
  '1 Chronicles'    => /1 Chronicles|1 Chron\.?|1 Chr\.?|1 Ch\.?|1Chron\.?|1Chr\.?|1Ch\.?|I Chron\.?|I Chr\.?|I Ch\.?|1st Chronicles|1st Chron\.?|First Chronicles|First Chron\.?/,
  '2 Chronicles'    => /2 Chronicles|2 Chron\.?|2 Chr\.?|2 Ch\.?|2Chron\.?|2Chr\.?|2Ch\.?|II Chron\.?|II Chr\.?|II Ch\.?|2nd Chronicles|2nd Chron\.?|Second Chronicles|Second Chron\.?/,
  'Ezra'            => /Ezra|Ezra|Ezr\.?|Ez\.?/,
  'Nehemiah'        => /Nehemiah|Neh\.?|Ne\.?/,
  'Esther'          => /Esther|Est\.?|Esth\.?|Es\.?/,
  'Job'             => /Job|Job|Jb\.?/,
  'Psalms'          => /Psalms|Ps\.?|Psalm|Pslm\.?|Psa\.?|Psm\.?|Pss\.?/,
  'Proverbs'        => /Proverbs|Prov|Pro\.?|Prv\.?|Pr\.?/,
  'Ecclesiastes'    => /Ecclesiastes|Eccles\.?|Eccle\.?|Ecc\.?|Ec\.?|Qoh\.?/,
  'Song of Solomon' => /Song of Solomon|Song|Song of Songs|SOS\.?|So\.?|Canticle of Canticles|Canticles|Cant\.?/,
  'Isaiah'          => /Isaiah|Isa\.?|Is\.?/,
  'Jeremiah'        => /Jeremiah|Jer\.?|Je\.?|Jr\.?/,
  'Lamentations'    => /Lamentations|Lam\.?|La\.?/,
  'Ezekiel'         => /Ezekiel|Ezek\.?|Eze\.?|Ezk\.?/,
  'Daniel'          => /Daniel|Dan\.?|Da\.?|Dn\.?/,
  'Hosea'           => /Hosea|Hos\.?|Ho\.?/,
  'Joel'            => /Joel|Joel|Jl\.?/,
  'Amos'            => /Amos|Amos|Am\.?/,
  'Obadiah'         => /Obadiah|Obad\.?|Ob\.?/,
  'Jonah'           => /Jonah|Jonah|Jnh\.?|Jon\.?/,
  'Micah'           => /Micah|Mic\.?|Mc\.?/,
  'Nahum'           => /Nahum|Nah\.?|Na\.?/,
  'Habakkuk'        => /Habakkuk|Hab\.?|Hb\.?/,
  'Zephaniah'       => /Zephaniah|Zeph\.?|Zep\.?|Zp\.?/,
  'Haggai'          => /Haggai|Hag\.?|Hg\.?/,
  'Zechariah'       => /Zechariah|Zech\.?|Zec\.?|Zc\.?/,
  'Malachi'         => /Malachi|Mal\.?|Ml\.?/,
  'Matthew'         => /Matthew|Matt\.?|Mt\.?/,
  # commenting out 'Mar' because it matches March datestamps.
  # 'Mark'=>/Mark|Mark|Mrk|Mar|Mk|Mr/,
  'Mark'            => /Mark|Mark|Mrk|Mk|Mr/,
  'Luke'            => /Luke|Luke|Luk|Lk/,
  'John'            => /John|John|Joh|Jhn|Jn/,
  'Acts'            => /Acts|Acts|Act|Ac/,
  'Romans'          => /Romans|Rom\.?|Ro\.?|Rm\.?/,
  '1 Corinthians'   => /1 Corinthians|1 Cor\.?|1 Co\.?|I Cor\.?|I Co\.?|1Cor\.?|1Co\.?|I Corinthians|1Corinthians|1st Corinthians|2nd Corinthians/,
  '2 Corinthians'   => /2 Corinthians|2 Cor\.?|2 Co\.?|II Cor\.?|II Co\.?|2Cor\.?|2Co\.?|II Corinthians|2Corinthians|2nd Corinthians|Second Corinthians/,
  'Galatians'       => /Galatians|Gal\.?|Ga\.?/,
  'Ephesians'       => /Ephesians|Eph\.?|Ephes\.?/,
  'Philippians'     => /Philippians|Phil\.?|Php\.?|Pp\.?/,
  'Colossians'      => /Colossians|Col\.?|Co\.?/,
  '1 Thessalonians' => /1 Thessalonians|1 Thess\.?|1 Thes\.?|1 Th\.?|I Thessalonians|I Thess\.?|I Thes\.?|I Th\.?|1Thessalonians|1Thess\.?|1Thes\.?|1Th\.?|1st Thessalonians|1st Thess\.?|First Thessalonians|First Thess\.?/,
  '2 Thessalonians' => /2 Thessalonians|2 Thess\.?|2 Thes\.?|II Thessalonians|II Thess\.?|II Thes\.?|II Th\.?|2Thessalonians|2Thess\.?|2Thes\.?|2Th\.?|2nd Thessalonians|2nd Thess\.?|Second Thessalonians|Second Thess\.?/,
  '1 Timothy'       => /1 Timothy|1 Tim\.?|1 Ti\.?|I Timothy|I Tim\.?|I Ti\.?|1Timothy|1Tim\.?|1Ti\.?|1st Timothy|1st Tim\.?|First Timothy|First Tim\.?/,
  '2 Timothy'       => /2 Timothy|2 Tim\.?|2 Ti\.?|II Timothy|II Tim\.?|II Ti\.?|2Timothy|2Tim\.?|2Ti\.?|2nd Timothy|2nd Tim\.?|Second Timothy|Second Tim\.?/,
  'Titus'           => /Titus|Titus|Tit|ti/,
  'Philemon'        => /Philemon|Philem\.?|Phm\.?|Pm\.?/,
  'Hebrews'         => /Hebrews|Heb\.?/,
  'James'           => /James|James|Jas|Jm/,
  '1 Peter'         => /1 Peter|1 Pet\.?|1 Pe\.?|1 Pt\.?|1 P\.?|I Pet\.?|I Pt\.?|I Pe\.?|1Peter|1Pet\.?|1Pe\.?|1Pt\.?|1P\.?|I Peter|1st Peter|First Peter/,
  '2 Peter'         => /2 Peter|2 Pet\.?|2 Pe\.?|2 Pt\.?|2 P\.?|II Peter|II Pet\.?|II Pt\.?|II Pe\.?|2Peter|2Pet\.?|2Pe\.?|2Pt\.?|2P\.?|2nd Peter|Second Peter/,
  '1 John'          => /1 John|1 John|1 Jhn\.?|1 Jn\.?|1 J\.?|1John|1Jhn\.?|1Joh\.?|1Jn\.?|1Jo\.?|1J\.?|I John|I Jhn\.?|I Joh\.?|I Jn\.?|I Jo\.?|1st John|First John/,
  '2 John'          => /2 John|2 John|2 Jhn\.?|2 Jn\.?|2 J\.?|2John|2Jhn\.?|2Joh\.?|2Jn\.?|2Jo\.?|2J\.?|II John|II Jhn\.?|II Joh\.?|II Jn\.?|II Jo\.?|2nd John|Second John/,
  '3 John'          => /3 John|3 John|3 Jhn\.?|3 Jn\.?|3 J\.?|3John|3Jhn\.?|3Joh\.?|3Jn\.?|3Jo\.?|3J\.?|III John|III Jhn\.?|III Joh\.?|III Jn\.?|III Jo\.?|3rd John|Third John/,
  'Jude'            => /Jude|Jude|Jud\.?|Jd\.?/,
  'Revelation'      => /Revelation|Most common:Rev|Re|The Revelation/
}.freeze

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
      abbr, regex = book_match
      @content.gsub!(/(?<book>#{regex}) (?<chapter>\d{1,3})(?::?(?<verse>\d+))?(?:- ?\d+)?/) do |v|
        match = Regexp.last_match
        if match[:verse]
          "[[ESV/#{match[:book]}/#{abbr}-#{match[:chapter]}##{match[:verse]}]]"
        else
          "[[ESV/#{match[:book]}/#{abbr}-#{match[:chapter]}]]"
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
      .content,
    mode: 'a'
  )
end
