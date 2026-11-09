-- Listes de documents d'un cours.
--
-- Dans un bloc « ::: documents » :
--
-- 1. une liste à puces de liens devient une grille de cartes cliquables
--    (icône et libellé selon le type de fichier, taille, description) :
--
--      ::: documents
--      - [Slides du cours](documents/01/slides.pdf) Description facultative
--      - [Notebook du TP](documents/01/tp.ipynb)
--      - [Corrigé](documents/01/solution.py){.solution}
--      :::
--
-- 2. dans un tableau (une ligne par chapitre, une colonne par sorte de
--    document), chaque lien devient un badge compact (icône + texte ;
--    type et taille au survol) ; plusieurs liens par cellule possibles :
--
--      ::: documents
--      | Chapitre              | Cours           | Exercices / TP             | Corrigé                |
--      |-----------------------|-----------------|----------------------------|------------------------|
--      | 1.1 Recherche aveugle | [PDF](c11.pdf)  | [TP1 Taquin](tp1.ipynb)    | [solution](tp1-sol.py) |
--      :::
--
-- {.hidden} sur un lien le masque : ni carte ni lien dans la page, et le
-- fichier n'est pas publié (Quarto ne copie dans _site/ que les fichiers liés).
-- Un fichier local absent est masqué automatiquement : il suffit de déposer
-- le fichier et de relancer le rendu pour qu'il apparaisse. Option dans
-- _quarto.yml (ou l'en-tête d'une page) :
--
--   documents:
--     missing: hide    # (défaut) document absent masqué
--     missing: soon    # affiché grisé « bientôt disponible », sans lien
--
-- {.soon} sur un lien force « bientôt disponible » pour ce document seul.
-- Les liens externes (https://...) ne sont pas vérifiés.
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

-- Document dont le fichier est absent : "hide" (masqué) ou "soon"
-- (« bientôt disponible ») ; lu dans `documents.missing` par Meta
local missing_mode = "hide"
-- Fichiers absents masqués, signalés en une ligne à la fin du rendu
local hidden_missing = {}

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

-- Analyse d'un lien vers un document. Renvoie nil si le document est masqué :
-- lien marqué {.hidden}, ou fichier local absent (option documents.missing:
-- hide, sauf {.soon}). Rien n'est alors écrit dans la page, et le fichier
-- n'est pas publié dans _site/ (Quarto ne copie que les fichiers liés).
local function resolve(link)
  if link.classes:includes("hidden") then
    return nil
  end
  local target = link.target
  local kind = file_type(target)
  local doc = { target = target, kind = kind, info = TYPES[kind], missing = false }
  if kind ~= "url" then
    doc.size = file_size(target)
    if not doc.size then
      if missing_mode == "hide" and not link.classes:includes("soon") then
        table.insert(hidden_missing, target)
        return nil
      end
      doc.missing = true
      quarto.log.warning("documents : fichier introuvable « " .. target .. " » (affiché comme bientôt disponible)")
    end
  end

  doc.classes = { "hearc-doc-" .. kind }
  for _, c in ipairs(link.classes) do
    table.insert(doc.classes, c)
  end
  if doc.missing then
    table.insert(doc.classes, "hearc-doc-missing")
  end

  -- Balise et attributs : lien, ou simple texte si le fichier est absent
  doc.tag, doc.attrs = "a", ' href="' .. html_escape(target) .. '"'
  if doc.missing then
    doc.tag, doc.attrs = "span", ""
  elseif kind == "url" or kind == "pdf" or kind == "html" then
    doc.attrs = doc.attrs .. ' target="_blank" rel="noopener"'
  elseif DOWNLOAD[kind] then
    doc.attrs = doc.attrs .. " download"
  end

  -- « PDF · 237 ko » ou « bientôt disponible »
  if doc.missing then
    doc.meta = "bientôt disponible"
  else
    doc.meta = doc.info.label .. (doc.size and (" · " .. doc.size) or "")
  end
  return doc
end

-- Une puce de la liste -> carte HTML ("" si masquée, nil si la puce ne
-- commence pas par un lien)
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

  local doc = resolve(link)
  if not doc then
    return ""
  end

  local description = inlines_to_html(trim_description(inlines))
  -- blocs suivants de la puce (paragraphes, sous-listes) : ajoutés à la description
  for i = 2, #item do
    description = description .. pandoc.write(pandoc.Pandoc({ item[i] }), "html")
  end

  local action = ""
  if not doc.missing then
    local action_icon = DOWNLOAD[doc.kind] and "bi-download" or "bi-box-arrow-up-right"
    action = '<i class="bi ' .. action_icon .. ' hearc-doc-action" aria-hidden="true"></i>'
  end

  local tag = doc.missing and "div" or doc.tag
  return table.concat({
    "<li><", tag, ' class="hearc-doc ', table.concat(doc.classes, " "), '"', doc.attrs, ">",
    '<i class="bi ', doc.info.icon, ' hearc-doc-icon" aria-hidden="true"></i>',
    '<span class="hearc-doc-body">',
    '<span class="hearc-doc-title">', inlines_to_html(link.content), "</span>",
    description ~= "" and ('<span class="hearc-doc-desc">' .. description .. "</span>") or "",
    '<span class="hearc-doc-meta">', doc.meta, "</span>",
    "</span>", action,
    "</", tag, "></li>",
  })
end

-- Un lien dans une cellule de tableau -> badge compact (icône + texte),
-- détails (type, taille) au survol. Lien masqué : rien.
local function document_chip(link)
  local doc = resolve(link)
  if not doc then
    return pandoc.Inlines({})
  end
  return pandoc.RawInline("html", table.concat({
    "<", doc.tag, ' class="hearc-chip ', table.concat(doc.classes, " "), '"', doc.attrs,
    ' title="', html_escape(doc.meta), '">',
    '<i class="bi ', doc.info.icon, '" aria-hidden="true"></i>',
    inlines_to_html(link.content),
    "</", doc.tag, ">",
  }))
end

-- Tableau : chaque lien devient un badge ; plusieurs liens d'une même cellule
-- sont placés côte à côte
local function documents_table(tbl)
  return tbl:walk({
    Link = document_chip,
    -- espaces restés seuls entre badges masqués ou en fin de cellule
    Plain = function(plain)
      local content = plain.content
      while #content > 0 and (content[#content].t == "Space" or content[#content].t == "SoftBreak") do
        content:remove(#content)
      end
      plain.content = content
      return plain
    end,
  })
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
        local card = document_card(item)
        if card then
          table.insert(cards, card)
        else
          quarto.log.warning("documents : chaque puce doit commencer par un lien [titre](fichier)")
        end
      end
      result:insert(pandoc.RawBlock("html",
        '<ul class="hearc-docs">' .. table.concat(cards) .. "</ul>"))
    elseif block.t == "Table" then
      block.classes:insert("hearc-docs-table")
      -- largeurs calculées par le navigateur, et non d'après la longueur des
      -- lignes du tableau source (longues à cause des chemins des fichiers)
      for i, colspec in ipairs(block.colspecs) do
        block.colspecs[i] = { colspec[1], nil }
      end
      result:insert(documents_table(block))
    else
      result:insert(block)
    end
  end
  div.classes = pandoc.List({ "hearc-documents" })
  div.content = result
  return div
end


-- Une seule ligne pour tous les documents masqués faute de fichier
local function Pandoc(doc)
  if #hidden_missing > 0 then
    quarto.log.warning("documents : masqués car fichier absent (" .. #hidden_missing .. ") : "
      .. table.concat(hidden_missing, ", "))
  end
end

-- Option documents.missing ; sous-titre par défaut : « Nom du cours · Classe · Année »
-- (sans le nom du cours s'il est déjà le titre de la page)
local function Meta(meta)
  local options = meta.documents
  if type(options) == "table" and options.missing then
    local mode = pandoc.utils.stringify(options.missing)
    if mode == "hide" or mode == "soon" then
      missing_mode = mode
    else
      quarto.log.warning("documents.missing : « " .. mode .. " » inconnu (hide ou soon)")
    end
  end

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
  { Pandoc = Pandoc },
}
