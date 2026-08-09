/**
 * remark-strip-copyright
 *
 * Removes the inline copyright block from the manifesto markdown body.
 * The footer carries the canonical legal line; the body block would
 * duplicate it (and the inline HTML fights the .prose typography).
 *
 * The block we strip is the centred `<p align="center"><small>…</small></p>`
 * near the end of the document, plus the trailing HTML comment that
 * mirrors it. Both arrive in the markdown AST as `html` nodes. We also
 * remove the divider `<hr>` immediately preceding the block, since that
 * rule existed to separate the body from the copyright stamp.
 *
 * The match is structural (HTML node containing `align="center"` and
 * `creativecommons.org` / `theloommanifesto.org`), not text-based, so
 * minor edits to the manifesto wording will not break it.
 */
export function remarkStripCopyright() {
  return (tree) => {
    if (!tree || !Array.isArray(tree.children)) return;

    const isCopyrightHtml = (node) =>
      node?.type === 'html' &&
      typeof node.value === 'string' &&
      /align="center"/.test(node.value) &&
      /creativecommons\.org/i.test(node.value);

    const isTrailingCopyrightComment = (node) =>
      node?.type === 'html' &&
      typeof node.value === 'string' &&
      /^<!--[\s\S]*The Loom Manifesto[\s\S]*-->$/i.test(node.value);

    for (let i = tree.children.length - 1; i >= 0; i--) {
      const node = tree.children[i];
      if (isCopyrightHtml(node) || isTrailingCopyrightComment(node)) {
        tree.children.splice(i, 1);
        // Drop a preceding thematic break (the --- divider before the block).
        if (i > 0 && tree.children[i - 1]?.type === 'thematicBreak') {
          tree.children.splice(i - 1, 1);
        }
      }
    }
  };
}
