defmodule HTML2TextTest do
  use ExUnit.Case
  doctest HTML2Text

  describe "convert2" do
    @html """
    <html>
      <head><title>Test</title></head>
      <body>
        <h1>Heading</h1>
        <p>This is a <strong>test</strong> of the HTML2Text conversion.</p>
        <a href="https://example.com">link</a>
        <table>
          <tr><td>Item</td><td>Qty</td></tr>
          <tr><td>Book</td><td>2</td></tr>
        </table>
        <p><s>Strike</s></p>
        <p><strong>Strong</strong></p>
        <p><em>Em</em></p>
      </body>
    </html>
    """

    test "default conversion" do
      assert {:ok, text} = HTML2Text.convert(@html)

      assert text == """
             # Heading

             This is a **test** of the HTML2Text conversion.

             [link][1]

             ────┬───
             Item│Qty
             ────┼───
             Book│2  
             ────┴───

             S̶t̶r̶i̶k̶e̶

             **Strong**

             *Em*

             [1]: https://example.com
             """
    end

    test "width as integer" do
      assert {:ok, text} = HTML2Text.convert(@html, width: 10)

      assert text == """
             # Heading

             This is a
             **test**
             of the
             HTML2Text
             conversion
             .

             [link][1]

             ────┬───
             Item│Qty
             ────┼───
             Book│2  
             ────┴───

             S̶t̶r̶i̶k̶e̶

             **Strong**

             *Em*

             [1]: https
             ://example
             .com
             """
    end

    test "width as :infinity" do
      assert {:ok, text} = HTML2Text.convert(@html, width: :infinity)

      assert text == """
             # Heading

             This is a **test** of the HTML2Text conversion.

             [link][1]

             ────┬───
             Item│Qty
             ────┼───
             Book│2  
             ────┴───

             S̶t̶r̶i̶k̶e̶

             **Strong**

             *Em*

             [1]: https://example.com
             """
    end

    test "decorate: false" do
      assert {:ok, text} = HTML2Text.convert(@html, decorate: false)

      assert text == """
             # Heading

             This is a test of the HTML2Text conversion.

             [link][1]

             ────┬───
             Item│Qty
             ────┼───
             Book│2  
             ────┴───

             S̶t̶r̶i̶k̶e̶

             Strong

             Em

             [1]: https://example.com
             """
    end

    test "link_footnotes: false" do
      assert {:ok, text} = HTML2Text.convert(@html, link_footnotes: false)

      assert text == """
             # Heading

             This is a **test** of the HTML2Text conversion.

             [link]

             ────┬───
             Item│Qty
             ────┼───
             Book│2  
             ────┴───

             S̶t̶r̶i̶k̶e̶

             **Strong**

             *Em*
             """
    end

    test "table_borders: false" do
      assert {:ok, text} = HTML2Text.convert(@html, table_borders: false)

      assert text == """
             # Heading

             This is a **test** of the HTML2Text conversion.

             [link][1]

             Item Qty
             Book 2  

             S̶t̶r̶i̶k̶e̶

             **Strong**

             *Em*

             [1]: https://example.com
             """
    end

    test "pad_block_width: true" do
      assert {:ok, text} = HTML2Text.convert(@html, pad_block_width: true, width: 10)

      assert text == """
             # Heading 
                       
             This is a 
             **test**  
             of the    
             HTML2Text 
             conversion
             .         
                       
             [link][1] 
                       
             ────┬───
             Item│Qty  
             ────┼───
             Book│2    
             ────┴───
                       
             S̶t̶r̶i̶k̶e̶    
                       
             **Strong**
                       
             *Em*      
                       
             [1]: https
             ://example
             .com      
             """

      assert is_binary(text)
    end

    test "allow_width_overflow: true" do
      assert {:error, "Output width not wide enough."} =
               HTML2Text.convert(@html, allow_width_overflow: false, width: 4)

      assert {:ok, text} = HTML2Text.convert(@html, allow_width_overflow: true, width: 4)

      assert text == """
             # Hea
             # din
             # g

             This
             is a
             **te
             st**
             of
             the
             HTML
             2Tex
             t
             conv
             ersi
             on.

             [lin
             k][1
             ]

             ────
             Item
             ////
             Qty
             ────
             Book
             ////
             2
             ────

             S̶t̶r̶i̶
             k̶e̶

             **St
             rong
             **

             *Em*

             [1]:
              htt
             ps:/
             /exa
             mple
             .com
             """
    end

    test "min_wrap_width" do
      assert {:error, "Output width not wide enough."} =
               HTML2Text.convert(@html, width: 8, min_wrap_width: 7)
    end

    test "raw: true" do
      assert {:ok, text} = HTML2Text.convert(@html, raw: true)

      assert text == """
             # Heading

             This is a **test** of the HTML2Text conversion.

             [link][1]

             Item
             Qty
             Book
             2

             S̶t̶r̶i̶k̶e̶

             **Strong**

             *Em*

             [1]: https://example.com
             """
    end

    test "wrap_links: false" do
      assert {:ok, text} = HTML2Text.convert(@html, wrap_links: false, width: 10)

      assert text == """
             # Heading

             This is a
             **test**
             of the
             HTML2Text
             conversion
             .

             [link][1]

             ────┬───
             Item│Qty
             ────┼───
             Book│2  
             ────┴───

             S̶t̶r̶i̶k̶e̶

             **Strong**

             *Em*

             [1]: https://example.com
             """
    end

    test "unicode_strikeout: false" do
      assert {:ok, text} = HTML2Text.convert(@html, unicode_strikeout: false)

      assert text == """
             # Heading

             This is a **test** of the HTML2Text conversion.

             [link][1]

             ────┬───
             Item│Qty
             ────┼───
             Book│2  
             ────┴───

             Strike

             **Strong**

             *Em*

             [1]: https://example.com
             """
    end

    test "invalid HTML still returns ok tuple" do
      assert {:ok, ""} = HTML2Text.convert("<invalid><html>")
    end

    test "ignore options with invalid types" do
      assert {:ok, _} = HTML2Text.convert(@html, width: "not_a_number", decorate: "not_a_boolean")
    end

    test "empty_img_mode: :ignore" do
      html = ~s(<p>Text</p><img src="photo.jpg"><p>More</p>)
      assert {:ok, "Text\n\nMore\n"} = HTML2Text.convert(html, empty_img_mode: :ignore)
    end

    test "empty_img_mode: {:replace, text}" do
      html = ~s(<p>Text</p><img src="photo.jpg"><p>More</p>)

      assert {:ok, "Text\n\n[[img]]\n\nMore\n"} =
               HTML2Text.convert(html, empty_img_mode: {:replace, "[img]"})
    end

    test "empty_img_mode: :filename" do
      html = ~s(<p>Text</p><img src="https://example.com/photo.jpg"><p>More</p>)

      assert {:ok, "Text\n\n[photo.jpg]\n\nMore\n"} =
               HTML2Text.convert(html, empty_img_mode: :filename)
    end

    test "convert! raises HTML2Text.Error" do
      assert_raise HTML2Text.Error, "Output width not wide enough.", fn ->
        HTML2Text.convert!(@html, allow_width_overflow: false, width: 4)
      end
    end
  end

  describe "convert_rich" do
    test "basic text with strong" do
      assert {:ok, [[{"Hello ", []}, {"world", [:strong]}]]} =
               HTML2Text.convert_rich("<p>Hello <strong>world</strong></p>")
    end

    test "emphasis annotation" do
      assert {:ok, [[{"text", [:emphasis]}]]} =
               HTML2Text.convert_rich("<em>text</em>")
    end

    test "link annotation" do
      assert {:ok, [[{"click", [{:link, "https://example.com"}]}]]} =
               HTML2Text.convert_rich(~s(<a href="https://example.com">click</a>))
    end

    test "nested annotations stack" do
      assert {:ok, [[{"bold link", [{:link, "https://ex.com"}, :strong]}]]} =
               HTML2Text.convert_rich(~s(<a href="https://ex.com"><strong>bold link</strong></a>))
    end

    test "strikeout annotation" do
      assert {:ok, [[{"d̶e̶l̶e̶t̶e̶d̶", [:strikeout]}]]} =
               HTML2Text.convert_rich("<s>deleted</s>")
    end

    test "code annotation" do
      assert {:ok, [[{"x = 1", [:code]}]]} =
               HTML2Text.convert_rich("<code>x = 1</code>")
    end

    test "multiple lines with empty line between paragraphs" do
      assert {:ok, [[{"one", []}], [], [{"two", []}]]} =
               HTML2Text.convert_rich("<p>one</p><p>two</p>")
    end

    test "width option wraps text" do
      assert {:ok, [[{"Hello", []}], [{"world", []}]]} =
               HTML2Text.convert_rich("<p>Hello world</p>", width: 5)
    end

    test "convert_rich! returns lines directly" do
      assert [[{"hello", []}]] =
               HTML2Text.convert_rich!("<p>hello</p>")
    end

    test "image annotation with alt text" do
      html = ~s(<img src="photo.jpg" alt="my photo">)

      assert {:ok, [[{"my photo", [{:image, "photo.jpg"}]}]]} =
               HTML2Text.convert_rich(html)
    end

    test "image with empty_img_mode: :filename" do
      html = ~s(<img src="photo.jpg">)

      assert {:ok, [[{"photo.jpg", [{:image, "photo.jpg"}]}]]} =
               HTML2Text.convert_rich(html, empty_img_mode: :filename)
    end

    test "preformat annotation" do
      assert {:ok, [[{"code", [{:preformat, false}]}], [{"block", [{:preformat, false}]}]]} =
               HTML2Text.convert_rich("<pre>code\nblock</pre>")
    end

    test "preformat continuation on wrapped lines" do
      {:ok, lines} = HTML2Text.convert_rich("<pre>a very long line</pre>", width: 10)
      [{_, first_ann}] = List.first(lines)
      [{_, cont_ann}] = Enum.at(lines, 1)
      assert first_ann == [{:preformat, false}]
      assert cont_ann == [{:preformat, true}]
    end

    test "table_borders: false" do
      html = "<table><tr><td>A</td><td>B</td></tr></table>"
      assert {:ok, [[{"A B", []}]]} = HTML2Text.convert_rich(html, table_borders: false)
    end

    test "raw mode" do
      html = "<table><tr><td>A</td><td>B</td></tr></table>"
      assert {:ok, [[{"A", []}], [{"B", []}]]} = HTML2Text.convert_rich(html, raw: true)
    end

    test "use_doc_css extracts inline colour" do
      html = ~s(<p style="color: red">red</p>)

      assert {:ok, [[{"red", [{:colour, {255, 0, 0}}]}]]} =
               HTML2Text.convert_rich(html, use_doc_css: true)
    end

    test "use_doc_css extracts class colour" do
      html =
        ~s(<html><head><style>.r { color: #ff0000; }</style></head><body><p class="r">red</p></body></html>)

      assert {:ok, [[{"red", [{:colour, {255, 0, 0}}]}]]} =
               HTML2Text.convert_rich(html, use_doc_css: true)
    end

    test "use_doc_css extracts background colour" do
      html = ~s(<p style="background-color: #ffff00">yellow</p>)

      assert {:ok, [[{"yellow", [{:bg_colour, {255, 255, 0}}]}]]} =
               HTML2Text.convert_rich(html, use_doc_css: true)
    end
  end

  describe "HTML2Text.HTML" do
    test "new/1 creates struct" do
      html = HTML2Text.HTML.new("<p>hello</p>")
      assert %HTML2Text.HTML{source: "<p>hello</p>"} = html
    end

    test "to_string returns original HTML" do
      html = HTML2Text.HTML.new("<p>hello</p>")
      assert to_string(html) == "<p>hello</p>"
    end

    test "inspect inline with ANSI" do
      colors = [string: :green]
      bright = IO.ANSI.bright()
      normal = IO.ANSI.normal()
      default = IO.ANSI.default_color()
      reset = IO.ANSI.reset()

      assert inspect(HTML2Text.HTML.new("<p>Hello <strong>world</strong></p>"),
               syntax_colors: colors
             ) ==
               "#HTML2Text.HTML<#{default}Hello #{bright}world#{normal}#{reset}>"
    end

    test "inspect link with ANSI" do
      colors = [string: :green]
      ul = IO.ANSI.underline()
      blue = IO.ANSI.blue()
      no_ul = IO.ANSI.no_underline()
      default = IO.ANSI.default_color()
      reset = IO.ANSI.reset()
      url = "https://example.com"
      open = "\e]8;id=#{:erlang.phash2(url)};#{url}\e\\"
      close = "\e]8;;\e\\"

      assert inspect(HTML2Text.HTML.new(~s(<a href="#{url}">click</a>)), syntax_colors: colors) ==
               "#HTML2Text.HTML<#{default}#{ul}#{blue}#{open}click#{close}#{no_ul}#{default}#{reset}>"
    end

    test "inspect emphasis with ANSI" do
      colors = [string: :green]
      italic = IO.ANSI.italic()
      no_italic = IO.ANSI.not_italic()
      default = IO.ANSI.default_color()
      reset = IO.ANSI.reset()

      assert inspect(HTML2Text.HTML.new("<em>italic</em>"), syntax_colors: colors) ==
               "#HTML2Text.HTML<#{default}#{italic}italic#{no_italic}#{reset}>"
    end

    test "inspect code with ANSI" do
      colors = [string: :green]
      cyan = IO.ANSI.cyan()
      default = IO.ANSI.default_color()
      reset = IO.ANSI.reset()

      assert inspect(HTML2Text.HTML.new("<code>x = 1</code>"), syntax_colors: colors) ==
               "#HTML2Text.HTML<#{default}#{cyan}x = 1#{default}#{reset}>"
    end

    test "inspect strikeout with ANSI" do
      colors = [string: :green]
      crossed = IO.ANSI.crossed_out()
      default = IO.ANSI.default_color()
      reset = IO.ANSI.reset()

      assert inspect(HTML2Text.HTML.new("<s>deleted</s>"), syntax_colors: colors) ==
               "#HTML2Text.HTML<#{default}#{crossed}d̶e̶l̶e̶t̶e̶d̶\e[29m#{reset}>"
    end

    test "inspect multiline without ANSI" do
      html = HTML2Text.HTML.new("<p>one</p><p>two</p>")

      assert inspect(html) ==
               """
               #HTML2Text.HTML<
                 one
                 \n\
                 two
               >\
               """
    end

    test "inspect CSS colour with true color RGB" do
      colors = [string: :green]
      default = IO.ANSI.default_color()
      reset = IO.ANSI.reset()

      html = HTML2Text.HTML.new(~s(<p style="color: #ff6600">orange</p>))

      assert inspect(html, syntax_colors: colors) ==
               "#HTML2Text.HTML<#{default}\e[38;2;255;102;0morange#{default}#{reset}>"
    end

    test "inspect CSS background colour with true color RGB" do
      colors = [string: :green]
      default = IO.ANSI.default_color()
      default_bg = IO.ANSI.default_background()
      reset = IO.ANSI.reset()

      html = HTML2Text.HTML.new(~s(<p style="background-color: #003300; color: #00cc00">ok</p>))

      assert inspect(html, syntax_colors: colors) ==
               "#HTML2Text.HTML<#{default}\e[38;2;0;204;0m\e[48;2;0;51;0mok#{default}#{default_bg}#{reset}>"
    end

    test "inspect without ANSI: inline" do
      html = HTML2Text.HTML.new("<p>Hello <strong>world</strong></p>")
      assert inspect(html, syntax_colors: []) == "#HTML2Text.HTML<Hello world>"
    end

    test "inspect without ANSI: multiline" do
      html = HTML2Text.HTML.new("<p>one</p><p>two</p>")

      assert inspect(html, syntax_colors: []) ==
               """
               #HTML2Text.HTML<
                 one
                 \n\
                 two
               >\
               """
    end

    test "inspect without ANSI: link" do
      html = HTML2Text.HTML.new(~s(<a href="https://example.com">click</a>))
      assert inspect(html, syntax_colors: []) == "#HTML2Text.HTML<click>"
    end

    test "inspect without ANSI: all annotations are plain text" do
      html = HTML2Text.HTML.new("<p><strong>bold</strong> <em>italic</em> <code>code</code></p>")
      assert inspect(html, syntax_colors: []) == "#HTML2Text.HTML<bold italic code>"
    end
  end
end
