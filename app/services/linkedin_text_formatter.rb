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

  # The Unicode bold block only defines plain A-Z/a-z/0-9 — there's no bold "é" or bold "%".
  # For accented letters, decompose into base letter + accent (NFD), bold the base, and
  # reattach the accent: é → e + ´ → bolded-e + ´, which still renders as a bold é.
  # Punctuation with no bold equivalent (%, /, +, …) is left untouched — there's nothing to map it to.
  def self.bold_char(char)
    base, *marks = char.unicode_normalize(:nfd).chars
    _range, offset = BOLD_OFFSETS.find { |range, _| range.cover?(base) }
    return char unless offset

    ([base.ord + offset].pack("U") + marks.join)
  end
  private_class_method :bold_char
end
