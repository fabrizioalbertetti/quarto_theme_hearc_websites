-- Listes de documents d'un cours.
--
-- Un bloc « ::: documents » contenant une liste à puces de liens :
--
--   ::: documents
--   - [Slides du cours](documents/01/slides.pdf) Description facultative
--   - [Notebook du TP](documents/01/tp.ipynb)
--   - [Corrigé](documents/01/solution.py){.solution}
--   - [Corrigé du TP 2](documents/01/tp2.ipynb){.hidden}
--   :::
--
-- {.hidden} masque la puce : ni carte ni lien dans la page, et le fichier
-- n'est pas publié (Quarto ne copie dans _site/ que les fichiers liés).
--
-- devient une liste de cartes cliquables : icône et libellé selon le type de
-- fichier (PDF, notebook, Python...), taille du fichier, description.
-- Un fichier absent est affiché « bientôt disponible » (sans lien) et signalé
-- par un avertissement au rendu : on peut donc annoncer un document avant
-- de le publier.
--
-- Transmet aussi `course` (_quarto.yml) au sous-titre de la page si celui-ci
-- n'est pas donné : « Nom du cours · Classe · Année ».

-- Types de fichiers : icône Bootstrap Icons (incluses dans Quarto) et libellé
local TYPES = {
  pdf   = { icon = "bi-file-earmark-pdf", label = "PDF" },
  ipynb = { icon = "bi-journal-code",     label = "Notebook" },
  py    = { icon = "bi-filetype-py",      label = "Python" },
  zip   = { icon = "bi-file-earmark-zip", label = "Archive" },
  csv   = { icon = "bi-filetype-csv",     label = "Données" },
  html  = { icon = "bi-filetype-html",    label = "Page web" },
  url   = { icon = "bi-box-arrow-up-right", label = "Lien" },
  other = { icon = "bi-file-earmark",     label = "Fichier" },
}

