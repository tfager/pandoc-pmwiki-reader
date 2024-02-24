-- Pandoc reader for PMWiki format: https://www.pmwiki.org/wiki/PmWiki/MarkupMasterIndex
-- Using LPeg: https://www.inf.puc-rio.br/~roberto/lpeg/
-- Inspired by https://pandoc.org/custom-readers.html
local P, S, R, Cf, Cc, Ct, V, Cs, Cg, Cb, B, C, Cmt =
  lpeg.P, lpeg.S, lpeg.R, lpeg.Cf, lpeg.Cc, lpeg.Ct, lpeg.V,
  lpeg.Cs, lpeg.Cg, lpeg.Cb, lpeg.B, lpeg.C, lpeg.Cmt

local whitespacechar = S(" \t\r\n")
local specialchar = S("/*~[]\\{}|")
local wordchar = (1 - (whitespacechar + specialchar))
local spacechar = S(" \t")
local newline = P"\r"^-1 * P"\n"
local blankline = spacechar^0 * newline
local endline = newline * #-blankline
local endequals = spacechar^0 * P"="^0 * spacechar^0 * newline
local cellsep = spacechar^0 * P"|"
local apostrophe = string.char(39)
local doubleApo = P(apostrophe) * P(apostrophe)
local fenced = '```\n%s\n```\n'
local cellsep = spacechar^0 * P"||"

local function trim(s)
   return (s:gsub("^%s*(.-)%s*$", "%1"))
end

local function ListItem(lev, ch)
  local start
  if ch == nil then
    start = S"*#"
  else
    start = P(ch)
  end
  local subitem = function(c)
    if lev < 6 then
    return ListItem(lev + 1, c)
    else
    return (1 - 1) -- fails
    end
  end
  local parser = spacechar^0
              * start^lev
              * #(- start)
              * spacechar^0
              * Ct((V"Inline" - (newline * spacechar^0 * S"*#"))^0)
              * newline
              * (Ct(subitem("*")^1) / pandoc.BulletList
                    +
                    Ct(subitem("#")^1) / pandoc.OrderedList
                    +
                    Cc(nil))
              / function (ils, sublist)
                    return { pandoc.Plain(ils), sublist }
                    end
  return parser
end

-- Grammar
G = P{ "Doc",
  Doc = Ct(V"Block"^0)
      / pandoc.Pandoc ;
  Block = blankline^0
        * ( V"IndentedBlock"
          + V"Header"
          + V"HorizontalRule"
          + V"CodeBlock"
          + V"List"
          + V"Table"
          + V"Para"
          ) ;
  IndentedBlock = C((spacechar^1
                    * (1 - newline)^1
                    * newline)^1
                    )
                    / function(text)
                        block = pandoc.RawBlock('markdown', fenced:format(text)) 
                        return block
                    end;
  CodeBlock = P"[@"
          * blankline
          * C((1 - (newline * P"@]"))^0)
          * newline
          * P"@]"
          / function(text)
            block = pandoc.RawBlock('markdown', fenced:format(text)) 
            return block
          end;
  List = V"BulletList"
        + V"OrderedList" ;
  BulletList = Ct(ListItem(1,'*')^1)
              / pandoc.BulletList ;
  OrderedList = Ct(ListItem(1,'#')^1)
              / pandoc.OrderedList ;
  Table = V"TableProperties"
        * (V"TableHeader" + Cc{})
        * Ct(V"TableRow"^1)
        / function(headrow, bodyrows)
          local numcolumns = #(bodyrows[1])
          local aligns = {}
          local widths = {}
          for i = 1,numcolumns do
            aligns[i] = pandoc.AlignDefault
            widths[i] = 0
          end
          return pandoc.utils.from_simple_table(
            pandoc.SimpleTable({}, aligns, widths, headrow, bodyrows))
        end ;
  TableProperties = cellsep
                  * spacechar^0
                  * P("border=")
                  * (1 - newline)^1
                  * newline;
  TableHeader = Ct(V"HeaderCell"^1)
              * cellsep^-1
              * spacechar^0
              * newline ;
  TableRow   = Ct(V"BodyCell"^1)
              * cellsep^-1
              * spacechar^0
              * newline ;
  HeaderCell = cellsep
              * P"!"^-1
              * spacechar^0
              * Ct((V"Inline" - (newline + cellsep))^0)
              / function(ils) return { pandoc.Plain(ils) } end ;
  BodyCell   = cellsep
              * spacechar^0
              * Ct((V"Inline" - (newline + cellsep))^0)
              / function(ils) return { pandoc.Plain(ils) } end ;
  Para = Ct(V"Inline"^1)
       * newline
       / pandoc.Para ;
  HorizontalRule = spacechar^0
                 * P"----"
                 * spacechar^0
                 * newline
                 / pandoc.HorizontalRule;
  Header = (P("!")^1 / string.len)
         * spacechar^0
         * Ct((V"Inline" - endequals)^1)
         * endequals
         / pandoc.Header;
  Inline = V"Link"
         + V"Url"
         + V"Code"
         + V"Bold"
         + V"Emph" 
         + V"Str"
         + V"Space"
         + V"Special";
  Link = P"[["
         * C((1 - (P"]]" + P"|"))^0)
         * (P"|" * Ct((V"Inline" - P"]]")^1))^-1
         * P"]]"
         / function(url, desc)
             local txt = desc or {pandoc.Str(url)}
             return pandoc.Link(txt, url)
           end;
  Url = C(
          P"http"
          * P"s"^-1
          * P"://"
          * (1 - whitespacechar)^1
          )
          / function(url)
              return pandoc.Link(url, url)
          end;
  Code = P'@@'
         * C((1 - P'@@')^0)
         * P'@@'
         / trim / pandoc.Code;
  Emph = P"''"
         * C(((wordchar + whitespacechar) - P"''")^1)
         * P"''"
         / pandoc.Emph;
  Bold = P"'''"
       * C(((wordchar + whitespacechar) - P"'''")^1)
       * P"'''"
       / pandoc.Strong;
  Str = wordchar^1
      / pandoc.Str;
  Special = specialchar
          / pandoc.Str;
  Space = spacechar^1
        / pandoc.Space ;
}

function Reader(input, reader_options)
    return lpeg.match(G, tostring(input))
end
