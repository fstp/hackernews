defmodule Hackernews do
  def get_body!(url) do
    %HTTPoison.Response{status_code: 200, body: body} = HTTPoison.get!(url, [], hackney: [:insecure])
    body
  end

  def download_story(id) do
    "https://hacker-news.firebaseio.com/v0/item/" <> to_string(id) <> ".json"
    |> get_body!
    |> Poison.Parser.parse!
    |> format_story
  end

  def format_story(%{"title" => title, "url" => url}) do
    [title, "\t", url, "\n"]
  end
  def format_story(_), do: [] # Ignore stories with no URL

  def download_stories(stories) do
    Enum.map(stories, &download_story/1)
    |> Enum.reject(&Enum.empty?/1)
  end

  def pmap(collection, func, timeout_ms \\ 10_000) do
    collection
    |> Enum.map(&(Task.async(fn -> func.(&1) end)))
    |> Enum.map(fn t -> Task.await(t, timeout_ms) end)
  end

  def get_stories do
    data = "https://hacker-news.firebaseio.com/v0/topstories.json"
    |> get_body!
    |> Poison.Parser.parse!
    |> Enum.sort # To avoid cache becoming invalid due to reordering of stories!
    |> Enum.chunk(25, 20, []) # TODO(john) should be configurable
    |> pmap(&download_stories/1)
    
    File.write!("topstories.txt", data)
  end

  def hash(data) do
      <<x ::unsigned-big-integer-256>> = :crypto.hash(:sha256, data)
      x
  end

  def topstories do
    body = "https://hacker-news.firebaseio.com/v0/topstories.json"
    |> get_body!
    |> Poison.Parser.parse!
    |> Enum.sort # To avoid cache becoming invalid due to reordering of stories!
    |> Enum.map(&:erlang.integer_to_binary/1)

    sha256 = body
    |> hash
    |> Integer.to_string(16)
    |> String.downcase

    {sha256, body}
  end

  def need_update? do
    {sha256, body} = topstories
    store = fn ->
      File.write!("topstories.sha256", sha256)
      File.write!("topstories.json", body)
      :true
    end
    case File.read("topstories.sha256") do
      {:error, :enoent} -> store.()
      {:ok, local} ->
        case String.equivalent?(sha256, local) do
          :true -> :false
          :false -> store.()
        end
    end
  end

  def main do
    HTTPoison.start
    case need_update? do
      :true -> get_stories
      :false -> :ok
    end
  end
end
