defmodule HTML2Text.HTML do
  @moduledoc """
  A container for HTML content with rich terminal inspection.

  Stores raw HTML and renders it as formatted text with ANSI styles when inspected
  in IEx. Useful for working with data that contains HTML — instead of seeing raw
  tags, you see readable formatted text with bold, italic, colours, clickable links,
  and other styles applied.

  `to_string/1` returns the original HTML unchanged.

  ## Usage

  Wrap any HTML string to make it inspectable:

      html = HTML2Text.HTML.new("<p>Hello <strong>world</strong></p>")
      #=> #HTML2Text.HTML<Hello **world**>

  Works naturally inside data structures:

      # In an Ecto schema or any map
      %{subject: "Alert", body: HTML2Text.HTML.new(email_html)}

      # In IEx you see formatted text instead of raw HTML tags:
      # %{subject: "Alert", body: #HTML2Text.HTML<
      #     Dear customer,
      #
      #     Your order has been **shipped**.
      #     Track it here: https://example.com/track
      #   >}

  ## Supported styles

  The following HTML elements are rendered with ANSI terminal styles:

  | HTML | Terminal style |
  |------|---------------|
  | `<strong>`, `<b>` | Bold |
  | `<em>`, `<i>` | Italic |
  | `<code>` | Cyan |
  | `<s>`, `<del>` | Strikeout |
  | `<a href="...">` | Blue underline, clickable (OSC 8) |
  | `<img>` | Yellow |
  | `<pre>` | Faint |
  | CSS `color` | True color (24-bit RGB) |
  | CSS `background-color` | True color (24-bit RGB) |

  CSS colours are extracted when the HTML contains `<style>` tags or inline styles.

  ## Examples

      iex> html = HTML2Text.HTML.new("<p>Hello <strong>world</strong></p>")
      iex> to_string(html)
      "<p>Hello <strong>world</strong></p>"

  """

  defstruct [:source]

  @type t :: %__MODULE__{source: String.t()}

  @doc "Creates a new HTML container from a source string."
  @spec new(String.t()) :: t()
  def new(source) when is_binary(source), do: %__MODULE__{source: source}
end

defimpl String.Chars, for: HTML2Text.HTML do
  def to_string(%HTML2Text.HTML{source: source}), do: source
end

defimpl Inspect, for: HTML2Text.HTML do
  import Inspect.Algebra

  @nesting 2
  @prefix_len String.length("#HTML2Text.HTML<")

  def inspect(%HTML2Text.HTML{source: source}, opts) do
    width = max(opts.width - @nesting - @prefix_len, 20)

    case HTML2Text.convert_rich(source, width: width, use_doc_css: true) do
      {:ok, lines} ->
        {lines, truncated} = truncate_lines(lines, opts.printable_limit)
        formatted = Enum.map(lines, &format_line(&1, opts))
        formatted = if truncated, do: formatted ++ [string("...")], else: formatted
        render_doc(formatted, length(lines) <= 1 and not truncated, opts)

      {:error, _} ->
        concat(["#HTML2Text.HTML<", source, ">"])
    end
  end

  defp render_doc(formatted, inline?, opts) do
    {sep, br} = if inline?, do: {break(""), break("")}, else: {line(), line()}
    ansi? = opts.syntax_colors != []

    inner =
      formatted
      |> Enum.intersperse(sep)
      |> Enum.reduce(empty(), &concat(&2, &1))

    doc =
      concat([
        "#HTML2Text.HTML<",
        if(ansi?, do: string(IO.ANSI.default_color()), else: empty()),
        nest(concat(br, inner), 2),
        br,
        if(ansi?, do: string(restore_code(opts.syntax_colors)), else: empty()),
        ">"
      ])

    if inline?, do: group(doc), else: doc
  end

  defp format_line([], _opts), do: empty()

  defp format_line(segments, opts) do
    segments
    |> Enum.map(fn {text, annotations} -> format_segment(text, annotations, opts) end)
    |> Enum.reduce(empty(), &concat(&2, &1))
  end

  defp format_segment(text, annotations, opts) do
    ansi =
      annotations
      |> Enum.map(&annotation_to_ansi/1)
      |> Enum.reject(&is_nil/1)

    if opts.syntax_colors != [] and ansi != [] do
      {prefixes, suffixes} = Enum.unzip(ansi)
      prefix = Enum.join(prefixes)
      suffix = Enum.join(suffixes)
      concat([string(prefix), string(text), string(suffix)])
    else
      string(text)
    end
  end

  defp restore_code(syntax_colors) do
    syntax_colors
    |> Keyword.get(:reset, :reset)
    |> List.wrap()
    |> IO.ANSI.format_fragment(true)
    |> IO.chardata_to_string()
  end

  defp annotation_to_ansi(:strong), do: {IO.ANSI.bright(), IO.ANSI.normal()}
  defp annotation_to_ansi(:emphasis), do: {IO.ANSI.italic(), IO.ANSI.not_italic()}
  defp annotation_to_ansi(:strikeout), do: {IO.ANSI.crossed_out(), "\e[29m"}
  defp annotation_to_ansi(:code), do: {IO.ANSI.cyan(), IO.ANSI.default_color()}
  defp annotation_to_ansi({:image, _src}), do: {IO.ANSI.yellow(), IO.ANSI.default_color()}
  defp annotation_to_ansi({:preformat, _}), do: {IO.ANSI.faint(), IO.ANSI.normal()}

  defp annotation_to_ansi({:link, url}) do
    {IO.ANSI.underline() <> IO.ANSI.blue() <> open_hyperlink(url),
     close_hyperlink() <> IO.ANSI.no_underline() <> IO.ANSI.default_color()}
  end

  defp annotation_to_ansi({:colour, {r, g, b}}),
    do: {"\e[38;2;#{r};#{g};#{b}m", IO.ANSI.default_color()}

  defp annotation_to_ansi({:bg_colour, {r, g, b}}),
    do: {"\e[48;2;#{r};#{g};#{b}m", IO.ANSI.default_background()}

  defp annotation_to_ansi(_), do: nil

  defp open_hyperlink(url),
    do: "\e]8;id=#{:erlang.phash2(url)};#{url}\e\\"

  defp close_hyperlink,
    do: "\e]8;;\e\\"

  defp truncate_lines(lines, :infinity), do: {lines, false}

  defp truncate_lines(lines, limit) do
    {acc, _, truncated} =
      Enum.reduce_while(lines, {[], 0, false}, fn line, {acc, chars, _} ->
        line_chars = line |> Enum.map(fn {text, _} -> String.length(text) end) |> Enum.sum()

        if chars + line_chars > limit do
          {:halt, {acc, chars, true}}
        else
          {:cont, {[line | acc], chars + line_chars, false}}
        end
      end)

    {Enum.reverse(acc), truncated}
  end
end
