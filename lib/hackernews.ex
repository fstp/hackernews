defmodule Hackernews do
  def get_body!(url) do
    %HTTPoison.Response{status_code: 200, body: body} = HTTPoison.get!(url, [], hackney: [:insecure])
    body
  end

  def download_story(id) do
    url = "https://hacker-news.firebaseio.com/v0/item/" <> to_string(id) <> ".json"
    json = get_body!(url)
    %{"title" => title} = Poison.Parser.parse!(json)
    title
  end

  def download_stories(stories) do
    Enum.map(stories, &download_story/1)
  end

  def pmap(collection, func) do
    collection
    |> Enum.map(&(Task.async(fn -> func.(&1) end)))
    |> Enum.map(&Task.await/1)
  end

  def get_stories do
    url = "https://hacker-news.firebaseio.com/v0/topstories.json"
    json = get_body!(url)
    stories = Poison.Parser.parse!(json)
    chunks = Enum.chunk(stories, 10, 10, [])
    pmap(chunks, &download_stories/1)
  end
end
