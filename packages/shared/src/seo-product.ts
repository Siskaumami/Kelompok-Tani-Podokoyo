/** Product URLs have a readable name AND immutable UUID. No database migration required. */
export type SeoProduct = {
  id: string; name: string; description: string; imageUrl: string | null; sellingPrice: string;
};
const uuid = '[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}';
const idPattern = new RegExp(`^${uuid}$`, 'i');
const routePattern = new RegExp(`^/produk/([a-z0-9]+(?:-[a-z0-9]+)*)--(${uuid})$`, 'i');
export function seoProductSlug(name: string): string {
  const value = name.normalize('NFKD').replace(/[\u0300-\u036f]/g, '').toLowerCase()
    .replace(/[^a-z0-9]+/g, '-').replace(/^-+|-+$/g, '').slice(0,80).replace(/-+$/g,'');
  return value || 'produk';
}
export function seoProductPath(product: Pick<SeoProduct,'id'|'name'>): string {
  if (!idPattern.test(product.id)) throw new Error('Product SEO URL needs a UUID.');
  return `/produk/${seoProductSlug(product.name)}--${product.id.toLowerCase()}`;
}
export function seoProductPathOrCatalog(product: Partial<Pick<SeoProduct,'id'|'name'>>): string {
  return typeof product.id === 'string' && typeof product.name === 'string' && idPattern.test(product.id)
    ? seoProductPath({id:product.id,name:product.name}) : '/produk';
}
export function seoProductRoute(pathname: string): { id: string; slug: string } | null {
  const match = routePattern.exec(pathname);
  return match ? { slug: match[1], id: match[2].toLowerCase() } : null;
}
export function seoProductMeta(product: SeoProduct): {title: string;description: string} {
  const title = `${product.name.trim().slice(0,90)} | Kelompok Tani Podokoyo`;
  const details = product.description.trim().replace(/\s+/g,' ');
  const description = details ? `${product.name}. ${details}`.slice(0,170)
    : `Kenali ${product.name} dari Kelompok Tani Podokoyo, Tosari, Pasuruan. Informasi produk dan pilihan pembelian.`;
  return { title, description };
}
