import { describe, it, expect } from 'vitest';
import { seoProductPath, seoProductPathOrCatalog, seoProductRoute, seoProductMeta } from '../packages/shared/src/seo-product.js';
import { seoPublicSnapshot, seoProductMarkup, seoInjectProduct } from '../apps/server/src/core/seo-public.js';
import { seoHtml, seoSitemapXml } from '../apps/server/src/core/seo.js';
const id = '123e4567-e89b-42d3-a456-426614174000';
const product = {id, name:'Biskuit Kentang Coklat',description:'Rasa coklat <script>alert(1)</script> & renyah', imageUrl:null,sellingPrice:'10000'};
const origin='https://contoh.test';
const raw={organization:{name:'Kelompok Tani Podokoyo',slug:'podokoyo'},village:null,products:[product],farmers:[]};
const template='<!doctype html><html lang="id"><head><meta name="description" content="lama"/><meta name="robots" content="noindex, nofollow"/><title>awal</title></head><body><div id="root"></div></body></html>';
describe('Public product SEO without database migrations',()=>{
 it('uses a readable slug and stable UUID and parses it safely',()=>{
  const path=seoProductPath(product);
  expect(path).toBe(`/produk/biskuit-kentang-coklat--${id}`);
  expect(seoProductRoute(path)).toEqual({id,slug:'biskuit-kentang-coklat'});
  expect(seoProductRoute('/produk/javascript:alert(1)')).toBeNull();
  expect(() => seoProductPath({...product,id:'bad'})).toThrow();
  expect(seoProductPathOrCatalog({id, name:product.name})).toBe(path);
  expect(seoProductPathOrCatalog({name:product.name})).toBe('/produk');
  expect(seoProductPathOrCatalog({id:'bad', name:product.name})).toBe('/produk');
 });
 it('produces indexable product metadata only with HTTPS SITE_URL',()=>{
  const path=seoProductPath(product);
  const html=seoHtml(template,path,origin,product);
  expect(html).toContain('rel="canonical"');
  expect(html).toContain(path);
  expect(html).toContain('Biskuit Kentang Coklat');
  expect(html).toContain('"@type":"Product"');
  expect(html).toContain('"priceCurrency":"IDR"');
  expect(html).not.toContain('<script>alert(1)</script>');
  expect(seoHtml(template,path,'',product)).toContain('noindex, nofollow');
 });
 it('includes only published product links in sitemap supplied by publicData',()=>{
  const map=seoSitemapXml(origin,[product]);
  expect(map).toContain(origin+seoProductPath(product));
  expect(map).toContain('<urlset');
  expect(seoSitemapXml(origin)).not.toContain(seoProductPath(product));
 });
 it('adds an HTML detail page and safe snapshot without exposing raw fields',()=>{
  const site=seoPublicSnapshot({...raw, internalSecret:'DO_NOT_INCLUDE',products:[{...product,cost_rp:'PRIVATE_COST',shopeeUrl:'javascript:alert(1)'}]});
  const html=seoInjectProduct(template,site,site.products[0]);
  expect(html).toContain('Biskuit Kentang Coklat');
  expect(html).toContain('href="/produk"');
  expect(html).toContain('&lt;script&gt;alert(1)&lt;/script&gt;');
  expect(html).not.toContain('PRIVATE_COST');
  expect(html).not.toContain('DO_NOT_INCLUDE');
  expect(html).not.toContain('javascript:');
  expect(seoProductMarkup(site,site.products[0])).toContain('<h1>');
 });
 it('has appropriate dynamic title and description',()=>{
  expect(seoProductMeta(product).title).toContain('Kelompok Tani Podokoyo');
  expect(seoProductMeta(product).description).toContain('Rasa coklat');
 });
});