-- Fichiers proposés au téléchargement (les autres s'ouvrent dans le navigateur)
local DOWNLOAD = { ipynb = true, py = true, zip = true, csv = true }

local function html_escape(s)
  return (s:gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;"):gsub('"', "&quot;"))
end

local function inlines_to_html(inlines)
  if #inlines == 0 then
    return ""
  end
  local html = pandoc.write(pandoc.Pandoc({ pandoc.Plain(inlines) }), "html")
  return (html:gsub("%s+$", ""))
end

local function file_type(target)
  if target:match("^%a[%w+.-]*://") then
    return "url"
  end
  local ext = target:gsub("[?#].*$", ""):match("%.([%w]+)$")
  ext = ext and ext:lower() or ""
  return TYPES[ext] and ext or "other"
end

-- Taille lisible (« 240 ko »), ou nil si le fichier n'existe pas
local function file_size(target)
  local dir = "."
  if quarto and quarto.doc and quarto.doc.input_file then
    dir = pandoc.path.directory(quarto.doc.input_file)
  end
  local path = pandoc.path.join({ dir, (target:gsub("[?#].*$", "")) })
  local f = io.open(path, "rb")
  if not f then
    return nil
  end
  local size = f:seek("end")
  f:close()
  if size < 1024 then
    return size .. " o"
  elseif size < 1024 * 1024 then
    return string.format("%.0f ko", size / 1024)
  end
  return (string.format("%.1f Mo", size / 1024 / 1024):gsub("%.", ","))
end

-- Retire les séparateurs en tête de la description (« — », « : », « - »)
local function trim_description(inlines)
  while #inlines > 0 do
    local first = inlines[1]
    if first.t == "Space" or first.t == "SoftBreak" or first.t == "LineBreak"
        or (first.t == "Str" and first.text:match("^[%-–—:]+$")) then
      inlines:remove(1)
    else
      break
    end
  end
  return inlines
end

-- Une puce de la liste -> carte HTML (nil si la puce ne commence pas par un lien)
local function document_card(item)
  if #item == 0 or (item[1].t ~= "Plain" and item[1].t ~= "Para") then
    return nil
  end
  local inlines = pandoc.Inlines(item[1].content)
  local link = inlines[1]
  if not link or link.t ~= "Link" then
    return nil
  end
  inlines:remove(1)

  local target = link.target
  local kind = file_type(target)
  local info = TYPES[kind]
  local description = inlines_to_html(trim_description(inlines))
  -- blocs suivants de la puce (paragraphes, sous-listes) : ajoutés à la description
  for i = 2, #item do
    description = description .. pandoc.write(pandoc.Pandoc({ item[i] }), "html")
  end

  local meta = { info.label }
  local missing = false
  if kind ~= "url" then
    local size = file_size(target)
    if size then
      table.insert(meta, size)
    else
      missing = true
      quarto.log.warning("documents : fichier introuvable « " .. target .. " » (affiché comme bientôt disponible)")
    end
  end

  local classes = { "hearc-doc", "hearc-doc-" .. kind }
  for _, c in ipairs(link.classes) do
    table.insert(classes, c)
  end
  if missing then
    table.insert(classes, "hearc-doc-missing")
  end

  local tag, attrs = "a", ' href="' .. html_escape(target) .. '"'
  if missing then
    tag, attrs = "div", ""
    meta = { "bientôt disponible" }
  elseif kind == "url" or kind == "pdf" or kind == "html" then
    attrs = attrs .. ' target="_blank" rel="noopener"'
  elseif DOWNLOAD[kind] then
    attrs = attrs .. ' download'
  end

  local action = ""
  if not missing then
    local action_icon = DOWNLOAD[kind] and "bi-download" or "bi-box-arrow-up-right"
    action = '<i class="bi ' .. action_icon .. ' hearc-doc-action" aria-hidden="true"></i>'
  end

  return table.concat({
    "<li><", tag, ' class="', table.concat(classes, " "), '"', attrs, ">",
    '<i class="bi ', info.icon, ' hearc-doc-icon" aria-hidden="true"></i>',
    '<span class="hearc-doc-body">',
    '<span class="hearc-doc-title">', inlines_to_html(link.content), "</span>",
    description ~= "" and ('<span class="hearc-doc-desc">' .. description .. "</span>") or "",
    '<span class="hearc-doc-meta">', table.concat(meta, " · "), "</span>",
    "</span>", action,
    "</", tag, "></li>",
  })
end

-- Puce masquée : lien marqué {.hidden}. Ni la carte ni le lien ne sont
-- écrits dans la page, et le fichier n'est donc pas publié dans _site/
local function is_hidden(item)
  local first = item[1]
  if not first or (first.t ~= "Plain" and first.t ~= "Para") then
    return false
  end
  local link = first.content[1]
  return link ~= nil and link.t == "Link" and link.classes:includes("hidden")
end

local function Div(div)
  if not div.classes:includes("documents") or not quarto.doc.is_format("html") then
    return nil
  end
  local result = pandoc.Blocks({})
  for _, block in ipairs(div.content) do
    if block.t == "BulletList" then
      local cards = {}
      for _, item in ipairs(block.content) do
        local card = nil
        if is_hidden(item) then
          card = ""
        else
          card = document_card(item)
        end
        if card then
          table.insert(cards, card)
        else
          quarto.log.warning("documents : chaque puce doit commencer par un lien [titre](fichier)")
        end
      end
      result:insert(pandoc.RawBlock("html",
        '<ul class="hearc-docs">' .. table.concat(cards) .. "</ul>"))
    else
      result:insert(block)
    end
  end
  div.classes = pandoc.List({ "hearc-documents" })
  div.content = result
  return div
end

-- Sous-titre par défaut : « Nom du cours · Classe · Année »
-- (sans le nom du cours s'il est déjà le titre de la page)
local function Meta(meta)
  local course = meta.course
  if meta.subtitle or type(course) ~= "table" then
    return nil
  end
  local title = meta.title and pandoc.utils.stringify(meta.title) or ""
  local parts = {}
  for _, key in ipairs({ "name", "class", "year" }) do
    if course[key] then
      local s = pandoc.utils.stringify(course[key])
      if s ~= "" and not (key == "name" and s == title) then
        table.insert(parts, s)
      end
    end
  end
  if #parts > 0 then
    meta.subtitle = pandoc.Inlines(table.concat(parts, " · "))
    return meta
  end
end

return {
  { Meta = Meta },
  { Div = Div },
}
