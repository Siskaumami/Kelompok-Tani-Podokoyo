import { describe, it, expect } from 'vitest';
import { seoPublicSnapshot, seoPublicMarkup, seoInjectPublic } from '../apps/server/src/core/seo-public.js';

const raw = {
  organization: { name: 'Kelompok Tani Podokoyo', slug: 'podokoyo', secret: 'PRIVATE_ORG_TOKEN' },
  village: { title: 'Desa Podokoyo', body: 'Cerita <script>alert(1)</script>', imageUrl: null },
  farmers: [{ id: 'f1', name: 'Petani <script>alert(1)</script>', bio: 'Aktif & ramah', password_hash: 'PRIVATE_PASSWORD' }],
  products: [{ id: 'p1', name: 'Biskuit Kentang', description: 'Coklat & matcha', sellingPrice: '10000',
    imageUrl: '/api/v1/public/podokoyo/files/123e4567-e89b-12d3-a456-426614174000',
    shopeeUrl: 'https://shopee.co.id/product', tokopediaUrl: 'javascript:alert(1)',
    whatsappUrl: 'https://wa.me/620000', costPrice: 'PRIVATE_COST' }],
  internalKey: 'PRIVATE_INTERNAL_KEY',
};
const template = '<!doctype html><html><head><title>test</title></head><body><div id="root"></div></body></html>';

describe('Published SEO HTML boundary', () => {
  it('whitelists public snapshot fields and never includes private database fields', () => {
    const site = seoPublicSnapshot(raw);
    const html = seoInjectPublic(template, '/produk', site);
    expect(html).toContain('Biskuit Kentang');
    for (const secret of ['PRIVATE_ORG_TOKEN','PRIVATE_PASSWORD','PRIVATE_COST','PRIVATE_INTERNAL_KEY'])
      expect(html).not.toContain(secret);
  });
  it('escapes HTML, keeps readable content and rejects unsafe external links', () => {
    const site = seoPublicSnapshot(raw);
    expect(seoPublicMarkup('/petani', site)).toContain('&lt;script&gt;alert(1)&lt;/script&gt;');
    const html = seoPublicMarkup('/produk', site);
    expect(html).toContain('Coklat &amp; matcha');
    expect(html).not.toContain('javascript:');
    expect(html).toContain('href="https://shopee.co.id/product"');
  });
  it('embeds a safe JSON seed and still works without JavaScript', () => {
    const site = seoPublicSnapshot(raw);
    const html = seoInjectPublic(template, '/desa', site);
    expect(html).toContain('<main class="public-main">');
    expect(html).not.toContain('<script>alert(1)</script>');
    expect(html).toContain('\\u003cscript');
    const serialized = html.match(/<script id="public-ssr-data" type="application\/json">([^<]*)<\/script>/)?.[1];
    expect(serialized).toBeDefined();
    expect(JSON.parse(serialized!).village.title).toBe('Desa Podokoyo');
  });
  it('renders only allowed public routes', () => {
    const site = seoPublicSnapshot(raw);
    for (const route of ['/', '/desa', '/petani', '/produk'])
      expect(seoPublicMarkup(route, site)).toContain('<h1>');
    expect(() => seoPublicMarkup('/dashboard', site)).toThrow();
    expect(() => seoPublicMarkup('/login', site)).toThrow();
  });
  it('rejects missing Vite roots and invalid public organizations', () => {
    expect(() => seoPublicSnapshot({organization: {name: ''}})).toThrow();
    expect(() => seoInjectPublic('<html></html>', '/', seoPublicSnapshot(raw))).toThrow();
  });
});
