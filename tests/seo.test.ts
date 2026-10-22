import { describe, it, expect } from 'vitest';
import { seoForPath } from '../packages/shared/src/seo.js';
import { seoSiteOrigin, seoHttpStatus, seoRobotsTxt, seoSitemapXml, seoHtml } from '../apps/server/src/core/seo.js';

const template = '<!doctype html><html lang="id"><head><meta name="description" content="Generic"/><meta name="robots" content="noindex, nofollow"/><title>Generic</title></head><body><div id="root"></div></body></html>';
const origin = 'https://contoh-podokoyo.id';
describe('SEO public/private boundary', () => {
  it('keeps SITE_URL optional locally and rejects wrong production origins', () => {
    expect(seoSiteOrigin('')).toBe('');
    expect(seoSiteOrigin(origin + '/')).toBe(origin);
    for (const value of ['http://localhost:5173', origin + '/produk', 'https://name:pass@contoh-podokoyo.id', 'not-an-origin'])
      expect(() => seoSiteOrigin(value)).toThrow();
  });
  it('only exposes designated public routes to indexing', () => {
    expect(seoForPath('/produk')).toBeDefined();
    for (const path of ['/', '/desa', '/petani', '/produk']) expect(seoHttpStatus(path)).toBe(200);
    expect(seoHttpStatus('/login')).toBe(200);
    expect(seoHttpStatus('/dashboard/sales')).toBe(200);
    expect(seoHttpStatus('/missing')).toBe(404);
    for (const path of ['/dashboard/sales', '/login', '/privacy', '/missing']) {
      const html = seoHtml(template, path, origin);
      expect(html).toContain('content="noindex, nofollow"');
      expect(html).not.toContain('rel="canonical"');
    }
  });
  it('returns noindex and no canonical without a selected domain', () => {
    const html = seoHtml(template, '/produk', '');
    expect(html).toContain('content="noindex, nofollow"');
    expect(html).not.toContain('rel="canonical"');
    expect(seoRobotsTxt('')).toContain('Disallow: /');
  });
  it('provides per-route SEO tags and Organization structured data', () => {
    const html = seoHtml(template, '/', origin);
    expect(html).toContain('content="index, follow"');
    expect(html).toContain(`rel="canonical" href="${origin}/"`);
    expect(html).toContain('property="og:description"');
    expect(html).toContain('type="application/ld+json"');
    expect(seoHtml(template, '/produk', origin)).toContain('Produk Pertanian dan Olahan');
    expect(seoHtml(template, '/produk', origin)).not.toContain('type="application/ld+json"');
  });
  it('includes only public paths in the XML sitemap', () => {
    const s = seoSitemapXml(origin);
    for (const path of ['/', '/desa', '/petani', '/produk']) expect(s).toContain(`<loc>${origin}${path}</loc>`);
    expect(s).not.toContain('/dashboard');
    expect(seoRobotsTxt(origin)).toContain(`${origin}/sitemap.xml`);
  });
});
