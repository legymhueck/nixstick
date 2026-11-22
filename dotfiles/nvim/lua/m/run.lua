-- <leader>r…: run Python and Java files, preview and export Typst, Marp and
-- Markdown, with the same commands as the repo unterricht (README, _tools/).
local vscode = require("m.vscode")

local function term(cmd, cwd)
  Snacks.terminal.open(cmd, { cwd = cwd, auto_close = false, win = { position = "bottom", height = 0.3 } })
end

local function job(cmd, cwd, done)
  vim.notify(table.concat(cmd, " "))
  vim.system(
    cmd,
    { cwd = cwd, text = true },
    vim.schedule_wrap(function(res)
      if res.code ~= 0 then
        vim.notify((res.stderr ~= "" and res.stderr or res.stdout), vim.log.levels.ERROR)
      elseif done then
        vim.notify(done)
      end
    end)
  )
end

local function is_marp(buf)
  for _, line in ipairs(vim.api.nvim_buf_get_lines(buf, 0, 20, false)) do
    if line:match("^marp:%s*true") then
      return true
    end
  end
  return false
end

local function git_root(file)
  return vim.fs.root(file, ".git") or vim.fs.dirname(file)
end

-- Python: the .venv of the unit, started in the file's folder (as .vscode/tasks.json does).
local function run_python(file)
  local root = vim.fs.root(file, { "pyproject.toml", ".venv" })
  local venv = root and root .. "/.venv/bin/python"
  local python = venv and vim.uv.fs_stat(venv) and venv or "python3"
  term({ python, file }, vim.fs.dirname(file))
end

