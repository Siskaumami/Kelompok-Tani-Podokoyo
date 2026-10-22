import {
  seoForPath,
  seoPublicPaths,
  seoPrivateTitle,
  seoSiteName,
} from '../../../../packages/shared/src/seo.js';
import { seoProductPath, seoProductMeta, type SeoProduct } from '../../../../packages/shared/src/seo-product.js';

const esc = (s: string) => s.replace(/&/g, '&amp;').replace(/"/g, '&quot;')
  .replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/'/g, '&#39;');

/** No domain needed in development. In production, SITE_URL must be an HTTPS origin. */
export function seoSiteOrigin(value: string): string {
  const raw = value.trim();
  if (!raw) return '';
  let url: URL;
  try { url = new URL(raw); } catch { throw new Error('SITE_URL must be an HTTPS origin.'); }
  if (url.protocol !== 'https:' || url.username || url.password || url.pathname !== '/' ||
      url.search || url.hash || (raw !== url.origin && raw !== url.origin + '/')) {
    throw new Error('SITE_URL must be an HTTPS origin, without path/query/credentials.');
  }
  return url.origin;
}

export function seoHttpStatus(pathname: string): number {
  if (seoForPath(pathname)) return 200;
  if (['/privacy', '/account-deletion', '/login', '/forgot-password',
        '/reset-password', '/accept-invitation'].includes(pathname)) return 200;
  if (/^\/dashboard(?:\/.*)?$/.test(pathname)) return 200;
  return 404;
}

/** robots.txt deliberately does not block private HTML; Google must see its noindex header. */
export function seoRobotsTxt(origin: string): string {
  if (!origin) return 'User-agent: *\nDisallow: /\n';
  return `User-agent: *\nAllow: /\nSitemap: ${origin}/sitemap.xml\n`;
}

export function seoSitemapXml(origin: string, products: Pick<SeoProduct,'id'|'name'>[] = []): string {
  if (!origin) throw new Error('SITE_URL is required before publishing sitemap.xml');
  const entries = [...seoPublicPaths, ...products.map(p => seoProductPath(p))]
    .map(p => `  <url><loc>${esc(origin + p)}</loc></url>`).join('\n');
  return `<?xml version="1.0" encoding="UTF-8"?>\n<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">\n${entries}\n</urlset>\n`;
}

export function seoHtml(template: string, pathname: string, origin: string, product?: SeoProduct): string {
  const validProduct = product && seoProductPath(product) === pathname ? product : undefined;
  const page = seoForPath(pathname) ?? (validProduct ? seoProductMeta(validProduct) : undefined);
  const indexable = Boolean(origin && page);
  const title = page?.title ?? (pathname === '/privacy'
    ? 'Kebijakan Privasi | Kelompok Tani Podokoyo'
    : seoPrivateTitle);
  const description = page?.description ?? 'Halaman Kelompok Tani Podokoyo.';
  const canonical = indexable ? origin + pathname : '';
  const robots = indexable ? 'index, follow' : 'noindex, nofollow';
  const html = template
    .replace(/<title>[\s\S]*?<\/title>/i, `<title>${esc(title)}</title>`)
    .replace(/<meta name="description" content="[^"]*"\s*\/>/i,
      `<meta name="description" content="${esc(description)}"/>`)
    .replace(/<meta name="robots" content="[^"]*"\s*\/>/i,
      `<meta name="robots" content="${robots}"/>`);
  const head = [
    `<meta name="site-url" content="${esc(origin)}"/>`,
    ...(canonical ? [`<link rel="canonical" href="${esc(canonical)}"/>`] : []),
    `<meta property="og:site_name" content="${esc(seoSiteName)}"/>`,
    `<meta property="og:locale" content="id_ID"/>`,
    `<meta property="og:type" content="website"/>`,
    `<meta property="og:title" content="${esc(title)}"/>`,
    `<meta property="og:description" content="${esc(description)}"/>`,
    ...(canonical ? [
      `<meta property="og:url" content="${esc(canonical)}"/>`,
      `<meta property="og:image" content="${esc(origin + (validProduct?.imageUrl || '/icon-512.png'))}"/>`,
    ] : []),
    ...(indexable && validProduct ? [
      `<script data-seo-jsonld type="application/ld+json">${JSON.stringify({
        '@context': 'https://schema.org', '@type': 'Product', name: validProduct.name,
        description: validProduct.description,
        url: origin + pathname,
        ...(validProduct.imageUrl ? {image: origin + validProduct.imageUrl} : {}),
        ...(/^\d+$/.test(validProduct.sellingPrice) ? {offers: {
          '@type': 'Offer',price: validProduct.sellingPrice,priceCurrency: 'IDR',url:origin+pathname,
        }} : {}),
      }).replace(/</g, '\\u003c')}</script>`,
    ] : []),
    ...(indexable && pathname === '/' ? [
      `<script data-seo-jsonld type="application/ld+json">${JSON.stringify({
        '@context': 'https://schema.org',
        '@type': 'Organization',
        name: seoSiteName,
        url: origin + '/',
        logo: origin + '/icon-512.png',
      }).replace(/</g, '\\u003c')}</script>`,
    ] : []),
  ].join('');
  return html.replace('</head>', head + '</head>');
}
