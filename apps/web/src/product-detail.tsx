import { useQuery } from '@tanstack/react-query';
import { Link, useParams } from 'react-router-dom';
import { request } from './api';
import { money } from './format';
import { ErrorNotice, Loading, type Data } from './ui';
import { seoProductPath, seoProductRoute } from '../../../packages/shared/src/seo-product.js';

function publishedSeed(): Data | undefined {
  const text = document.getElementById('public-ssr-data')?.textContent;
  if (!text) return undefined;
  try { return JSON.parse(text) as Data; } catch { return undefined; }
}
export function ProductDetailPage() {
  const { productSlug = '' } = useParams();
  const route = seoProductRoute('/produk/' + productSlug);
  const q = useQuery<Data>({queryKey:['public'],queryFn:()=>request('/public/site'),initialData:publishedSeed});
  if (!route) return <main className="public-main"><h1>Produk tidak ditemukan</h1><p><Link to="/produk">Kembali ke katalog</Link></p></main>;
  if (q.isPending) return <main className="public-main"><Loading/></main>;
  if (q.isError) return <main className="public-main"><ErrorNotice error={q.error} retry={()=>q.refetch()}/></main>;
  const product = (q.data.products ?? []).find((item: Data) => item.id.toLowerCase() === route.id);
  if (!product) return <main className="public-main"><h1>Produk tidak ditemukan</h1><p><Link to="/produk">Kembali ke katalog</Link></p></main>;
  const canonicalPath = seoProductPath(product);
  const links = [['Shopee',product.shopeeUrl],['Tokopedia',product.tokopediaUrl],['WhatsApp',product.whatsappUrl]] as const;
  return <main className="public-main">
    <header className="public-page-heading"><span className="eyebrow">PRODUK KELOMPOK TANI PODOKOYO</span>
      <h1>{product.name}</h1><p>{product.description || 'Hasil kerja bersama para petani Desa Podokoyo.'}</p></header>
    <article className="village-story village-feature">
      {product.imageUrl && <img className="village-story-image" src={product.imageUrl} alt={product.name} loading="eager"/>}
      <div className="village-story-copy"><h2>Informasi produk</h2>
        {product.description && <p>{product.description}</p>}
        <p><strong>Harga: {money(product.sellingPrice)}</strong></p>
        <div className="commerce-links">{links.filter(([,url])=>url).map(([label,url])=><a className="button secondary small" key={label} href={url} target="_blank" rel="noopener noreferrer">Beli melalui {label}</a>)}</div>
        <p><Link className="text-button" to="/produk">Kembali ke semua produk</Link></p>
      </div>
    </article>
    {('/produk/' + productSlug) !== canonicalPath && <p className="muted-text">Alamat produk telah diperbarui. <Link to={canonicalPath}>Buka alamat terbaru</Link>.</p>}
  </main>;
}
