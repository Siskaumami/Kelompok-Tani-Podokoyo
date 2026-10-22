import { useEffect } from 'react';
import { useQuery } from '@tanstack/react-query';
import { request } from './api';
import { seoProductRoute, seoProductPath, seoProductMeta } from '../../../packages/shared/src/seo-product.js';
import { useLocation } from 'react-router-dom';
import {
  seoForPath, seoPrivateTitle, seoSiteName,
} from '../../../packages/shared/src/seo.js';

function meta(name: string, content: string, property = false) {
  const attr = property ? 'property' : 'name';
  let node = document.head.querySelector<HTMLMetaElement>(`meta[${attr}="${name}"]`);
  if (!node) {
    node = document.createElement('meta');
    node.setAttribute(attr, name);
    document.head.appendChild(node);
  }
  node.content = content;
}
function link(rel: string, href: string) {
  let node = document.head.querySelector<HTMLLinkElement>(`link[rel="${rel}"]`);
  if (!href) { node?.remove(); return; }
  if (!node) { node = document.createElement('link'); node.rel = rel; document.head.appendChild(node); }
  node.href = href;
}
function removeMeta(property: string) {
  document.head.querySelector(`meta[property="${property}"]`)?.remove();
}

/** Client navigation keeps SEO tags in sync with the initial server-supplied HTML. */
export function SeoManager() {
  const location = useLocation();
  const productRoute = seoProductRoute(location.pathname);
  const siteQuery = useQuery({queryKey:['public'],queryFn:()=>request('/public/site'),enabled:Boolean(productRoute),
    initialData:()=>{const text=document.getElementById('public-ssr-data')?.textContent;try{return text?JSON.parse(text):undefined;}catch{return undefined;}}});
  const product = productRoute ? siteQuery.data?.products?.find((p: {id:string}) => p.id.toLowerCase() === productRoute.id) : undefined;
  useEffect(() => {
    const validProduct = product && seoProductPath(product) === location.pathname ? product : undefined;
    const page = seoForPath(location.pathname) ?? (validProduct ? seoProductMeta(validProduct) : undefined);
    const origin = document.head.querySelector<HTMLMetaElement>('meta[name="site-url"]')?.content ?? '';
    const indexable = Boolean(origin && page);
    const title = page?.title ?? (location.pathname === '/privacy'
      ? 'Kebijakan Privasi | Kelompok Tani Podokoyo' : seoPrivateTitle);
    const description = page?.description ?? 'Halaman Kelompok Tani Podokoyo.';
    const canonical = indexable ? origin + location.pathname : '';
    document.title = title;
    meta('description', description);
    meta('robots', indexable ? 'index, follow' : 'noindex, nofollow');
    link('canonical', canonical);
    meta('og:site_name', seoSiteName, true);
    meta('og:locale', 'id_ID', true);
    meta('og:type', 'website', true);
    meta('og:title', title, true);
    meta('og:description', description, true);
    if (canonical) {
      meta('og:url', canonical, true);
      meta('og:image', origin + (validProduct?.imageUrl || '/icon-512.png'), true);
    } else { removeMeta('og:url'); removeMeta('og:image'); }
    document.head.querySelector('script[data-seo-jsonld]')?.remove();
    if (indexable && validProduct) {
      const script=document.createElement('script');script.type='application/ld+json';script.dataset.seoJsonld='';
      script.textContent=JSON.stringify({'@context':'https://schema.org','@type':'Product',
        name: validProduct.name, description: validProduct.description, url: canonical,
        ...(validProduct.imageUrl ? {image:origin+validProduct.imageUrl}:{}),
        ...(/^\d+$/.test(validProduct.sellingPrice) ? {offers:{'@type':'Offer',price:validProduct.sellingPrice,priceCurrency:'IDR',url:canonical}}:{}),
      });document.head.appendChild(script);
    }
    if (indexable && location.pathname === '/') {
      const script = document.createElement('script');
      script.type = 'application/ld+json';
      script.dataset.seoJsonld = '';
      script.textContent = JSON.stringify({
        '@context': 'https://schema.org', '@type': 'Organization',
        name: seoSiteName, url: origin + '/', logo: origin + '/icon-512.png',
      });
      document.head.appendChild(script);
    }
  }, [location.pathname, product]);
  return null;
}
