defmodule Hackernews do
  def get_stories do
    HTTPoison.get!("https://hacker-news.firebaseio.com/v0/topstories.json", [], hackney: [:insecure])
  end
end
