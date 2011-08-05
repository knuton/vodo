# Copyright (c) 2004-2011 David Heinemeier Hansson
#
# Permission is hereby granted, free of charge, to any person obtaining
# a copy of this software and associated documentation files (the
# "Software"), to deal in the Software without restriction, including
# without limitation the rights to use, copy, modify, merge, publish,
# distribute, sublicense, and/or sell copies of the Software, and to
# permit persons to whom the Software is furnished to do so, subject to
# the following conditions:
#
# The above copyright notice and this permission notice shall be
# included in all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
# EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
# MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
# NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
# LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
# OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
# WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.


# Annotation objects are triplets <tt>:line</tt>, <tt>:tag</tt>, <tt>:text</tt> that
# represent the line where the annotation lives, its tag, and its text. Note
# the filename is not stored.
#
# Annotations are looked for in comments and modulus whitespace they have to
# start with the tag optionally followed by a colon. Everything up to the end
# of the line (or closing ERB comment tag) is considered to be their text.
class SourceAnnotationExtractor
  class Annotation < Struct.new(:line, :tag, :text)

    # Returns a representation of the annotation that looks like this:
    #
    #   [126] [TODO] This algorithm is simple and clearly correct, make it faster.
    #
    # If +options+ has a flag <tt>:tag</tt> the tag is shown as in the example above.
    # Otherwise the string contains just line and text.
    def to_s(options={})
      s = "[%3d] " % line
      s << "[#{tag}] " if options[:tag]
      s << text
    end
  end

  class CommentPattern

    @patterns = {}

    def self.add(filetype_or_hash, comment_start = nil)
      if filetype_or_hash.is_a? Hash
        filetype_or_hash.each do |type, comment_start|
          add(type, comment_start)
        end
        return
      else
        filetype = filetype_or_hash
      end

      if @patterns.include? comment_start
        instance = @patterns[comment_start]
        instance.filetypes << filetype
        instance
      else
        pattern = comment_start + '\s*({TAG}):?\s*(.*)$'
        @patterns[comment_start] = self.new(filetype, pattern)
      end
    end

    def self.all
      @patterns.values
    end

    def initialize(filetype, pattern)
      self.filetypes = [filetype]
      self.pattern = pattern
    end

    attr_accessor :filetypes, :pattern

    def types_regexp
      Regexp.new '\.(' << filetypes.join('|') << ')$'
    end

    def comment_regexp(tag)
      Regexp.new pattern.sub('{TAG}', tag)
    end

    def serves?(filename)
      types_regexp =~ filename
    end

  end

  # Prints all annotations with tag +tag+ under the root directories +app+, +config+, +lib+,
  # +script+, and +test+ (recursively). Only filenames with extension 
  # +.builder+, +.rb+, +.rxml+, +.rhtml+, or +.erb+ are taken into account. The +options+
  # hash is passed to each annotation's +to_s+.
  #
  # This class method is the single entry point for the rake tasks.
  def self.enumerate(tag, options={})
    if options[:filetypes]
      CommentPattern.add(options[:filetypes])
    end
    extractor = new(tag)
    extractor.display(extractor.find, options)
  end

  attr_reader :tag

  def initialize(tag)
    @tag = tag
  end

  # Returns a hash that maps filenames under +dirs+ (recursively) to arrays
  # with their annotations. Only files with annotations are included, and only
  # those with extension +.builder+, +.rb+, +.rxml+, +.rhtml+, and +.erb+
  # are taken into account.
  def find(dirs=%w(app config lib script test))
    dirs.inject({}) { |h, dir| h.update(find_in(dir)) }
  end

  # Returns a hash that maps filenames under +dir+ (recursively) to arrays
  # with their annotations. Only files with annotations are included, and only
  # those with extension +.builder+, +.rb+, +.rxml+, +.rhtml+, and +.erb+
  # are taken into account.
  def find_in(dir)
    results = {}

    Dir.glob("#{dir}/*") do |item|
      next if File.basename(item)[0] == ?.

      if File.directory?(item)
        results.update(find_in(item))
      else
        CommentPattern.all.each do |comment_pattern|
          if comment_pattern.serves?(item)
            results.update(
              extract_annotations_from(item, comment_pattern.comment_regexp(tag))
            )
          end
        end
      end
    end

    results
  end

  # If +file+ is the filename of a file that contains annotations this method returns
  # a hash with a single entry that maps +file+ to an array of its annotations.
  # Otherwise it returns an empty hash.
  def extract_annotations_from(file, pattern)
    lineno = 0
    result = File.readlines(file).inject([]) do |list, line|
      lineno += 1
      next list unless line =~ pattern
      list << Annotation.new(lineno, $1, $2)
    end
    result.empty? ? {} : { file => result }
  end

  # Prints the mapping from filenames to annotations in +results+ ordered by filename.
  # The +options+ hash is passed to each annotation's +to_s+.
  def display(results, options={})
    results.keys.sort.each do |file|
      puts "#{file}:"
      results[file].each do |note|
        puts "  * #{note.to_s(options)}"
      end
      puts
    end
  end
end
