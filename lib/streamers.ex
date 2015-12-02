defmodule Streamers do
  require Logger

  defmodule M3U8 do
    defstruct program_id: nil, path: nil, bandwidth: nil, ts_files: []
  end

  @doc """
  Find streaming index file in the given directory.

  ## Examples
    iex> Streamers.find_index("this/doesnt/exist")
    nil
  """
  def find_index(directory) do
    files = Path.join(directory, "*.m3u8")
    if file = Enum.find Path.wildcard(files), &is_index?(&1) do
      file
    end
  end

  defp is_index?(file) do
    File.open!(file, [:read], fn(file) ->
      IO.read(file, 25) == "#EXTM3U\n#EXT-X-STREAM-INF"
    end)
  end

  @doc """
  Extract M3U8 records from the index file.
  """
  def extract_m3u8(index_file) do
    File.open! index_file, fn(pid) ->
      # Discards #EXTM3U
       IO.read(pid, :line)
       do_extract_m3u8(pid, Path.dirname(index_file), [])
    end
  end

  defp do_extract_m3u8(pid, dir, accumulator) do
    case IO.read(pid, :line) do
      :eof -> Enum.reverse(accumulator)
      stream_inf ->
        path = IO.read(pid, :line)
        do_extract_m3u8(pid, dir, stream_inf, path, accumulator)
    end
  end

  defp do_extract_m3u8(pid, dir, stream_inf, path, acc) do
    
    << "#EXT-X-STREAM-INF:PROGRAM-ID=", program_id, ",BANDWIDTH=", bandwidth :: binary >> = stream_inf 

    program_id = String.to_integer(<<program_id>>)
    path = Path.join(dir, String.strip(path))

    bandwidth = bandwidth |> String.strip |> String.to_integer

    record = %M3U8{program_id: program_id, path: path, bandwidth: bandwidth}

    do_extract_m3u8(pid, dir, [record|acc])
  end

  @doc """
  Process M3U8 records to get ts_files
  """
  def process_m3u8(m3u8s) do
    Enum.map m3u8s, &do_parallel_process_m3u8(&1, self)

    do_collect_m3u8(Enum.count(m3u8s), [])
  end

  defp do_parallel_process_m3u8(m3u8, parent_pid) do
    spawn(fn -> 
      updated_m3u8 = do_process_m3u8(m3u8) 
      send parent_pid, {:m3u8, updated_m3u8}
    end)
  end

  defp do_collect_m3u8(0, acc), do: acc

  defp do_collect_m3u8(count, acc) do
    receive do
      {:m3u8, updated_m3u8} ->
        do_collect_m3u8(count - 1, [updated_m3u8 | acc])
    end
  end

  defp do_process_m3u8(%M3U8{program_id: program_id, path: path, bandwidth: bandwidth} = m3u8) do
    File.open! path, fn(pid) ->
      #Discards #EXTM3U
      IO.read(pid, :line)

      #Discards #EXT-X-TARGETDURATION:15
      IO.read(pid, :line)

      #m3u8.ts_files[do_process_m3u8(pid, [])
      m3u8_files = do_process_m3u8(pid, [])

      %M3U8{program_id: program_id, path: path, bandwidth: bandwidth, ts_files: m3u8_files}
    end
  end

  defp do_process_m3u8(pid, accumulator) do
    case IO.read(pid, :line) do
      "#EXT-X-ENDLIST\n" -> Enum.reverse(accumulator)
      extinf when is_binary(extinf) -> #Discards #EXTINF:10,
        # 8bda35243c7c0a7fc69ebe1383c6464c-00001.ts
        file = IO.read(pid, :line)
        do_process_m3u8(pid, [file | accumulator])
      end
  end
end
