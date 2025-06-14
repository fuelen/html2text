# HTML2Text
[![Hex.pm](https://img.shields.io/hexpm/v/html2text.svg)](https://hex.pm/packages/html2text)

A high-performance Elixir library for converting HTML documents to plain text format using Rust NIFs (Native Implemented Functions).

## Overview

HTML2Text provides a simple and efficient way to extract readable plain text from HTML content. It leverages the power of Rust's [html2text](https://crates.io/crates/html2text) crate to deliver fast HTML parsing and text extraction while maintaining the logical structure and readability of the content.

## Installation

Add `html2text` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:html2text, "~> 0.1"}
  ]
end
```

Then run:

```bash
mix deps.get
```

## Usage

The library provides a single main function `HTML2Text.convert/2` that takes HTML content and a width parameter.

```elixir
# Convert with specific line width
html = "<h1>Welcome</h1><p>This is a sample paragraph with some content.</p>"
text = HTML2Text.convert(html, 30)
IO.puts(text)
# Output:
# # Welcome
#
# This is a sample paragraph
# with some content.


# Convert with unlimited width
text = HTML2Text.convert(html, :infinity)
IO.puts(text)
# Output:
# # Welcome
#
# This is a sample paragraph with some content.

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

text = HTML2Text.convert(html, 70)
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
# This article provided an overview of important web technologies and
# some key statistics.
#
# [1]: http://example.com
```
