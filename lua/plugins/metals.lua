-- LazyVim scala extra'sı <leader>mc/me/mh'yi global tanımlıyor; bu da her buffer'da
-- <leader>m (multicursor) için which-key'i ek tuş beklemeye sokuyordu. Sadece Scala/sbt'de olsunlar.
return {
  "scalameta/nvim-metals",
  keys = function(_, keys)
    for _, key in ipairs(keys) do
      key.ft = { "scala", "sbt" }
    end
    return keys
  end,
}
