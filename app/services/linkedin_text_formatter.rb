# Converts markdown-style **bold** into Unicode bold characters, since LinkedIn
# (and most social platforms) don't render real markdown — the only way to get
# bold text in a post is to use lookalike bold Unicode code points instead of ASCII.
class LinkedinTextFormatter
  BOLD_OFFSETS = {
    ("A".."Z") => 0x1D5D4 - "A".ord,
    ("a".."z") => 0x1D5EE - "a".ord,
    ("0".."9") => 0x1D7EC - "0".ord
  }.freeze

  def self.call(text)
    text.to_s.gsub(/\*\*(.+?)\*\*/) { bold(::Regexp.last_match(1)) }
  end

  def self.bold(segment)
    segment.each_char.map { |char| bold_char(char) }.join
  end

  def self.bold_char(char)
    _range, offset = BOLD_OFFSETS.find { |range, _| range.cover?(char) }
    offset ? [char.ord + offset].pack("U") : char
  end
  private_class_method :bold_char
end
