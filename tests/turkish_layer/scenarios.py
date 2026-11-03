"""Türkçe Q klavyede kullanıcının gerçekten bastığı tuşlar → beklenen davranış = referans Neovim'deki davranış.

Tuş dizileri fiziksel tuşun Türkçe Q'da ürettiği karakterle yazılır: ı=i, i=', ş=;, ğ=[, ü=], ö=,,
ç=., İ=", Ş=:, Ğ={, Ü=}, Ö=<, Ç=>, .=/, :=?, ,=\\, ;=|.
"rpc" anahtarı: tuşlar tmux yerine nvim_input ile gider (GUI/Neovide yolu; Ctrl+TR chord'ları için).
"""

TEXT = ["foo bar baz", "one two three", "x y z", "a b c", "q w e"]
TR = "Türkçe ıişğüöç İŞĞÜÖÇ"


def k(s):
    """'ı Z <Esc>' gibi boşlukla ayrılmış token dizisi."""
    return s.split(" ")


SCENARIOS = [
    # --- normal mod, tek TR tuş ---------------------------------------------------------
    dict(name="ı insert", keys=k("ı Z <Esc>"), lines=TEXT),
    dict(name="ı sonra ASCII metin", keys=k("ı test <Esc>"), lines=TEXT),
    dict(name="i = ' mark", keys=k("m a g g i a"), lines=TEXT, cursor=[3, 2]),
    dict(name="ii = '' geri", keys=k("G g g i i"), lines=TEXT, cursor=[3, 0]),
    dict(name="ş = ; tekrar", keys=k("f b ş"), lines=["a b c b d b"]),
    dict(name="ö = , geri", keys=k("f b ş ş ö"), lines=["a b c b d b"]),
    dict(name="ç = . repeat", keys=k("x ç"), lines=TEXT),
    dict(name="2ç count repeat", keys=k("x 2 ç"), lines=TEXT),
    dict(name="üp = ]p", keys=k("y y ü p"), lines=["  a", "b"], cursor=[1, 0]),
    dict(name="üü = ]]", keys=k("ü ü"), lines=["a", "{", "b", "}", "{", "c"]),
    dict(name="ğğ = [[", keys=k("ğ ğ"), lines=["{", "a", "{", "b"], cursor=[4, 0]),
    dict(name="Ü = }", keys=k("Ü"), lines=["a", "b", "", "c"]),
    dict(name="Ğ = {", keys=k("Ğ"), lines=["a", "", "b", "c"], cursor=[4, 0]),
    dict(name="ÇÇ = >>", keys=k("Ç Ç"), lines=TEXT),
    dict(name="ÖÖ = <<", keys=k("Ö Ö"), lines=["    foo"]),
    dict(name="İay = \"ay", keys=k("İ a y y j İ a p"), lines=TEXT, regs="a"),
    dict(name="Ş = : cmdline", keys=k("Ş s/foo/Z/ <CR>"), lines=TEXT),
    dict(name=". = / arama", keys=k(". baz <CR>"), lines=TEXT),
    dict(name=". arama TR metin", keys=k(". ğüş <CR>"), lines=["a", "x ğüş y"]),
    dict(name=". arama ı i", keys=k(". ıi <CR>"), lines=["a", "x ıi y"]),
    dict(name=": = ? geri arama", keys=k(": foo <CR>"), lines=TEXT, cursor=[3, 0]),
    dict(name="5; = 5|", keys=k("5 ;"), lines=TEXT),
    dict(name=", = \\", keys=k(", x"), lines=TEXT),
    dict(name="gı = gi", keys=k("A X <Esc> g g g ı Y <Esc>"), lines=TEXT),
    dict(name="gş = g;", keys=k("x G g ş"), lines=TEXT),
    dict(name="3x count", keys=k("3 x"), lines=TEXT),
    dict(name="3x sonra ç tekrar", keys=k("3 x ç"), lines=TEXT),
    dict(name="3s count", keys=k("3 s Z <Esc>"), lines=TEXT),
    dict(name="3dd count", keys=k("3 d d"), lines=TEXT),
    dict(name="d3w count", keys=k("d 3 w"), lines=TEXT),
    # --- gerçek ASCII tuşlar TR karşılıklarıyla karışmasın (çakışma) ------------------------
    dict(name="ASCII i tuşu (TR') mark", keys=k("m b G i b"), lines=TEXT, cursor=[2, 0]),
    dict(name="ASCII . tuşu (TR/) arama", keys=k(". two <CR> ç"), lines=TEXT),
    # --- operatör + textobject ----------------------------------------------------------
    dict(name="dıw", keys=k("d ı w"), lines=TEXT, cursor=[1, 5]),
    dict(name="cıw", keys=k("c ı w Z <Esc>"), lines=TEXT, cursor=[1, 5]),
    dict(name="yıw", keys=k("y ı w"), lines=TEXT, cursor=[1, 5], regs='"'),
    dict(name="yıİ = yi\"", keys=k("y ı İ"), lines=['say "hello" ok'], cursor=[1, 6], regs='"'),
    dict(name="dıİ", keys=k("d ı İ"), lines=['say "hello" ok'], cursor=[1, 6]),
    dict(name="caİ", keys=k("c a İ X <Esc>"), lines=['say "hello" ok'], cursor=[1, 6]),
    dict(name="yığ = yi[", keys=k("y ı ğ"), lines=["a[bcd]e"], cursor=[1, 3], regs='"'),
    dict(name="dıü = di]", keys=k("d ı ü"), lines=["a[bcd]e"], cursor=[1, 3]),
    dict(name="dıÜ = di}", keys=k("d ı Ü"), lines=["f{xyz}"], cursor=[1, 3]),
    dict(name="dıĞ = di{", keys=k("d ı Ğ"), lines=["f{xyz}"], cursor=[1, 3]),
    dict(name="dıÖ = di<", keys=k("d ı Ö"), lines=["<abc>"], cursor=[1, 2]),
    dict(name="yıi = yi'", keys=k("y ı i"), lines=["x 'q' y"], cursor=[1, 3], regs='"'),
    dict(name="dıp", keys=k("d ı p"), lines=["a", "b", "", "c"]),
    dict(name="vıvd = viv PascalCase", keys=k("v ı v d"), lines=["PascalCase"]),
    dict(name="dıv", keys=k("d ı v"), lines=["PascalCase"], cursor=[1, 7]),
    dict(name="vıwd", keys=k("v ı w d"), lines=TEXT, cursor=[1, 5]),
    dict(name="vıİd", keys=k("v ı İ d"), lines=['say "hello" ok'], cursor=[1, 6]),
    dict(name="Vjd", keys=k("V j d"), lines=TEXT),
    dict(name="VÇ visual indent", keys=k("V j Ç"), lines=TEXT),
    dict(name="v İby visual register", keys=k("v e İ b y"), lines=TEXT, regs="b"),
    dict(name="üv subword", keys=k("ü v"), lines=["fooBarBaz"]),
    dict(name="ğv subword", keys=k("ğ v"), lines=["fooBarBaz"], cursor=[1, 7]),
    dict(name="düv", keys=k("d ü v"), lines=["fooBarBaz"]),
    dict(name="dğv", keys=k("d ğ v"), lines=["fooBarBaz"], cursor=[1, 7]),
    dict(name="vüvd", keys=k("v ü v d"), lines=["fooBarBaz"]),
    dict(name="düü = d]]", keys=k("d ü ü"), lines=["a", "b", "{", "c"]),
    dict(name="vğğd = v[[d", keys=k("v ğ ğ d"), lines=["{", "a", "b"], cursor=[3, 0]),
    dict(name="dü% matchit", keys=k("d ü %"), lines=["f(a, (b), c) x"], cursor=[1, 3]),
    dict(name="dü Esc iptal", keys=k("d ü <Esc> x"), lines=TEXT),
    dict(name="vü Esc", keys=k("v l ü <Esc> d"), lines=TEXT),
    # --- f/t/r argümanı -----------------------------------------------------------------
    dict(name="fı literal", keys=k("f ı"), lines=["abıcid"]),
    dict(name="fi literal", keys=k("f i"), lines=["abıcid"]),
    dict(name="fç", keys=k("f ç"), lines=["a.b.ç"]),
    dict(name="tş", keys=k("t ş"), lines=["a;b;ş"]),
    dict(name="rı", keys=k("r ı"), lines=TEXT),
    dict(name="rİ", keys=k("r İ"), lines=TEXT),
    dict(name="mı / iı mark", keys=k("m ı g g i ı"), lines=TEXT, cursor=[3, 0]),
    # --- insert / cmdline metni ---------------------------------------------------------
    dict(name="insert TR metin", keys=["ı", TR, "<Esc>"], lines=TEXT),
    dict(name="insert noktalama", keys=k("A .:,; <Esc>"), lines=TEXT),
    dict(name="o TR metin", keys=["o", TR, "<Esc>"], lines=TEXT),
    dict(name="cmdline TR metin", keys=["Ş", "s/foo/" + "ığüş/", "<CR>"], lines=TEXT),
    # --- makrolar ---------------------------------------------------------------------
    dict(name="makro ı test", keys=k("q a ı test <Esc> q j 0 @ a"), lines=TEXT, regs="a"),
    dict(name="makro TR metin", keys=["q", "a", "ı", TR, "<Esc>", "q", "j", "0", "@", "a"], lines=TEXT, regs="a"),
    dict(name="makro x ç j", keys=k("q a x ç j q @ a"), lines=TEXT, regs="a"),
    dict(name="makro Q = son kayıt", keys=k("q a A ! <Esc> q j Q"), lines=TEXT, regs="a"),
    dict(name="makro @@", keys=k("q a A ! <Esc> q j @ a j @ @"), lines=TEXT, regs="a"),
    dict(name="makro 2@a", keys=k("q a ı Z <Esc> q j 0 2 @ a"), lines=TEXT, regs="a"),
    dict(name="makro arama", keys=k("q a . b <CR> x q g g @ a"), lines=["ab ab ab ab"], regs="a"),
    dict(name="makro fı", keys=k("q a f ı x q 0 @ a"), lines=["aıbıcıd"], regs="a"),
    dict(name="makro cıw", keys=k("q a c ı w Z <Esc> w q @ a"), lines=TEXT, regs="a"),
    dict(name="makro mark i", keys=k("m b G q a i b x q G @ a"), lines=TEXT, regs="a"),
    dict(name="makro qA append", keys=k("q a ı x <Esc> q q A a y <Esc> q j 0 @ a"), lines=TEXT, regs="a"),
    dict(name="makro İ register", keys=k("q a İ c y y q j @ a İ c p"), lines=TEXT, regs="ac"),
    # --- multicursor (0.12 plugin vs yerleşik: son metin aynı olmalı) ---------------------
    dict(name="mc <leader>m x2 cıw", keys=k("<Space> m <Space> m c ı w Z <Esc> <Esc>"), lines=["foo bar foo", "baz foo"]),
    dict(name="mc <leader>j basılı", keys=k("<Space> j j j A ! <Esc> <Esc>"), lines=TEXT, speeds=["human"]),
    dict(name="mc sonra ı insert", keys=k("<Space> m <Esc> <Esc> ı Q <Esc>"), lines=["foo foo"]),
    # --- plugin/leader map'leri ---------------------------------------------------------
    dict(name="gcc yorum", keys=k("g c c"), lines=["foo"], ft="lua"),
    dict(name="ü b = ]b sonraki buffer", keys=k("ü b"), lines=TEXT,
         setup="vim.cmd('badd /tmp/trlayer-b1.txt | badd /tmp/trlayer-b2.txt')",
         probe="return vim.fn.fnamemodify(vim.api.nvim_buf_get_name(0), ':t')"),
    dict(name="İ tek başına (which-key registers)", keys=k("İ"), lines=TEXT, speeds=["human"]),
    dict(name="i tek başına (which-key marks)", keys=k("i"), lines=TEXT, speeds=["human"]),
    # --- chord'lar (GUI yolu: nvim_input) -----------------------------------------------
    dict(name="C-ı = C-i jump ileri", keys=["G", "<C-o>", "<C-ı>"], lines=TEXT, rpc=True),
    dict(name="C-ü = C-] tag", keys=["<C-ü>"], lines=TEXT, rpc=True),
    dict(name="C-ı insert modda", keys=["A", "x", "<C-ı>", "y", "<Esc>"], lines=TEXT, rpc=True),
    dict(name="C-ı visual", keys=["G", "<C-o>", "v", "<C-ı>", "<Esc>"], lines=TEXT, rpc=True),
    dict(name="C-ğ normal (Esc değil)", keys=["v", "l", "<C-ğ>", "d"], lines=TEXT, rpc=True),
    dict(name="C-ğ insert (Esc değil)", keys=["A", "x", "<C-ğ>", "y", "<Esc>"], lines=TEXT, rpc=True),
    dict(name="C-ü insert", keys=["A", "x", "<C-ü>", "y", "<Esc>"], lines=TEXT, rpc=True),
    dict(name="C-ş normal", keys=["<C-ş>"], lines=TEXT, rpc=True),
    dict(name="C-İ normal", keys=["<C-İ>"], lines=TEXT, rpc=True),
    dict(name="C-ü burst tmux", keys=["<C-ü>"], lines=TEXT),
    dict(name="C-. = C-/ terminal", keys=["<C-.>"], lines=TEXT, rpc=True,
         probe="local b=vim.bo.buftype; vim.cmd('stopinsert'); return b"),
]
