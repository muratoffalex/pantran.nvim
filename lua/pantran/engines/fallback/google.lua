local curl = require("pantran.curl")
local config = require("pantran.config")

-- Implementation based on https://github.com/Animenosekai/translate
-- Other helpful resource: https://wiki.freepascal.org/Using_Google_Translate
local google = {
  name = "Google Translate (Web)",
  urls = {
    "https://translate.googleapis.com/translate_a/single?client=gtx&dt=t",
    "https://clients5.google.com/translate_a/t?client=dict-chrome-ex"
  },
  config = {
    default_source = "auto",
    default_target = "en",
    default_alternate_target = "ru"
  }
}
-- https://cloud.google.com/translate/docs/languages
local languages = {
  af = "Afrikaans",
  sq = "Albanian",
  am = "Amharic",
  ar = "Arabic",
  hy = "Armenian",
  az = "Azerbaijani",
  eu = "Basque",
  be = "Belarusian",
  bn = "Bengali",
  bs = "Bosnian",
  bg = "Bulgarian",
  ca = "Catalan",
  ceb = "Cebuano",
  ["zh-CN"] = "Chinese (Simplified)",
  ["zh-TW"] = "Chinese (Traditional)",
  co = "Corsican",
  hr = "Croatian",
  cs = "Czech",
  da = "Danish",
  nl = "Dutch",
  en = "English",
  eo = "Esperanto",
  et = "Estonian",
  fi = "Finnish",
  fr = "French",
  fy = "Frisian",
  gl = "Galician",
  ka = "Georgian",
  de = "German",
  el = "Greek",
  gu = "Gujarati",
  ht = "Haitian Creole",
  ha = "Hausa",
  haw = "Hawaiian",
  he = "Hebrew",
  hi = "Hindi",
  hmn = "Hmong",
  hu = "Hungarian",
  is = "Icelandic",
  ig = "Igbo",
  id = "Indonesian",
  ga = "Irish",
  it = "Italian",
  ja = "Japanese",
  jv = "Javanese",
  kn = "Kannada",
  kk = "Kazakh",
  km = "Khmer",
  rw = "Kinyarwanda",
  ko = "Korean",
  ku = "Kurdish",
  ky = "Kyrgyz",
  lo = "Lao",
  la = "Latin",
  lv = "Latvian",
  lt = "Lithuanian",
  lb = "Luxembourgish",
  mk = "Macedonian",
  mg = "Malagasy",
  ms = "Malay",
  ml = "Malayalam",
  mt = "Maltese",
  mi = "Maori",
  mr = "Marathi",
  mn = "Mongolian",
  my = "Myanmar (Burmese)",
  ne = "Nepali",
  no = "Norwegian",
  ny = "Nyanja (Chichewa)",
  ["or"] = "Odia (Oriya)",
  ps = "Pashto",
  fa = "Persian",
  pl = "Polish",
  pt = "Portuguese (Portugal, Brazil)",
  pa = "Punjabi",
  ro = "Romanian",
  ru = "Russian",
  sm = "Samoan",
  gd = "Scots Gaelic",
  sr = "Serbian",
  st = "Sesotho",
  sn = "Shona",
  sd = "Sindhi",
  si = "Sinhala (Sinhalese)",
  sk = "Slovak",
  sl = "Slovenian",
  so = "Somali",
  es = "Spanish",
  su = "Sundanese",
  sw = "Swahili",
  sv = "Swedish",
  tl = "Tagalog (Filipino)",
  tg = "Tajik",
  ta = "Tamil",
  tt = "Tatar",
  te = "Telugu",
  th = "Thai",
  tr = "Turkish",
  tk = "Turkmen",
  uk = "Ukrainian",
  ur = "Urdu",
  ug = "Uyghur",
  uz = "Uzbek",
  vi = "Vietnamese",
  cy = "Welsh",
  xh = "Xhosa",
  yi = "Yiddish",
  yo = "Yoruba",
  zu = "Zulu",
}

function google.languages()
  local langs = {
    source = vim.tbl_extend("error", {auto = "Auto"}, languages),
    target = languages
  }

  return langs
end

function google.switch(source, target)
  if source == "auto" then
    return source, target
  elseif target == google.config.default_target then
    return target, google.config.default_alternate_target
  elseif target == google.config.default_alternate_target then
    return target, google.config.default_target
  else
    return target, source
  end
end

function google.translate(text, source, target)
  local ok, translation
  source = source or google.config.default_source
  local selected_target = target
  
  -- Автоматический выбор целевого языка
  if source == "auto" then
    -- Сначала определяем исходный язык
    local detected
    for _, api in ipairs(google._apis) do
      ok, detected = pcall(api.post, api, nil, {
        q = text,
        sl = "auto",
        tl = google.config.default_target
      })
      if ok then
        if #detected == 1 then
          detected = detected[2]
        else
          detected = detected[3]
        end
        break
      end
    end
    
    if detected then
      -- Выбираем целевой язык на основе определенного исходного
      if detected == google.config.default_target then
        selected_target = google.config.default_alternate_target
      else
        selected_target = google.config.default_target
      end
    else
      selected_target = target or google.config.default_target
    end
  else
    selected_target = target or google.config.default_target
  end

  -- Основной код перевода
  for _, api in ipairs(google._apis) do
    ok, translation = pcall(api.post, api, nil, {
      q = text,
      sl = source,
      tl = selected_target
    })

    if ok then
      if #translation == 1 then -- clients5.google.com
        translation = vim.tbl_flatten(translation)
        return {
          text = translation[1],
          detected = translation[2],
          target = selected_target -- Важно: всегда возвращаем выбранный target
        }
      else -- translate.googleapis.com
        return {
          text = table.concat(vim.tbl_map(function(tbl) return tbl[1] end, translation[1])),
          detected = source == "auto" and translation[3] or nil,
          target = selected_target -- Важно: всегда возвращаем выбранный target
        }
      end
    end
  end

  -- Being here means every API endpoint failed
  error(translation, 0)
end

function google.detect(text)
  return google.translate(text, "auto").detected
end

function google.setup()
  google._apis = {}
  for _, url in ipairs(google.urls) do
    table.insert(google._apis, curl.new{
      url = url,
    })
  end
end

return config.apply(config.user.engines.google.fallback, google)
