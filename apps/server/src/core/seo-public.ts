/** Server-rendered public *content* for search engines; React keeps controlling interactivity. */
import { seoForPath } from '../../../../packages/shared/src/seo.js';
import { seoProductPathOrCatalog } from '../../../../packages/shared/src/seo-product.js';

type R = Record<string, unknown>;
const record = (value: unknown): R => value !== null && typeof value === 'object' && !Array.isArray(value) ? value as R : {};
const arr = (value: unknown) => Array.isArray(value) ? value.map(record) : [];
const str = (value: unknown): string => typeof value === 'string' ? value : '';
const nullable = (value: unknown): string | null => typeof value === 'string' && value ? value : null;
const escapeHtml = (value: string): string => value.replace(/&/g, '&amp;').replace(/</g, '&lt;')
  .replace(/>/g, '&gt;').replace(/"/g, '&quot;').replace(/'/g, '&#39;');
const safeImage = (url: string | null): string => url && /^\/api\/v1\/public\/[a-z0-9-]+\/files\/[0-9a-f-]{36}$/i.test(url) ? url : '';
function safeExternal(url: string | null): string {
  if (!url || url.length > 2048) return '';
  try { const parsed = new URL(url); return ['https:', 'http:'].includes(parsed.protocol) ? parsed.href : ''; }
  catch { return ''; }
}
const escapeJSON = (data: unknown): string => JSON.stringify(data).replace(/[<>&\u2028\u2029]/g,
  char => '\\u' + char.charCodeAt(0).toString(16).padStart(4, '0'));

/** Include only fields from the published-site API. Never serialize database rows or actor data. */
export function seoPublicSnapshot(raw: unknown) {
  const source = record(raw);
  const organization = record(source.organization);
  if (!str(organization.name)) throw new Error('Published organization is unavailable.');
  const village = source.village ? record(source.village) : null;
  return {
    organization: { name: str(organization.name), slug: str(organization.slug) },
    village: village ? { title: str(village.title), body: str(village.body), imageUrl: safeImage(nullable(village.imageUrl)) || null } : null,
    products: arr(source.products).map(p => ({
      id: str(p.id), name: str(p.name), description: str(p.description), imageUrl: safeImage(nullable(p.imageUrl)) || null,
      sellingPrice: str(p.sellingPrice), shopeeUrl: safeExternal(nullable(p.shopeeUrl)) || null,
      tokopediaUrl: safeExternal(nullable(p.tokopediaUrl)) || null, whatsappUrl: safeExternal(nullable(p.whatsappUrl)) || null,
    })),
    farmers: arr(source.farmers).map(f => ({
      id: str(f.id), name: str(f.name), bio: str(f.bio), imageUrl: safeImage(nullable(f.imageUrl)) || null,
    })),
  };
}

export type SeoPublicSnapshot = ReturnType<typeof seoPublicSnapshot>;

const image = (url: string | null, alt: string): string => {
  const safe = safeImage(url);
  return safe ? `<img src="${escapeHtml(safe)}" alt="${escapeHtml(alt)}" loading="lazy"/>` : '';
};
function links(p: SeoPublicSnapshot['products'][number]): string {
  return ([['Shopee', p.shopeeUrl], ['Tokopedia', p.tokopediaUrl], ['WhatsApp', p.whatsappUrl]] as const)
    .map(([label, url]) => {
      const safe = safeExternal(url);
      return safe ? `<a href="${escapeHtml(safe)}" rel="noopener noreferrer" target="_blank">${label}</a>` : '';
    }).join(' ');
}
function products(site: SeoPublicSnapshot): string {
  if (!site.products.length) return '<p>Produk sedang disiapkan oleh pengelola.</p>';
  return `<div class="product-grid">${site.products.map(p => `<article class="public-product">${image(p.imageUrl,p.name)}<div class="product-body"><h2><a href="${seoProductPathOrCatalog(p)}">${escapeHtml(p.name)}</a></h2><p>${escapeHtml(p.description)}</p><p>Harga: Rp ${escapeHtml(p.sellingPrice)}</p><div class="commerce-links">${links(p)}</div></div></article>`).join('')}</div>`;
}
function farmers(site: SeoPublicSnapshot): string {
  if (!site.farmers.length) return '<p>Profil para petani sedang disiapkan oleh pengelola.</p>';
  return `<div class="farmer-grid">${site.farmers.map(f => `<article class="farmer-card">${image(f.imageUrl,f.name)}<div><h2>${escapeHtml(f.name)}</h2><p>${escapeHtml(f.bio)}</p></div></article>`).join('')}</div>`;
}
function village(site: SeoPublicSnapshot): string {
  if (!site.village) return '<p>Cerita desa sedang disiapkan oleh pengelola.</p>';
  const text = site.village.body.split(/\n\s*\n/).filter(Boolean).map(para => `<p>${escapeHtml(para)}</p>`).join('');
  return `<article class="village-story">${image(site.village.imageUrl,site.village.title)}<h2>${escapeHtml(site.village.title)}</h2>${text}</article>`;
}

export function seoPublicMarkup(pathname: string, site: SeoPublicSnapshot): string {
  if (!seoForPath(pathname)) throw new Error('Not a supported public SEO route.');
  const heading: Record<string, string> = {
    '/': 'Hasil tani. Cerita dari desa.', '/desa': 'Desa kami.',
    '/petani': 'Tumbuh, bersama.', '/produk': 'Hasil dari kerja bersama.',
  };
  const body = pathname === '/produk' ? products(site)
    : pathname === '/petani' ? farmers(site)
    : pathname === '/desa' ? village(site)
    : `<p>Kenali Desa Podokoyo, para petani, dan produk pertanian lokal di Tosari, Pasuruan.</p>
       ${site.village ? `<p>${escapeHtml(site.village.body.slice(0, 500))}</p>` : ''}
       <section><h2>Produk kami</h2>${products(site)}</section>
       <p><a href="/desa">Tentang desa</a> · <a href="/petani">Para petani</a> · <a href="/produk">Lihat produk</a></p>`;
  return `<div class="public-app" data-public-initial="true"><header class="public-header"><a href="/">${escapeHtml(site.organization.name)}</a><nav aria-label="Menu publik"><a href="/">Beranda</a> <a href="/desa">Desa kami</a> <a href="/petani">Para petani</a> <a href="/produk">Produk</a></nav></header><main class="public-main"><header class="public-page-heading"><h1>${escapeHtml(heading[pathname] ?? '')}</h1></header>${body}</main></div>`;
}

/** Replaces the empty Vite root only for the four whitelisted public routes. */
export function seoInjectPublic(html: string, pathname: string, site: SeoPublicSnapshot): string {
  if (!html.includes('<div id="root"></div>')) throw new Error('Expected Vite root element not found.');
  const markup = seoPublicMarkup(pathname, site);
  const seed = `<script id="public-ssr-data" type="application/json">${escapeJSON(site)}</script>`;
  return html.replace('<div id="root"></div>', `<div id="root">${markup}</div>${seed}`);
}

/** Public detail HTML reads only the already-whitelisted published snapshot. */
export function seoProductMarkup(site: SeoPublicSnapshot, product: SeoPublicSnapshot['products'][number]): string {
  return `<div class="public-app" data-public-initial="true"><header class="public-header"><a href="/">${escapeHtml(site.organization.name)}</a><nav aria-label="Menu publik"><a href="/">Beranda</a> <a href="/desa">Desa kami</a> <a href="/petani">Para petani</a> <a href="/produk">Produk</a></nav></header><main class="public-main"><header class="public-page-heading"><h1>${escapeHtml(product.name)}</h1></header><article class="village-story village-feature">${image(product.imageUrl,product.name)}<h2>Informasi produk</h2><p>${escapeHtml(product.description)}</p><p>Harga: Rp ${escapeHtml(product.sellingPrice)}</p><div class="commerce-links">${links(product)}</div><p><a href="/produk">Kembali ke katalog</a></p></article></main></div>`;
}
export function seoInjectProduct(html: string,site: SeoPublicSnapshot,product: SeoPublicSnapshot['products'][number]): string {
  if(!html.includes('<div id="root"></div>')) throw new Error('Expected Vite root element not found.');
  const seed=`<script id="public-ssr-data" type="application/json">${escapeJSON(site)}</script>`;
  return html.replace('<div id="root"></div>', `<div id="root">${seoProductMarkup(site,product)}</div>${seed}`);
}
