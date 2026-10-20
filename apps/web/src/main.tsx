import React,{createContext,useContext,useEffect,useState,type FormEvent} from 'react';
import { createRoot } from 'react-dom/client';
import { BrowserRouter,Routes,Route,Navigate,Link,NavLink,Outlet,useLocation,useNavigate } from 'react-router-dom';
import { QueryClientProvider,useQuery } from '@tanstack/react-query';
import { ArrowUpRight,ArrowRight,Leaf,Package,Users,Menu,X,LayoutDashboard,Wheat,Warehouse,ClipboardCheck,Waypoints,Factory,ShoppingBag,ChartNoAxesCombined,Settings,ScrollText,PanelTop,LogOut,WifiOff,LoaderCircle } from 'lucide-react';
import { request,queryClient,setCsrf,ApiError } from './api';
import { ErrorNotice,Loading,Empty,type Data } from './ui';
import { money } from './format';
import { CoBrandIdentity,HighlandScene } from './identity';
import { Operations,Overview,SettingsPage,ReportsPage,ContentPage } from './pages';
import './styles.css';
const Auth=createContext<Data|null>(null);
export const useAuth=()=>useContext(Auth)!;
function OfflineBanner(){const [online,setOnline]=useState(navigator.onLine);useEffect(()=>{const yes=()=>setOnline(true),no=()=>setOnline(false);window.addEventListener('online',yes);window.addEventListener('offline',no);return()=>{window.removeEventListener('online',yes);window.removeEventListener('offline',no);};},[]);return online?null:<div role="alert" className="offline-banner"><WifiOff size={18}/>Tidak ada koneksi. Transaksi memerlukan internet dan tidak akan diantrekan.</div>;}
function PublicLayout(){const [menu,setMenu]=useState(false),location=useLocation();useEffect(()=>setMenu(false),[location.pathname]);return <div className="public-app"><OfflineBanner/><header className="public-header"><CoBrandIdentity/><button className="icon-button mobile-toggle" aria-label={menu?'Tutup menu':'Buka menu'} onClick={()=>setMenu(!menu)}>{menu?<X/>:<Menu/>}</button><nav className={menu?'public-nav open':'public-nav'}><NavLink to="/" end>Beranda</NavLink><NavLink to="/desa">Desa kami</NavLink><NavLink to="/petani">Para petani</NavLink><NavLink to="/produk">Produk</NavLink></nav></header><Outlet/><footer className="public-footer"><CoBrandIdentity variant="footer"/><span>Dari hasil panen, tumbuh kesempatan.</span><Link className="text-button" to="/privacy">Kebijakan Privasi</Link><Link className="text-button" to="/account-deletion">Hapus akun</Link></footer></div>;}
function PublicPage({section='home'}:{section?:string}){
 const q=useQuery({queryKey:['public'],queryFn:()=>request('/public/site')});
 if(q.isPending)return <main className="public-main"><Loading/></main>;
 if(q.isError)return <main className="public-main"><div className="public-page-heading"><span className="eyebrow">KELOMPOK TANI PODOKOYO</span><h1>Ruang tumbuh<br/>hasil pertanian desa.</h1></div><ErrorNotice error={q.error} retry={()=>q.refetch()}/><p className="muted-text">Profil dan katalog akan tersedia setelah pengelola menyiapkan informasi kelompok tani.</p></main>;
 const {organization,village,products,farmers}=q.data;
 const productGrid=<>{products.length?<div className="product-grid">{products.map((p:Data)=><article className="public-product" key={p.id}>{p.imageUrl?<img src={p.imageUrl} alt={p.name} loading="lazy"/>:<div className="product-no-image"><Package size={38}/><span>Foto belum tersedia</span></div>}<div className="product-body"><h3>{p.name}</h3><p>{p.description}</p><strong>{money(p.sellingPrice)}</strong><div className="commerce-links">{[['Shopee',p.shopeeUrl],['Tokopedia',p.tokopediaUrl],['WhatsApp',p.whatsappUrl]].filter(([,url])=>url).map(([name,url])=><a className="button secondary small" href={url} key={name} target="_blank" rel="noopener noreferrer">{name}<ArrowUpRight size={15}/></a>)}</div>{!p.shopeeUrl&&!p.tokopediaUrl&&!p.whatsappUrl&&<small className="muted-text">Tautan pembelian belum tersedia.</small>}</div></article>)}</div>:<Empty title="Produk sedang disiapkan" description="Produk yang telah diterbitkan pengelola akan tampil di sini bersama tautan pembeliannya."/>}</>;
 const farmerGrid=<>{farmers.length?<div className="farmer-grid">{farmers.map((f:Data)=><article className="farmer-card" key={f.id}>{f.imageUrl?<img src={f.imageUrl} alt={f.name} loading="lazy"/>:<span className="farmer-avatar"><Leaf size={32}/></span>}<div><h3>{f.name}</h3><p>{f.bio}</p></div></article>)}</div>:<Empty title="Kenali para petani, segera" description="Profil anggota kelompok tani akan hadir setelah diterbitkan oleh pengelola."/>}</>;
 return <main className="public-main">
 {section==='home'?<><section className="hero"><HighlandScene/><div className="hero-copy"><span className="eyebrow"><span className="live-dot"/> {organization.name}</span><h1>Hasil tani.<br/>Cerita <em>dari desa.</em></h1><p>{village?village.body.slice(0,240):'Ruang untuk mengenal desa, para petani, dan produk yang tumbuh dari kerja bersama.'}</p><div className="hero-actions"><Link className="button" to="/produk">Jelajahi produk <ArrowRight size={18}/></Link><Link className="text-button" to="/desa">Tentang desa kami <ArrowUpRight size={18}/></Link></div><div className="hero-note"><Leaf size={18}/><span>Dikelola bersama. Bertumbuh bersama.</span></div></div><div className="hero-place"><span>Desa Podokoyo</span><small>Tosari · Pasuruan</small></div></section><div className="values-strip"><span><Wheat size={20}/>Hasil pertanian desa</span><span><Users size={20}/>Kerja bersama petani</span><span><Package size={20}/>Produk dan olahan lokal</span></div><section className="public-section"><div className="section-title"><div><span className="eyebrow">DARI KELOMPOK TANI</span><h2>Kenali produk kami.</h2></div><Link className="text-button" to="/produk">Semua produk <ArrowRight size={17}/></Link></div>{productGrid}</section><section className="village-teaser">{village?.imageUrl&&<img className="village-teaser-image" src={village.imageUrl} alt={village.title} loading="lazy"/>}<div className="village-teaser-copy"><span className="eyebrow">ADA CERITA DI BALIK HASIL PANEN</span><h2>{village?.title??'Mengenal desa dan orang-orangnya.'}</h2><p>{village?village.body.split(/\n\s*\n/)[0]:'Profil desa dan cerita kelompok tani sedang dipersiapkan oleh pengelola.'}</p><Link className="button secondary" to="/desa">Baca cerita desa <ArrowUpRight size={17}/></Link></div></section></>:<><header className="public-page-heading scenic-heading"><HighlandScene variant="heading"/><span className="eyebrow">{organization.name}</span><h1>{section==='village'?'Desa kami.':section==='farmers'?'Tumbuh, bersama.':'Hasil dari kerja bersama.'}</h1><p>{section==='village'?'Cerita tempat dan kelompok tani di balik hasil panen.':section==='farmers'?'Berkenalan dengan anggota kelompok tani.':'Temukan produk, lalu beli melalui pilihan yang tersedia.'}</p></header>{section==='products'?productGrid:section==='farmers'?farmerGrid:village?<article className="village-story village-feature">{village.imageUrl&&<img className="village-story-image" src={village.imageUrl} alt={village.title}/>}<div className="village-story-copy"><h2>{village.title}</h2><p>{village.body.split(/\n\s*\n/)[0]}</p></div><div className="village-story-rest">{village.body.split(/\n\s*\n/).slice(1).map((paragraph:string,i:number)=><p key={i}>{paragraph}</p>)}<Link className="text-button" to="/petani">Kenali para petani <ArrowRight size={18}/></Link></div></article>:<Empty title="Cerita desa sedang disiapkan" description="Profil desa akan tampil setelah diterbitkan pengelola."/>}</>}
 </main>;
}
function AuthPage({mode='login'}:{mode?:'login'|'forgot'|'reset'|'invite'}){
 const navigate=useNavigate(),location=useLocation(),[busy,setBusy]=useState(false),[error,setError]=useState<unknown>(),[message,setMessage]=useState('');
 const next=mode==='login'?new URLSearchParams(location.search).get('next'):'';
 const returnTo=next==='/account-deletion'?next:'/dashboard';
 const [token]=useState(()=>new URLSearchParams(window.location.hash.slice(1)).get('token')??'');
 useEffect(()=>{if(window.location.hash)window.history.replaceState(null,'',window.location.pathname);},[]);
 useEffect(()=>{setMessage('');setError(undefined);},[mode]);
 async function submit(e:FormEvent<HTMLFormElement>){e.preventDefault();const f=new FormData(e.currentTarget);setBusy(true);setError(undefined);try{
  if(mode==='login'){const r=await request('/auth/login',{method:'POST',body:JSON.stringify({email:f.get('email'),password:f.get('password')})});setCsrf(r.csrf);queryClient.setQueryData(['session'],r);navigate(returnTo,{replace:true});}
  else{const path=mode==='forgot'?'/auth/forgot-password':mode==='reset'?'/auth/reset-password':'/auth/accept-invitation';const payload=mode==='forgot'?{email:f.get('email')}:{token,password:f.get('password'),...(mode==='invite'?{name:f.get('name')}:{})};const r=await request(path,{method:'POST',body:JSON.stringify(payload)});setMessage(r.message);}
 }catch(e){setError(e);}finally{setBusy(false);}}
 const title=mode==='login'?'Selamat datang kembali.':mode==='forgot'?'Pulihkan akses akun.':mode==='reset'?'Kata sandi baru.':'Bergabung sebagai Admin.';
 return <main className="auth-page"><HighlandScene variant="auth-mobile"/><section className="auth-story"><HighlandScene variant="auth"/><CoBrandIdentity variant="login"/><div className="auth-story-copy"><span className="eyebrow">RUANG KERJA KELOMPOK TANI</span><h1>Catatan yang rapi.<br/>Langkah yang pasti.</h1><p>Dari panen hingga penjualan, kelola pekerjaan bersama dalam satu tempat.</p></div><small>Kelompok Tani Podokoyo</small></section><section className="auth-form"><div className="auth-content"><span className="eyebrow">AKSES PENGELOLA</span><h2>{title}</h2><p>{mode==='login'?'Masuk menggunakan akun yang telah dibuat pengelola.':mode==='forgot'?'Masukkan email akun untuk menerima tautan pengaturan ulang.':'Gunakan minimal 12 karakter untuk kata sandi Anda.'}</p>{message&&mode!=='login'?<div className="notice success"><div>{message}<Link className="text-button" to="/login">Ke halaman masuk <ArrowRight size={16}/></Link></div></div>:<form onSubmit={submit}>{mode==='invite'&&<label>Nama lengkap<input name="name" required maxLength={200} autoComplete="name"/></label>}{(mode==='login'||mode==='forgot')&&<label>Email<input type="email" name="email" required autoComplete="email" maxLength={254}/></label>}{mode!=='forgot'&&<label>Kata sandi<input type="password" name="password" required minLength={mode==='login'?1:12} maxLength={128} autoComplete={mode==='login'?'current-password':'new-password'}/></label>}{(mode==='reset'||mode==='invite')&&!token&&<ErrorNotice error={new Error('Tautan tidak lengkap. Gunakan tautan dari email pengelola.')}/ >}{error!=null&&<ErrorNotice error={error}/>}<button className="button full" disabled={busy||(mode==='reset'||mode==='invite')&&!token}>{busy?<LoaderCircle size={18} className="spin"/>:mode==='login'?'Masuk':mode==='forgot'?'Kirim tautan':mode==='invite'?'Aktifkan akun':'Perbarui kata sandi'}<ArrowRight size={17}/></button></form>}{mode==='login'?<Link className="text-button auth-link" to="/forgot-password">Lupa kata sandi?</Link>:<Link className="text-button auth-link" to="/login">Kembali ke halaman masuk</Link>}<p className="auth-footnote">Akses akun dikelola oleh pengelola kelompok tani. Belum punya akses? Hubungi pengelola kelompok tani.</p></div></section></main>;
}
function AccountDeletionPage(){
 const navigate=useNavigate();
 const [busy,setBusy]=useState(false);
 const [error,setError]=useState<unknown>();
 const [deleted,setDeleted]=useState(false);

 const session=useQuery({
  queryKey:['account-deletion-session'],
  queryFn:async()=>{
   const r=await request('/auth/me');
   setCsrf(r.csrf);
   return r;
  },
  retry:false
 });

 async function submit(e:FormEvent<HTMLFormElement>){
  e.preventDefault();
  const f=new FormData(e.currentTarget);
  setBusy(true);
  setError(undefined);

  try{
   await request('/auth/delete-account',{
    method:'POST',
    body:JSON.stringify({
     current_password:f.get('current_password')
    })
   });

   setCsrf('');
   queryClient.clear();
   setDeleted(true);
  }catch(e){
   setError(e);
  }finally{
   setBusy(false);
  }
 }

 if(deleted){
  return <main className="public-main">
   <header className="public-page-heading">
    <span className="eyebrow">AKUN & DATA</span>
    <h1>Akun berhasil dihapus.</h1>
    <p>
     Akses akun telah dicabut dan data pribadi akun telah dianonimkan.
     Catatan transaksi dan riwayat organisasi tertentu tetap disimpan
     untuk integritas pembukuan dan keamanan.
    </p>
   </header>
   <Link className="button" to="/">Kembali ke beranda</Link>
  </main>;
 }

 if(session.isPending){
  return <main className="public-main"><Loading/></main>;
 }

 if(session.error instanceof ApiError&&session.error.status===401){
  return <main className="public-main">
   <header className="public-page-heading">
    <span className="eyebrow">AKUN & DATA</span>
    <h1>Hapus akun.</h1>
    <p>
     Masuk dengan akun yang ingin dihapus. Setelah masuk,
     Anda akan kembali ke halaman ini untuk mengonfirmasi penghapusan.
    </p>
   </header>
   <Link
    className="button"
    to="/login?next=/account-deletion"
   >
    Masuk untuk melanjutkan
   </Link>
  </main>;
 }

 if(session.isError){
  return <main className="public-main">
   <ErrorNotice
    error={session.error}
    retry={()=>session.refetch()}
   />
  </main>;
 }

 const user=session.data.user;

 if(user.role==='OWNER'){
  return <main className="public-main">
   <header className="public-page-heading">
    <span className="eyebrow">AKUN & DATA</span>
    <h1>Hapus akun.</h1>
    <p>
     Akun Pengelola Utama tidak dapat dihapus sebelum tanggung jawab
     Pengelola Utama dipindahkan ke Admin lain.
    </p>
   </header>
   <button
    className="button"
    onClick={()=>navigate('/dashboard/users')}
   >
    Kelola pengguna
   </button>
  </main>;
 }

 return <main className="public-main">
  <header className="public-page-heading">
   <span className="eyebrow">AKUN & DATA</span>
   <h1>Hapus akun.</h1>
   <p>
    Penghapusan akan mencabut akses akun dan menganonimkan data pribadi
    akun. Catatan transaksi dan riwayat organisasi tertentu tetap disimpan
    untuk integritas pembukuan dan keamanan.
   </p>
  </header>

  <div className="auth-content">
   <strong>{user.name}</strong>
   <p className="muted-text">{user.email}</p>

   <form onSubmit={submit}>
    <label>
     Kata sandi saat ini
     <input
      type="password"
      name="current_password"
      required
      maxLength={128}
      autoComplete="current-password"
     />
    </label>

    {error!=null&&<ErrorNotice error={error}/>}

    <button className="button full" disabled={busy}>
     {busy?<LoaderCircle size={18} className="spin"/>:'Hapus akun'}
    </button>
   </form>
  </div>
 </main>;
}
function PrivacyPage(){
 return <main className="public-main">
  <header className="public-page-heading">
   <span className="eyebrow">PRIVASI & DATA</span>
   <h1>Kebijakan Privasi.</h1>
   <p>
    Kebijakan ini menjelaskan bagaimana Kelompok Tani Podokoyo
    memproses data ketika Anda menggunakan website dan aplikasi
    pengelolaan kelompok tani.
   </p>
  </header>

  <article className="village-story">
   <h2>Data yang diproses</h2>
   <p>
    Sistem dapat memproses nama, alamat email, informasi akun,
    profil anggota tani, foto yang dipilih pengguna, serta catatan
    operasional seperti panen, persediaan, produksi, penjualan,
    pembukuan, dan riwayat aktivitas.
   </p>

   <h2>Tujuan penggunaan data</h2>
   <p>
    Data digunakan untuk menyediakan akses akun, menjalankan
    operasional kelompok tani, menjaga riwayat transaksi,
    menghasilkan laporan, mengirim email terkait akun atau
    pengingat, serta menjaga keamanan dan integritas sistem.
   </p>

   <h2>Pihak yang membantu menyediakan layanan</h2>
   <p>
    Data dapat diproses oleh penyedia layanan yang digunakan
    untuk menjalankan sistem, seperti penyedia hosting dan
    database, layanan email transaksional, serta penyimpanan
    file privat. Data tidak digunakan untuk iklan dan tidak
    dijual kepada pengiklan.
   </p>

   <h2>Foto dan file</h2>
   <p>
    Aplikasi hanya mengakses foto yang dipilih pengguna melalui
    pemilih foto sistem. Aplikasi tidak menggunakan kamera,
    lokasi, kontak, mikrofon, atau akses penyimpanan perangkat
    secara luas. File gambar disimpan pada penyimpanan privat dan
    diakses melalui tautan terbatas.
   </p>

   <h2>Keamanan</h2>
   <p>
    Layanan produksi menggunakan koneksi HTTPS. Informasi sesi
    autentikasi disimpan secara aman dan kata sandi tidak disimpan
    dalam bentuk teks biasa. Akses data organisasi dibatasi
    berdasarkan akun dan peran pengguna.
   </p>

   <h2>Penyimpanan dan penghapusan data</h2>
   <p>
    Pengguna Admin dapat meminta penghapusan akun. Saat akun
    dihapus, akses dicabut dan data pribadi akun seperti nama,
    email, informasi autentikasi, sesi, dan data terkait akses
    dianonimkan atau dihapus.
   </p>
   <p>
    Catatan transaksi, pembukuan, riwayat stok, dan audit tertentu
    dapat tetap disimpan apabila diperlukan untuk menjaga
    integritas catatan organisasi, keamanan, pencegahan
    penyalahgunaan, atau kewajiban yang berlaku.
   </p>

   <h2>Penghapusan akun</h2>
   <p>
    Permintaan penghapusan akun dapat dilakukan dari aplikasi
    atau melalui halaman penghapusan akun pada website.
   </p>
   <Link className="text-button" to="/account-deletion">
    Buka halaman penghapusan akun <ArrowRight size={17}/>
   </Link>

   <h2>Perubahan kebijakan</h2>
   <p>
    Kebijakan ini dapat diperbarui apabila cara sistem memproses
    data berubah. Versi yang berlaku akan ditampilkan pada halaman
    ini.
   </p>

   <h2>Kontak privasi</h2>
   <p>
    Pertanyaan mengenai privasi dan penggunaan data dapat
    disampaikan kepada Pengelola Utama Kelompok Tani Podokoyo
    melalui kanal kontak resmi kelompok tani.
   </p>
  </article>
 </main>;
}
const nav=[{to:'',label:'Ringkasan',icon:LayoutDashboard},{to:'harvests',label:'Panen',icon:Wheat},{to:'inventory',label:'Persediaan',icon:Warehouse},{to:'products',label:'Produk & HPP',icon:Package},{to:'plans',label:'Rencana produksi',icon:Waypoints},{to:'production',label:'Hasil produksi',icon:Factory},{to:'opnames',label:'Cek stok fisik',icon:ClipboardCheck},{to:'sales',label:'Penjualan',icon:ShoppingBag},{to:'reports',label:'Pembukuan',icon:ChartNoAxesCombined},{to:'content',label:'Konten website',icon:PanelTop},{to:'users',label:'Pengguna',icon:Users},{to:'farmers',label:'Anggota tani',icon:Users},{to:'audit',label:'Riwayat aktivitas',icon:ScrollText},{to:'settings',label:'Pengaturan',icon:Settings}];
function Dashboard(){
 const location=useLocation(),navigate=useNavigate(),[menu,setMenu]=useState(false),[logoutError,setLogoutError]=useState<unknown>();
 const session=useQuery({queryKey:['session'],queryFn:async()=>{const r=await request('/auth/me');setCsrf(r.csrf);return r;},retry:false});
 useEffect(()=>setMenu(false),[location.pathname]);
 if(session.isPending)return <Loading/>;
 if(session.error instanceof ApiError&&session.error.status===401)return <Navigate to="/login" replace/>;
 if(session.isError)return <div className="standalone-error"><ErrorNotice error={session.error} retry={()=>session.refetch()}/></div>;
 const user=session.data.user,current=nav.find(n=>location.pathname==='/dashboard'+(n.to?'/'+n.to:''));
 return <Auth.Provider value={user}><div className="dashboard"><OfflineBanner/>{menu&&<button className="sidebar-backdrop" aria-label="Tutup navigasi" onClick={()=>setMenu(false)}/>}<aside className={'sidebar '+(menu?'open':'')}><CoBrandIdentity variant="sidebar"/><nav>{nav.map((n,i)=><React.Fragment key={n.to}>{[1,3,6,9,10].includes(i)&&<span className="nav-divider"/>}<NavLink to={'/dashboard'+(n.to?'/'+n.to:'')} end={!n.to}><n.icon size={18}/>{n.label}</NavLink></React.Fragment>)}</nav><div className="sidebar-bottom"><Link className="text-button" to="/" target="_blank">Lihat website <ArrowUpRight size={16}/></Link><button className="text-button" onClick={async()=>{try{await request('/auth/logout',{method:'POST',body:'{}'});setCsrf('');queryClient.clear();navigate('/login');}catch(e){setLogoutError(e);}}}><LogOut size={16}/>Keluar</button>{logoutError!=null&&<ErrorNotice error={logoutError}/>}</div></aside><div className="workspace"><header className="workspace-top"><button className="icon-button mobile-toggle" aria-label="Buka navigasi" onClick={()=>setMenu(!menu)}><Menu/></button><span className="workspace-breadcrumb">Ruang kerja <span className="breadcrumb-slash">/</span> <strong>{current?.label??'Operasional'}</strong></span><div className="workspace-label top-workspace-label"><span className="workspace-avatar"><Leaf size={17}/></span><div>Ruang kerja<small>{user.role==='OWNER'?'Pengelola Utama':'Admin'}</small></div></div></header><main className="workspace-main"><Outlet/></main></div></div></Auth.Provider>;
}
function App(){return <BrowserRouter><Routes><Route element={<PublicLayout/>}><Route index element={<PublicPage/>}/><Route path="desa" element={<PublicPage section="village"/>}/><Route path="petani" element={<PublicPage section="farmers"/>}/><Route path="produk" element={<PublicPage section="products"/>}/><Route path="privacy" element={<PrivacyPage/>}/></Route><Route path="login" element={<AuthPage/>}/><Route path="forgot-password" element={<AuthPage mode="forgot"/>}/><Route path="reset-password" element={<AuthPage mode="reset"/>}/><Route path="accept-invitation" element={<AuthPage mode="invite"/>}/><Route path="account-deletion" element={<AccountDeletionPage/>}/><Route path="dashboard" element={<Dashboard/>}><Route index element={<Overview/>}/>{['harvests','farmers','inventory','opnames','plans','production','products','sales','users','audit'].map(resource=><Route key={resource} path={resource} element={<Operations key={resource} resource={resource}/>}/>)}<Route path="reports" element={<ReportsPage/>}/><Route path="settings" element={<SettingsPage/>}/><Route path="content" element={<ContentPage/>}/></Route><Route path="*" element={<div className="standalone-error"><Empty title="Halaman tidak ditemukan" action={<Link className="button" to="/">Ke beranda</Link>}/></div>}/></Routes></BrowserRouter>;}
createRoot(document.getElementById('root')!).render(<React.StrictMode><QueryClientProvider client={queryClient}><App/></QueryClientProvider></React.StrictMode>);
if('serviceWorker' in navigator&&import.meta.env.PROD)window.addEventListener('load',()=>{navigator.serviceWorker.register('/sw.js').catch(()=>console.info('PWA service worker unavailable.'));});