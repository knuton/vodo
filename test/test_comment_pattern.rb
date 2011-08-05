require 'test/unit'

require 'lib/vodo/source_annotation_extractor'

class TestCommentPattern < Test::Unit::TestCase

  def test_creation
    comment_pattern = SourceAnnotationExtractor::CommentPattern.new 'footype', 'foopattern'
    assert_equal comment_pattern.filetypes, ["footype"]
    assert_equal comment_pattern.pattern, "foopattern"
  end

  def test_augmentation
    comment_pattern_a = SourceAnnotationExtractor::CommentPattern.add 'type_a', 'pattern'
    assert_equal comment_pattern_a.filetypes.size, 1
    comment_pattern_b = SourceAnnotationExtractor::CommentPattern.add 'type_b', 'pattern'
    assert_equal comment_pattern_a, comment_pattern_b
    assert_equal comment_pattern_a.filetypes.size, 2
  end

  def test_distinction
    comment_pattern_a = SourceAnnotationExtractor::CommentPattern.add 'type_a', 'pattern_a'
    assert_equal comment_pattern_a.filetypes.size, 1
    comment_pattern_b = SourceAnnotationExtractor::CommentPattern.add 'type_b', 'pattern_b'
    assert_not_equal comment_pattern_a, comment_pattern_b
    assert_equal comment_pattern_a.filetypes.size, 1
  end

  def test_pattern_regexp_creation
    comment_pattern = SourceAnnotationExtractor::CommentPattern.add 'footype', '#'
    assert_equal comment_pattern.comment_regexp('TODO'), /#\s*(TODO):?\s*(.*)$/
  end

  def test_type_regexp_creation
    comment_pattern = SourceAnnotationExtractor::CommentPattern.add 'footype_a', 'foo'
    comment_pattern = SourceAnnotationExtractor::CommentPattern.add 'footype_b', 'foo'
    assert_equal comment_pattern.types_regexp, /\.(footype_a|footype_b)$/
  end

  def test_filetype_recognition
    rb_pattern = SourceAnnotationExtractor::CommentPattern.add 'rb', '#'
    coffee_pattern = SourceAnnotationExtractor::CommentPattern.add 'coffee', '#'
    assert coffee_pattern.serves? '.coffee'
  end

end
