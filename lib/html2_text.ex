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


  use RustlerPrecompiled,
    otp_app: :html2text,
    crate: "html2text_nif",
    base_url: "#{github_url}/releases/download/v#{version}",
    version: version,
    force_build: System.get_env("HTML2TEXT_BUILD") in ["1", "true"]

  @spec convert(String.t(), pos_integer() | :infinity) :: String.t()
  @doc """
  Converts HTML content to plain text with configurable line width.

  This function converts HTML content to plain text and optionally wraps lines at the
  specified width. The width can be either a positive integer representing the maximum
  number of characters per line, or `:infinity` for unlimited line width.

  ## Parameters

  - `html` - A binary containing the HTML content to convert
  - `width` - Either a positive integer for line width or `:infinity` for unlimited width

  ## Return Value

  Returns a string containing the plain text representation of the HTML content.

  ## Examples

      # Converting with specific width
      iex> html = "<h1>Welcome to Our Amazing Website</h1><p>This is a comprehensive guide that covers everything you need to know about our services and products.</p>"
      iex> HTML2Text.convert(html, 30)
      "# Welcome to Our Amazing\\n# Website\\n\\nThis is a comprehensive guide\\nthat covers everything you\\nneed to know about our\\nservices and products.\\n"

      # Converting with unlimited width
      iex> html = "<div><strong>Important:</strong> Please read all the terms and conditions carefully before proceeding with your purchase.</div>"
      iex> HTML2Text.convert(html, :infinity)
      "**Important:** Please read all the terms and conditions carefully before proceeding with your purchase.\\n"

      # Converting lists and complex HTML
      iex> html = "<ul><li>First item with some detailed description</li><li>Second item that also has quite a bit of text</li><li>Third item</li></ul>"
      iex> HTML2Text.convert(html, 25)
      "* First item with some\\n  detailed description\\n* Second item that also\\n  has quite a bit of text\\n* Third item\\n"

      # Converting tables and structured content
      iex> html = "<table><tr><td>Product Name</td><td>Description</td><td>Price</td></tr><tr><td>Widget</td><td>A useful widget for everyday tasks</td><td>$19.99</td></tr></table>"
      iex> HTML2Text.convert(html, 50)
      \"""
      ───────────┬────────────────────────────────┬─────
      Product    │Description                     │Price
      Name       │                                │     
      ───────────┼────────────────────────────────┼─────
      Widget     │A useful widget for everyday    │$19.9
                 │tasks                           │9    
      ───────────┴────────────────────────────────┴─────
      \"""

  """
  def convert(html, :infinity) when is_binary(html) do
    do_convert(html, :infinity)
  end

  def convert(html, width) when is_binary(html) and is_integer(width) and width > 0 do
    do_convert(html, width)
  end

  defp do_convert(_html, _width), do: :erlang.nif_error(:nif_not_loaded)
end