-- Java: compile the file and what it uses (-sourcepath) into .java-bin/ (git-ignored), then start it.
local function run_java(file, buf)
  local flat, root = vscode.settings(file)
  root = root or vim.fs.dirname(file)
  local pkg
  for _, line in ipairs(vim.api.nvim_buf_get_lines(buf, 0, 40, false)) do
    pkg = line:match("^%s*package%s+([%w_.]+)%s*;")
    if pkg then
      break
    end
  end
  local dir = vim.fs.dirname(file)
  local src = { pkg and dir:sub(1, #dir - #pkg - 1) or dir }
  for _, p in ipairs(flat["java.project.sourcePaths"] or {}) do
    table.insert(src, root .. "/" .. p)
  end
  local cp = {}
  for _, pattern in ipairs(flat["java.project.referencedLibraries"] or { "lib/**/*.jar" }) do
    vim.list_extend(cp, vim.fn.glob(root .. "/" .. pattern, false, true))
  end
  local out = root .. "/.java-bin"
  local main = (pkg and pkg .. "." or "") .. vim.fn.fnamemodify(file, ":t:r")
  local classpath = table.concat(vim.list_extend({ out }, cp), ":")
  local script = string.format(
    "javac -d %s -cp %s -sourcepath %s %s && java -cp %s %s",
    vim.fn.shellescape(out),
    vim.fn.shellescape(classpath),
    vim.fn.shellescape(table.concat(src, ":")),
    vim.fn.shellescape(file),
    vim.fn.shellescape(classpath),
    main
  )
  term({ "bash", "-c", script }, root) -- cwd = the .vscode folder, like VS Code
end

local function run()
  local buf, file = 0, vim.api.nvim_buf_get_name(0)
  vim.cmd.update()
  local ft = vim.bo.filetype
  if ft == "python" then
    run_python(file)
  elseif ft == "java" then
    run_java(file, buf)
  else
    vim.notify("Nothing to run for " .. ft, vim.log.levels.WARN)
  end
end

local function preview()
  local file = vim.api.nvim_buf_get_name(0)
  if vim.bo.filetype == "typst" then
    vim.cmd("TypstPreviewToggle")
  elseif vim.bo.filetype == "markdown" and is_marp(0) then
    vim.system({ "marp", "--preview", "--html", "--allow-local-files", file }, { cwd = vim.fs.dirname(file) })
  elseif vim.bo.filetype == "markdown" then
    vim.cmd("RenderMarkdown toggle")
  end
end

-- Rendered PDFs always go to out/ next to the source (git-ignored), like
-- _tools/typst-bauen.py in unterricht and the main repo nixos.
local function out_pdf(file)
  local out = vim.fs.joinpath(vim.fs.dirname(file), "out")
  vim.fn.mkdir(out, "p")
  return vim.fs.joinpath(out, vim.fn.fnamemodify(file, ":t:r") .. ".pdf")
end

-- PDF: typst compile --root <repo> | marp --pdf | _tools/pdf-bauen.sh <folder> (all into out/)
local function export_pdf()
  vim.cmd.update()
  local file = vim.api.nvim_buf_get_name(0)
  local root = git_root(file)
  if vim.bo.filetype == "typst" then
    job({ "typst", "compile", "--root", root, file, out_pdf(file) }, root, "PDF written to out/")
  elseif is_marp(0) then
    job(
      { "marp", "--pdf", "--html", "--allow-local-files", file, "-o", out_pdf(file) },
      vim.fs.dirname(file),
      "PDF written to out/"
    )
  elseif vim.bo.filetype == "markdown" then
    term({ "bash", root .. "/_tools/pdf-bauen.sh", vim.fs.dirname(file) }, root)
  end
end

-- HTML: marp --html | _tools/html-bauen.sh <folder> (student HTML for Logineo)
local function export_html()
  vim.cmd.update()
  local file = vim.api.nvim_buf_get_name(0)
  local root = git_root(file)
  if is_marp(0) then
    job({ "marp", "--html", file }, vim.fs.dirname(file), "HTML written next to the file")
  elseif vim.bo.filetype == "markdown" then
    term({ "bash", root .. "/_tools/html-bauen.sh", vim.fs.dirname(file) }, root)
  end
end

local function export_pptx()
  vim.cmd.update()
  local file = vim.api.nvim_buf_get_name(0)
  job(
    { "marp", "--pptx", "--html", "--allow-local-files", file },
    vim.fs.dirname(file),
    "PPTX written next to the file"
  )
end

-- zathura, detached: it outlives Neovim and reloads the PDF when it changes
-- (export again with <leader>re and the open window updates).
local function zathura(pdf)
  if not vim.uv.fs_stat(pdf) then
    vim.notify("No PDF yet: " .. pdf .. " (export with <leader>re)", vim.log.levels.WARN)
    return false
  end
  vim.system({ "zathura", pdf }, { detach = true })
  return true
end

-- The PDF that <leader>re writes for this file: out/<name>.pdf.
local function open_pdf()
  local file = vim.api.nvim_buf_get_name(0)
  zathura(vim.fs.joinpath(vim.fs.dirname(file), "out", vim.fn.fnamemodify(file, ":t:r") .. ".pdf"))
end

-- Opening a PDF (nvim file.pdf, picker, explorer) shows it in zathura instead
-- of loading the binary into a buffer.
vim.api.nvim_create_autocmd("BufReadCmd", {
  pattern = "*.pdf",
  callback = function(ev)
    local pdf = vim.api.nvim_buf_get_name(ev.buf)
    local msg = zathura(pdf) and "Opened in zathura: " or "No such PDF: "
    vim.api.nvim_buf_set_lines(ev.buf, 0, -1, false, { msg .. pdf })
    vim.bo[ev.buf].buftype = "nofile"
    vim.bo[ev.buf].bufhidden = "wipe"
    vim.bo[ev.buf].modifiable = false
  end,
})

local map = vim.keymap.set
map("n", "<leader>ro", open_pdf, { desc = "Open exported PDF (zathura)" })
map("n", "<leader>rr", run, { desc = "Run file (Python / Java)" })
map("n", "<leader>rp", preview, { desc = "Preview (Typst / Marp / Markdown)" })
map("n", "<leader>re", export_pdf, { desc = "Export PDF" })
map("n", "<leader>rh", export_html, { desc = "Export HTML" })
map("n", "<leader>rx", export_pptx, { desc = "Export PPTX (Marp)" })
