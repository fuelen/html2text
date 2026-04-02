# HTML2Text
[![Hex.pm](https://img.shields.io/hexpm/v/html2text.svg)](https://hex.pm/packages/html2text)

A high-performance Elixir library for converting HTML to plain text or annotated rich text using Rust NIFs (Native Implemented Functions).

## Overview

HTML2Text provides a simple and efficient way to extract readable text from HTML content. It leverages Rust's [html2text](https://crates.io/crates/html2text) crate for fast HTML parsing and text extraction.

Two conversion modes are available:
- **Plain text** (`convert/2`) — markdown-like output with `**bold**`, `*italic*`, link footnotes, table borders
- **Rich text** (`convert_rich/2`) — structured `{text, annotations}` tuples for building custom renderers (ANSI terminal, Slack, Inspect protocol, etc.)

## Installation

Add `html2text` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:html2text, "~> 0.2"}
  ]
end
```

Then run:

```bash
mix deps.get
```

## Usage

### Plain text

```elixir
# Convert with specific line width
html = "<h1>Welcome</h1><p>This is a sample paragraph with some content.</p>"
text = HTML2Text.convert!(html, width: 30)
IO.puts(text)

# Output:
# # Welcome
#
# This is a sample paragraph
# with some content.

html = """
<article>
  <h1>Article Title</h1>
  <p><strong>Introduction:</strong> This article covers important topics.</p>

  <h2>Section 1</h2>
  <p>Content with <em>emphasis</em> and <a href="http://example.com">links</a>.</p>

  <ul>
    <li>Point one</li>
    <li>Point two</li>
  </ul>

  <h2>Section 2: Simple Table</h2>
  <p>Key metrics overview:</p>

  <table border="1" cellpadding="6" cellspacing="0">
    <thead>
      <tr>
        <th>Metric</th>
        <th>Value</th>
        <th>Change</th>
      </tr>
    </thead>
    <tbody>
      <tr>
        <td>Users</td>
        <td>15,300</td>
        <td>+12%</td>
      </tr>
      <tr>
        <td>Sessions</td>
        <td>48,500</td>
        <td>-5%</td>
      </tr>
    </tbody>
  </table>

  <h2>Conclusion</h2>
  <p>This article provided an overview of important web technologies and some key statistics.</p>
</article>
"""

text = HTML2Text.convert!(html)
IO.puts(text)

# Output:
# # Article Title
#
# **Introduction:** This article covers important topics.
#
# ## Section 1
#
# Content with *emphasis* and [links][1].
# * Point one
# * Point two
#
# ## Section 2: Simple Table
#
# Key metrics overview:
#
# ────────┬──────┬──────
# Metric  │Value │Change
# ────────┼──────┼──────
# Users   │15,300│+12%  
# ────────┼──────┼──────
# Sessions│48,500│-5%   
# ────────┴──────┴──────
#
# ## Conclusion
#
# This article provided an overview of important web technologies and some key
# statistics.
#
# [1]: http://example.com
```

### Rich text

```elixir
# Rich mode returns annotated segments instead of formatted text
{:ok, lines} = HTML2Text.convert_rich("<p>Hello <strong>world</strong></p>")
# => {:ok, [[{"Hello ", []}, {"world", [:strong]}]]}

# Annotations stack for nested elements
{:ok, lines} = HTML2Text.convert_rich(~s(<a href="https://ex.com"><em>click</em></a>))
# => {:ok, [[{"click", [{:link, "https://ex.com"}, :emphasis]}]]}

# Extract CSS colours with use_doc_css
html = ~s(<p style="color: red">alert</p>)
{:ok, lines} = HTML2Text.convert_rich(html, use_doc_css: true)
# => {:ok, [[{"alert", [colour: {255, 0, 0}]}]]}
```

Available annotations: `:default`, `:emphasis`, `:strong`, `:strikeout`, `:code`,
`{:link, url}`, `{:image, src}`, `{:preformat, bool}`, `{:colour, {r, g, b}}`,
`{:bg_colour, {r, g, b}}`.
