# Decides whether a nickname contains blocked or reserved words.
# Word lists live in config/nickname_filter/.
module NicknameFilter
  LEET = { "0" => "o", "1" => "i", "3" => "e", "4" => "a", "5" => "s", "7" => "t", "8" => "b", "9" => "g", "$" => "s", "@" => "a" }.freeze
  # Short blocked words only match a whole word, so "Cassidy" isn't caught by a three-letter word.
  SUBSTRING_MIN_LENGTH = 4

  class << self
    def blocked?(nickname)
      raw = nickname.to_s.downcase
      tokens = raw.split(/[_\d]+/).reject(&:empty?)
      squashed = without_allowed_words(deleet(raw).delete("_"))

      reserved?(tokens, squashed) || profane?(tokens, squashed)
    end

    def reload!
      @lists = nil
    end

    private
      def reserved?(tokens, squashed)
        whole = [ squashed.strip, tokens.join ]
        lists[:reserved_anywhere].any? { |word| squashed.include?(word) } ||
          (whole & lists[:reserved_words]).any?
      end

      def profane?(tokens, squashed)
        short, long = lists[:blocked].partition { |word| word.length < SUBSTRING_MIN_LENGTH }
        long.any? { |word| squashed.include?(word) } || (tokens.map { |t| deleet(t) } & short).any?
      end

      def deleet(text)
        text.gsub(/[0-9$@]/) { |char| LEET.fetch(char, char) }
      end

      def without_allowed_words(text)
        lists[:allowed].reduce(text) { |result, word| result.gsub(word, " ") }
      end

      def lists
        @lists ||= begin
          reserved = read("reserved.txt")
          {
            blocked: read("blocked_words.txt"),
            allowed: read("allowed_words.txt"),
            reserved_anywhere: reserved.select { |w| w.start_with?("*") }.map { |w| w.delete_prefix("*") },
            reserved_words: reserved.reject { |w| w.start_with?("*") }
          }
        end
      end

      def read(file)
        Rails.root.join("config/nickname_filter", file).readlines(chomp: true)
          .map(&:strip).reject { |line| line.empty? || line.start_with?("#") }.map(&:downcase)
      end
  end
end
