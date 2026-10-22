/** Public SEO routes only. Dashboard and authentication are intentionally absent. */
export const seoPages = {
  '/': {
    title: 'Kelompok Tani Podokoyo | Pertanian dan Produk Lokal Pasuruan',
    description: 'Kenali Kelompok Tani Podokoyo di Desa Podokoyo, Tosari, Pasuruan. Jelajahi cerita desa, para petani, dan katalog produk pertanian serta olahan lokal.',
  },
  '/desa': {
    title: 'Desa Podokoyo, Tosari | Kelompok Tani Podokoyo',
    description: 'Mengenal Desa Podokoyo di Tosari, Kabupaten Pasuruan, dan cerita pertanian serta kegiatan Kelompok Tani Podokoyo.',
  },
  '/petani': {
    title: 'Para Petani | Kelompok Tani Podokoyo',
    description: 'Kenali anggota dan petani Kelompok Tani Podokoyo, desa pertanian di kawasan Tosari, Pasuruan.',
  },
  '/produk': {
    title: 'Produk Pertanian dan Olahan | Kelompok Tani Podokoyo',
    description: 'Lihat katalog produk hasil pertanian dan olahan Kelompok Tani Podokoyo di Tosari, Pasuruan, beserta informasi produk dan pilihan pembelian.',
  },
} as const;

export const seoPublicPaths = Object.keys(seoPages);
export type SeoPublicPath = keyof typeof seoPages;
export function seoForPath(path: string) {
  return Object.prototype.hasOwnProperty.call(seoPages, path)
    ? seoPages[path as SeoPublicPath]
    : undefined;
}
export const seoSiteName = 'Kelompok Tani Podokoyo';
export const seoPrivateTitle = 'Ruang Kerja | Kelompok Tani Podokoyo';
