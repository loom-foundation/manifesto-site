/**
 * rehype-closing-aphorism
 *
 * Adds the `closing-aphorism` class to the last top-level <p> in the
 * rendered markdown body. The `.manifesto p.closing-aphorism` rule in
 * global.css centres and emphasises the paragraph typographically.
 *
 * "Top-level" means a direct child <p> of the root element — not a <p>
 * inside a <blockquote> or other container. The manifesto closes with a
 * standalone bolded paragraph; this plugin finds it without needing the
 * manifesto source to carry any class attribute.
 *
 * Manifesto.md itself is never touched.
 */

export function rehypeClosingAphorism() {
  return (tree) => {
    if (!tree || !Array.isArray(tree.children)) return;

    // Walk backwards through top-level children to find the last <p>.
    for (let i = tree.children.length - 1; i >= 0; i--) {
      const node = tree.children[i];
      if (node.type === 'element' && node.tagName === 'p') {
        node.properties = node.properties || {};
        const existing = node.properties.className;
        const classes = Array.isArray(existing)
          ? existing.slice()
          : typeof existing === 'string'
            ? existing.split(/\s+/).filter(Boolean)
            : [];
        if (!classes.includes('closing-aphorism')) {
          classes.push('closing-aphorism');
        }
        node.properties.className = classes;
        return;
      }
    }
  };
}
