defmodule Hackernews do
  def main do
    topstories = download_topstories

    sha256 = topstories
    |> Enum.map(&:erlang.integer_to_binary/1)
    |> hash
    |> Integer.to_string(16)
    |> String.downcase

    case need_update?(sha256) do
      :true ->
        # TODO(john) number of and size of chunks should be configurable.
        chunks = Enum.chunk(topstories, 25, 20, [])
        text = pmap(chunks, &download_stories/1)
        File.write!(txt_path, text)
        File.write!(sha256_path, sha256)
        IO.puts text
      :false ->
        IO.puts File.read!(txt_path)
    end
  end

  def download_stories(stories) do
    Enum.map(stories, &download_story/1)
    |> Enum.reject(&Enum.empty?/1)
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

  def download_topstories do
    "https://hacker-news.firebaseio.com/v0/topstories.json"
    |> get_body!
    |> Poison.Parser.parse!
    |> Enum.sort # To avoid cache becoming invalid due to reordering of stories!
  end

  def home_path(name) do
     Path.absname(System.user_home!) |> Path.join(name)
  end
  def sha256_path do
    home_path("topstories.sha256")
  end
  def txt_path do
    home_path("topstories.txt")
  end

  def need_update?(sha256) do
    case File.read(sha256_path) do
      {:error, :enoent} -> :true
      {:ok, local} ->
        case String.equivalent?(sha256, local) do
          :true -> :false
          :false -> :true
        end
    end
  end

  def hash(data) do
      <<x ::unsigned-big-integer-256>> = :crypto.hash(:sha256, data)
      x
  end

  def get_body!(url) do
    %HTTPoison.Response{status_code: 200, body: body} = HTTPoison.get!(url, [], hackney: [:insecure])
    body
  end

  def pmap(collection, func, timeout_ms \\ 10_000) do
    collection
    |> Enum.map(&(Task.async(fn -> func.(&1) end)))
    |> Enum.map(fn t -> Task.await(t, timeout_ms) end)
  end
end
