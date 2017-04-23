defmodule HackernewsTest do
  use ExUnit.Case
  doctest Hackernews

  test "Topstories exist" do
    Hackernews.download_topstories()
  end

  test "Story with url is printed" do
    delimeter = "deadbeef"
    story = %{"title" => "Foo", "url" => "Bar"}
    assert Hackernews.format_story(story, delimeter) == ["Foo", "\n", "Bar", delimeter]
  end

  test "Story without url is discarded" do
    delimeter = "deadbeef"
    story = %{"title" => "Foo"}
    assert Hackernews.format_story(story, delimeter) == []
  end

  # Make sure we write files to local directory
  test "Test configuration is valid" do  
    assert Hackernews.home_path() == Path.expand(".")
    assert Hackernews.sha256_path() == Path.join([Path.expand("."), "topstories.sha256"])
    assert Hackernews.txt_path() == Path.join([Path.expand("."), "topstories.txt"])
  end

  test "Cached data is replaced if SHA1 is different" do
    sha256 = "123456789"
    text = """
    deadbeef
    www.google.se

    badbeed
    www.facebook.com
    """
    File.write!(Hackernews.sha256_path(), sha256)
    File.write!(Hackernews.txt_path(), text)
    Hackernews.main
    new_sha256 = File.read!(Hackernews.sha256_path())
    new_text = File.read!(Hackernews.txt_path())
    assert new_sha256 != sha256
    assert new_text != text
  end
end
