const char *colorname[] = {

  /* 8 normal colors */
  [0] = "#000000", /* black   */
  [1] = "#2b2925", /* red     */
  [2] = "#293847", /* green   */
  [3] = "#344d4f", /* yellow  */
  [4] = "#52524b", /* blue    */
  [5] = "#55738e", /* magenta */
  [6] = "#6c93a6", /* cyan    */
  [7] = "#9a9a9a", /* white   */

  /* 8 bright colors */
  [8]  = "#363636",  /* black   */
  [9]  = "#2b2925",  /* red     */
  [10] = "#293847", /* green   */
  [11] = "#344d4f", /* yellow  */
  [12] = "#52524b", /* blue    */
  [13] = "#55738e", /* magenta */
  [14] = "#6c93a6", /* cyan    */
  [15] = "#9a9a9a", /* white   */

  /* special colors */
  [256] = "#000000", /* background */
  [257] = "#9a9a9a", /* foreground */
  [258] = "#9a9a9a",     /* cursor */
};

/* Default colors (colorname index)
 * foreground, background, cursor */
 unsigned int defaultbg = 0;
 unsigned int defaultfg = 257;
 unsigned int defaultcs = 258;
 unsigned int defaultrcs= 258;
