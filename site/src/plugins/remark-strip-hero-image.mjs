/**
 * remark-strip-hero-image
 *
 * Removes the first-paragraph image at the top of the manifesto markdown
 * (the `![Alt text](.../loom-logo.svg)` line). The site renders the logo
 * in the Layout masthead, not inline in the body. This keeps manifesto.md
 * untouched while preventing a duplicate logo render.
 */
export function remarkStripHeroImage() {
  return (tree) => {
    if (!tree || !Array.isArray(tree.children)) return;
    // Walk top-level nodes; remove the first paragraph that contains only
    // an image (and optional whitespace). Stop after the first removal —
    // we only ever want to strip the hero, never images further down.
    for (let i = 0; i < tree.children.length; i++) {
      const node = tree.children[i];
      if (node.type !== 'paragraph') continue;
      const meaningful = (node.children || []).filter(
        (c) => !(c.type === 'text' && /^\s*$/.test(c.value))
      );
      if (meaningful.length === 1 && meaningful[0].type === 'image') {
        tree.children.splice(i, 1);
        return;
      }
      // First non-paragraph or paragraph with text → stop searching.
      return;
    }
  };
}
