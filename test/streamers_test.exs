defmodule StreamersTest do
  use ExUnit.Case, async: true
  doctest Streamers
  alias Streamers.M3U8, as: M3U8

  @index_file   "test/fixtures/emberjs/9af0270acb795f9dcafb5c51b1907628.m3u8"
  @m3u8_sample  "test/fixtures/emberjs/8bda35243c7c0a7fc69ebe1383c6464c.m3u8"

  test "find the index file in a directory" do
    assert Streamers.find_index("test/fixtures/emberjs") == @index_file
  end

  test "returns nil for not available index file" do
    assert Streamers.find_index("test/fixtures/not_available") == nil
  end

  test "extract m3u8 from index file" do
    m3u8s = Streamers.extract_m3u8(@index_file)
    assert List.first(m3u8s) == %M3U8{program_id: 1, bandwidth: 110000, path: @m3u8_sample }

    assert Enum.count(m3u8s) == 5

  end


  test "processes m3u8" do
    m3u8s = @index_file |> Streamers.extract_m3u8 |> Streamers.process_m3u8
    
    sample = Enum.find(m3u8s, fn(m3u8) -> m3u8.path == @m3u8_sample end)

    assert Enum.count(sample.ts_files) == 510
  end
end
