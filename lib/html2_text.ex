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
          unicode_strikeout: boolean()
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

  ## Examples

      iex> html = "<h1>Title</h1><p>Some paragraph text.</p>"
      ...> HTML2Text.convert(html, width: 15)
      {:ok, "# Title\\n\\nSome paragraph\\ntext.\\n"}

      iex> HTML2Text.convert("<b>Important</b>", decorate: false)
      {:ok, "Important\\n"}

      iex> HTML2Text.convert("<table><tr><td>A</td><td>B</td></tr></table>", [])
      {:ok, "─┬─\\nA│B\\n─┴─\\n"}

  """
  @spec convert(html :: String.t(), opts()) :: {:ok, text :: String.t()} | {:error, reason :: String.t()}
  def convert(html, opts \\ []) do
    do_convert(html, opts)
  end

  @doc """
  Converts HTML content to plain text, raising on failure.

  This function behaves like `convert/2`, but raises an error if conversion fails.
  """
  @spec convert!(html :: String.t(), opts :: opts()) :: String.t()
  def convert!(html, opts \\ []) do
    case do_convert(html, opts) do
      {:ok, text} -> text
      {:error, reason} -> raise "HTML to text conversion failed: #{reason}"
    end
  end

  defp do_convert(_html, _opts), do: :erlang.nif_error(:nif_not_loaded)
end
