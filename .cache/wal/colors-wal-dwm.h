static const char norm_fg[] = "#9a9a9a";
static const char norm_bg[] = "#000000";
static const char norm_border[] = "#363636";

static const char sel_fg[] = "#9a9a9a";
static const char sel_bg[] = "#293847";
static const char sel_border[] = "#9a9a9a";

static const char urg_fg[] = "#9a9a9a";
static const char urg_bg[] = "#2b2925";
static const char urg_border[] = "#2b2925";

static const char *colors[][3]      = {
    /*               fg           bg         border                         */
    [SchemeNorm] = { norm_fg,     norm_bg,   norm_border }, // unfocused wins
    [SchemeSel]  = { sel_fg,      sel_bg,    sel_border },  // the focused win
    [SchemeUrg] =  { urg_fg,      urg_bg,    urg_border },
};
