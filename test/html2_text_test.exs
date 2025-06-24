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
  end
end
