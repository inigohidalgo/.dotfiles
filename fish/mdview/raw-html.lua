-- mdview: render raw HTML as the literal text it was written as.
--
-- This is what `gfm-raw_html` should do, but pandoc's gfm reader ignores the
-- toggle (still true in 3.10), so a prose placeholder like
-- "Landed on main: <title> (<sha7>)" reaches the browser as markup. Unknown
-- names (<sha7>, <pid>) render as empty elements and vanish; worse, <title> is
-- an RCDATA element, so the browser swallows everything up to the next
-- </title> -- the rest of the document silently disappears while the HTML file
-- itself is complete.
--
-- Trade-off: real HTML in a document (<details>, <kbd>, <br>) shows as text too.

function RawInline(el)
  if el.format == 'html' then
    return pandoc.Str(el.text)
  end
end

function RawBlock(el)
  if el.format == 'html' then
    -- keep it a paragraph of literal text, one source line per line
    local inlines = pandoc.Inlines{}
    for line in el.text:gsub('%s+$', ''):gmatch('[^\n]+') do
      if #inlines > 0 then inlines:insert(pandoc.SoftBreak()) end
      inlines:insert(pandoc.Str(line))
    end
    return pandoc.Para(inlines)
  end
end
