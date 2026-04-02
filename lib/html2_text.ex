defmodule HTML2Text.Error do
  defexception [:message]
end

defmodule HTML2Text do
  @moduledoc """
  A native-implemented HTML to plain text converter using Rust NIF.

  This module provides functionality to convert HTML documents to plain text format
  with configurable line width wrapping. It uses the Rust `html2text` crate under
  the hood for high-performance HTML parsing and text extraction.

  The converter handles HTML entities, removes tags, and formats the output as
  readable plain text while preserving the logical structure of the content.

  See: https://github.com/jugglerchris/rust-html2text
  """

  mix_config = Mix.Project.config()
  version = mix_config[:version]
  github_url = mix_config[:package][:links]["GitHub"]

  targets = ~w(
    aarch64-apple-darwin
    aarch64-unknown-linux-gnu
    aarch64-unknown-linux-musl
    riscv64gc-unknown-linux-gnu
    x86_64-apple-darwin
    x86_64-pc-windows-gnu
    x86_64-pc-windows-msvc
    x86_64-unknown-linux-gnu
    x86_64-unknown-linux-musl
  )

  nif_versions = ~w(2.17 2.16)

  use RustlerPrecompiled,
    otp_app: :html2text,
    crate: "html2text_nif",
    base_url: "#{github_url}/releases/download/v#{version}",
    nif_versions: nif_versions,
    targets: targets,
    version: version,
    force_build: System.get_env("HTML2TEXT_BUILD") in ["1", "true"]

  @type annotation ::
          :default
          | :emphasis
          | :strong
          | :strikeout
          | :code
          | {:link, url :: String.t()}
          | {:image, src :: String.t()}
          | {:preformat, continuation :: boolean()}
          | {:colour, {r :: non_neg_integer(), g :: non_neg_integer(), b :: non_neg_integer()}}
          | {:bg_colour, {r :: non_neg_integer(), g :: non_neg_integer(), b :: non_neg_integer()}}

  @type segment :: {text :: String.t(), annotations :: [annotation()]}
  @type line :: [segment()]

  @type rich_opts :: [
          width: pos_integer() | :infinity,
          table_borders: boolean(),
          pad_block_width: boolean(),
          allow_width_overflow: boolean(),
          min_wrap_width: pos_integer(),
          raw: boolean(),
          wrap_links: boolean(),
          empty_img_mode: :ignore | {:replace, String.t()} | :filename,
          use_doc_css: boolean(),
          css: String.t()
        ]

  @type opts :: [
          width: pos_integer() | :infinity,
          decorate: boolean(),
          link_footnotes: boolean(),
          table_borders: boolean(),
          pad_block_width: boolean(),
          allow_width_overflow: boolean(),
          min_wrap_width: pos_integer(),
          raw: boolean(),
          wrap_links: boolean(),
          unicode_strikeout: boolean(),
          empty_img_mode: :ignore | {:replace, String.t()} | :filename
        ]

  @doc """
  Converts HTML content to plain text.

  ## Options
  - `:width` — Maximum line width (positive integer or `:infinity`). Defaults to `80`. Setting to `:infinity` disables line wrapping and outputs the entire text on a single line.
  - `:decorate` — Enables text decorations like bold or italic. Boolean, defaults to `true`. When `false`, output is plain text without styling.
  - `:link_footnotes` — Adds numbered link footnotes at the end of the text. Boolean, defaults to `true`. When `false`, links are omitted.
  - `:table_borders` — Shows ASCII borders around table cells. Boolean, defaults to `true`. When `false`, tables render without borders.
  - `:pad_block_width` — Pads blocks with spaces to align text to full width. Boolean, defaults to `false`. Useful for fixed-width layouts.
  - `:allow_width_overflow` — Allows lines to exceed the specified width if wrapping is impossible. Boolean, defaults to `false`. Prevents errors when content can't fit.
  - `:min_wrap_width` — Minimum length of text chunks when wrapping lines. Integer ≥ 1, defaults to `3`. Helps avoid awkwardly narrow wraps.
  - `:raw` — Enables raw mode with minimal processing and formatting. Boolean, defaults to `false`. Produces plain, raw text output.
  - `:wrap_links` — Wraps long URLs or links onto multiple lines. Boolean, defaults to `true`. When `false`, links stay on a single line and may overflow.
  - `:unicode_strikeout` — Uses Unicode characters for strikeout text. Boolean, defaults to `true`. When `false`, strikeout renders in simpler styles.
  - `:empty_img_mode` — Controls how images without alt text are rendered. Accepts `:ignore` (skip images without alt text, default), `{:replace, text}` (replace with static text like `"[image]"`), or `:filename` (use the image filename from URL).

  ## Examples

      iex> html = "<h1>Title</h1><p>Some paragraph text.</p>"
      ...> HTML2Text.convert(html, width: 15)
      {:ok, "# Title\\n\\nSome paragraph\\ntext.\\n"}

      iex> HTML2Text.convert("<b>Important</b>", decorate: false)
      {:ok, "Important\\n"}

      iex> HTML2Text.convert("<table><tr><td>A</td><td>B</td></tr></table>", [])
      {:ok, "─┬─\\nA│B\\n─┴─\\n"}

      iex> HTML2Text.convert("<p><a href=\\"https://example.com\\">link</a></p>", link_footnotes: false)
      {:ok, "[link]\\n"}

  """
  @spec convert(html :: String.t(), opts()) ::
          {:ok, text :: String.t()} | {:error, reason :: String.t()}
  def convert(html, opts \\ []) do
    do_convert(html, opts)
  end

  @doc """
  Converts HTML content to plain text, raising on failure.

  This function behaves like `convert/2`, but raises an error if conversion fails.

  ## Examples

      iex> HTML2Text.convert!("<p>hello</p>")
      "hello\\n"

      iex> HTML2Text.convert!("<em>italic</em>")
      "*italic*\\n"

  """
  @spec convert!(html :: String.t(), opts :: opts()) :: String.t()
  def convert!(html, opts \\ []) do
    case do_convert(html, opts) do
      {:ok, text} -> text
      {:error, reason} -> raise HTML2Text.Error, reason
    end
  end

  @doc """
  Converts HTML content to annotated rich text.

  Returns a list of lines, where each line is a list of `{text, annotations}` tuples.
  Annotations are stacked — a text segment inside `<strong><a href="...">` will have
  `[{:link, url}, :strong]`, with the outer annotation first.

  ## Options
  - `:width` — Maximum line width (positive integer or `:infinity`). Defaults to `80`.
  - `:table_borders` — Shows ASCII borders around table cells. Boolean, defaults to `true`.
  - `:pad_block_width` — Pads blocks with spaces to align text to full width. Boolean, defaults to `false`.
  - `:allow_width_overflow` — Allows lines to exceed the specified width. Boolean, defaults to `false`.
  - `:min_wrap_width` — Minimum length of text chunks when wrapping. Integer ≥ 1, defaults to `3`.
  - `:raw` — Enables raw mode with minimal processing. Boolean, defaults to `false`.
  - `:wrap_links` — Wraps long URLs onto multiple lines. Boolean, defaults to `true`.
  - `:empty_img_mode` — Controls how images without alt text are rendered. Accepts `:ignore` (default), `{:replace, text}`, or `:filename`.
  - `:use_doc_css` — Parse `<style>` tags from the HTML to extract colour annotations. Boolean, defaults to `false`.
  - `:css` — Additional CSS rules to apply. String, defaults to `nil`.

  ## Annotations
  - `:default` — Normal text
  - `:emphasis` — `<em>` tag
  - `:strong` — `<strong>` / `<b>` tag
  - `:strikeout` — `<s>` / `<del>` tag
  - `:code` — `<code>` tag
  - `{:link, url}` — `<a href="...">` tag
  - `{:image, src}` — `<img src="...">` tag
  - `{:preformat, bool}` — `<pre>` block (`true` if continuation line)
  - `{:colour, {r, g, b}}` — CSS text color
  - `{:bg_colour, {r, g, b}}` — CSS background color

  ## Examples

      iex> HTML2Text.convert_rich("<p>Hello <strong>world</strong></p>")
      {:ok, [[{"Hello ", []}, {"world", [:strong]}]]}

      iex> HTML2Text.convert_rich("<em>text</em>")
      {:ok, [[{"text", [:emphasis]}]]}

      iex> HTML2Text.convert_rich(~s(<a href="https://example.com">click</a>))
      {:ok, [[{"click", [link: "https://example.com"]}]]}

      iex> HTML2Text.convert_rich(~s(<a href="https://ex.com"><strong>bold link</strong></a>))
      {:ok, [[{"bold link", [{:link, "https://ex.com"}, :strong]}]]}

  """
  @spec convert_rich(html :: String.t(), rich_opts()) ::
          {:ok, [line()]} | {:error, reason :: String.t()}
  def convert_rich(html, opts \\ []) do
    do_convert_rich(html, opts)
  end

  @doc """
  Converts HTML content to annotated rich text, raising on failure.

  This function behaves like `convert_rich/2`, but raises an error if conversion fails.

  ## Examples

      iex> HTML2Text.convert_rich!("<p>hello</p>")
      [[{"hello", []}]]

      iex> HTML2Text.convert_rich!("<code>x = 1</code>")
      [[{"x = 1", [:code]}]]

  """
  @spec convert_rich!(html :: String.t(), rich_opts()) :: [line()]
  def convert_rich!(html, opts \\ []) do
    case do_convert_rich(html, opts) do
      {:ok, lines} -> lines
      {:error, reason} -> raise HTML2Text.Error, reason
    end
  end

  defp do_convert(_html, _opts), do: :erlang.nif_error(:nif_not_loaded)
  defp do_convert_rich(_html, _opts), do: :erlang.nif_error(:nif_not_loaded)
end
